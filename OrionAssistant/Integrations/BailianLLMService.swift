import Foundation

enum BailianSettingsStore {
    static let apiKeyKey = "bailian.apiKey"
    static let baseURLKey = "bailian.baseURL"
    static let modelKey = "bailian.model"

    static let defaultBaseURL = "https://dashscope.aliyuncs.com/compatible-mode/v1"
    static let defaultModel = "qwen-turbo"

    static var apiKey: String {
        KeychainStore.load(apiKeyKey)
    }

    static var baseURL: String {
        let value = UserDefaults.standard.string(forKey: baseURLKey) ?? ""
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? defaultBaseURL : cleaned
    }

    static var model: String {
        let value = UserDefaults.standard.string(forKey: modelKey) ?? ""
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? defaultModel : cleaned
    }

    static var streamingModel: String {
        let configured = model.lowercased()
        if configured.contains("turbo") {
            return model
        }
        return defaultModel
    }

    static var isConfigured: Bool {
        apiKey.isEmpty == false
    }
}

enum BailianLLMError: LocalizedError {
    case missingConfiguration
    case invalidBaseURL
    case invalidResponse(String?)
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "百炼 API Key 未配置"
        case .invalidBaseURL:
            return "百炼 Base URL 无效"
        case .invalidResponse(let detail):
            if let detail, detail.isEmpty == false {
                return "百炼返回结果无法解析：\(detail)"
            }
            return "百炼返回结果无法解析"
        case .emptyContent:
            return "百炼没有返回可用内容"
        }
    }
}

final class BailianCompatibleLLMProviderService: LLMProviderService {
    func respond(to prompt: String, history: [AssistantMessage]) async throws -> AssistantLLMResponse {
        let structured = try await requestStructuredResponse(for: prompt, history: history)
        return AssistantLLMResponse(
            reply: structured.reply.trimmingCharacters(in: .whitespacesAndNewlines),
            drafts: structured.drafts.compactMap(makeDraft)
        )
    }

    func streamReply(to prompt: String, history: [AssistantMessage], onDelta: @escaping @Sendable (String) -> Void) async throws -> String {
        guard BailianSettingsStore.isConfigured else {
            throw BailianLLMError.missingConfiguration
        }

        guard let url = URL(string: BailianSettingsStore.baseURL + "/chat/completions") else {
            throw BailianLLMError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(BailianSettingsStore.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        request.httpBody = try JSONEncoder().encode(makeStreamingRequestBody(for: prompt, history: history))

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BailianLLMError.invalidResponse("未获取到 HTTP 响应")
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            var bodyText = ""
            for try await line in bytes.lines {
                bodyText += line
                if bodyText.count > 400 { break }
            }
            throw BailianLLMError.invalidResponse("HTTP \(httpResponse.statusCode) \(bodyText)")
        }

        var fullContent = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            if payload == "[DONE]" { break }

            guard let data = payload.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(BailianStreamingChunk.self, from: data),
                  let delta = chunk.choices.first?.delta.contentText,
                  delta.isEmpty == false else { continue }

            fullContent += delta
            onDelta(fullContent)
        }

        guard fullContent.isEmpty == false else {
            throw BailianLLMError.emptyContent
        }

        return fullContent
    }

    func generateDrafts(from prompt: String) async throws -> [AssistantActionDraft] {
        let structured = try await requestStructuredResponse(for: prompt, history: [])
        return structured.drafts.compactMap(makeDraft)
    }

    private func requestStructuredResponse(for prompt: String, history: [AssistantMessage]) async throws -> LLMStructuredResponse {
        guard BailianSettingsStore.isConfigured else {
            throw BailianLLMError.missingConfiguration
        }

        guard let url = URL(string: BailianSettingsStore.baseURL + "/chat/completions") else {
            throw BailianLLMError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(BailianSettingsStore.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(makeRequestBody(for: prompt, history: history))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw NSError(domain: "BailianHTTP", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [
                NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "百炼请求失败"
            ])
        }

        let decoded = try JSONDecoder().decode(BailianChatCompletionsEnvelope.self, from: data)
        let text = decoded.choices.first?.message.contentText
        let cleaned = sanitizeJSONText(text)
        guard cleaned.isEmpty == false else {
            throw BailianLLMError.emptyContent
        }

        let payloadData = Data(cleaned.utf8)
        return try JSONDecoder().decode(LLMStructuredResponse.self, from: payloadData)
    }

    private func makeRequestBody(for prompt: String, history: [AssistantMessage]) -> BailianChatCompletionsRequest {
        let currentDate = ISO8601DateFormatter().string(from: Date())
        let systemPrompt = """
        你是中文私人助理。只输出 JSON。
        结合最近对话自然回复；需要执行时再生成动作草案。
        时间使用 ISO8601，时区 Asia/Shanghai。未给日期默认明天，未给天数默认 2 天。
        输出：
        {"reply":"2到4句自然回复","drafts":[{"type":"trip|event|reminder","title":"标题","subtitle":"副标题","trip":{"title":"行程标题","destination":"目的地","dateRangeText":"日期范围","summary":"摘要","items":[{"title":"日程标题","start":"ISO8601","end":"ISO8601","location":"地点","notes":"备注","alarmOffsetMinutes":60}],"reminders":[{"title":"提醒标题","dueDate":"ISO8601","notes":"备注"}]},"event":{"title":"事件标题","start":"ISO8601","end":"ISO8601","location":"地点","notes":"备注","alarmOffsetMinutes":30},"reminder":{"title":"提醒标题","dueDate":"ISO8601","notes":"备注"}}]}
        当前时间：\(currentDate)
        """

        let historyMessages = history.suffix(4).map { message in
            BailianChatMessage(role: message.role == .assistant ? "assistant" : "user", text: message.content)
        }

        return BailianChatCompletionsRequest(
            model: BailianSettingsStore.model,
            messages: [BailianChatMessage(role: "system", text: systemPrompt)] + historyMessages + [BailianChatMessage(role: "user", text: prompt)],
            temperature: 0.1,
            maxTokens: 900,
            stream: false,
            streamOptions: nil
        )
    }

    private func makeStreamingRequestBody(for prompt: String, history: [AssistantMessage]) -> BailianChatCompletionsRequest {
        let systemPrompt = """
        你是中文私人助理。
        直接回答，不复述，不空话。
        信息不够就简短追问一句；信息够就直接给建议和判断。
        不输出 JSON。
        """

        let historyMessages = history.suffix(2).map { message in
            BailianChatMessage(role: message.role == .assistant ? "assistant" : "user", text: message.content)
        }

        return BailianChatCompletionsRequest(
            model: BailianSettingsStore.streamingModel,
            messages: [BailianChatMessage(role: "system", text: systemPrompt)] + historyMessages + [BailianChatMessage(role: "user", text: prompt)],
            temperature: 0.2,
            maxTokens: 220,
            stream: true,
            streamOptions: BailianStreamOptions(includeUsage: false)
        )
    }

    private func makeDraft(from item: LLMStructuredDraft) -> AssistantActionDraft? {
        switch item.type {
        case "trip":
            guard let trip = item.trip else { return nil }
            let eventDrafts = trip.items.compactMap { payload -> CalendarEventDraftPayload? in
                guard let startDate = payload.startDate, let endDate = payload.endDate else { return nil }
                return CalendarEventDraftPayload(
                    title: payload.title,
                    startDate: startDate,
                    endDate: endDate,
                    notes: payload.notes,
                    location: payload.location,
                    alarmOffsetMinutes: payload.alarmOffsetMinutes,
                    conflictTitles: [],
                    suggestedAlternatives: []
                )
            }
            let reminderDrafts = trip.reminders.map {
                ReminderDraftPayload(title: $0.title, dueDate: $0.dueDate, notes: $0.notes)
            }

            return AssistantActionDraft(
                title: item.title,
                subtitle: item.subtitle,
                actionType: .createTrip,
                requiresConfirmation: true,
                payload: .trip(
                    TripDraftPayload(
                        title: trip.title,
                        destination: trip.destination,
                        dateRangeText: trip.dateRangeText,
                        summary: trip.summary,
                        eventDrafts: eventDrafts,
                        reminderDrafts: reminderDrafts
                    )
                )
            )
        case "event":
            guard let event = item.event, let startDate = event.startDate, let endDate = event.endDate else { return nil }
            return AssistantActionDraft(
                title: item.title,
                subtitle: item.subtitle,
                actionType: .createEvent,
                requiresConfirmation: true,
                payload: .event(
                    CalendarEventDraftPayload(
                        title: event.title,
                        startDate: startDate,
                        endDate: endDate,
                        notes: event.notes,
                        location: event.location,
                        alarmOffsetMinutes: event.alarmOffsetMinutes,
                        conflictTitles: [],
                        suggestedAlternatives: []
                    )
                )
            )
        case "reminder":
            guard let reminder = item.reminder else { return nil }
            return AssistantActionDraft(
                title: item.title,
                subtitle: item.subtitle,
                actionType: .createReminder,
                requiresConfirmation: true,
                payload: .reminder(ReminderDraftPayload(title: reminder.title, dueDate: reminder.dueDate, notes: reminder.notes))
            )
        default:
            return nil
        }
    }

    private func sanitizeJSONText(_ text: String?) -> String {
        let raw = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard raw.isEmpty == false else { return "" }
        if raw.hasPrefix("```"), let firstBrace = raw.firstIndex(of: "{"), let lastBrace = raw.lastIndex(of: "}") {
            return String(raw[firstBrace...lastBrace])
        }
        if let firstBrace = raw.firstIndex(of: "{"), let lastBrace = raw.lastIndex(of: "}") {
            return String(raw[firstBrace...lastBrace])
        }
        return raw
    }
}

private struct BailianChatCompletionsRequest: Encodable {
    let model: String
    let messages: [BailianChatMessage]
    let temperature: Double
    let maxTokens: Int
    let stream: Bool
    let streamOptions: BailianStreamOptions?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
        case stream
        case streamOptions = "stream_options"
    }
}

private struct BailianChatMessage: Encodable {
    let role: String
    let text: String

    enum CodingKeys: String, CodingKey {
        case role
        case text = "content"
    }
}

private struct BailianChatCompletionsEnvelope: Decodable {
    let choices: [BailianChatChoice]
}

private struct BailianChatChoice: Decodable {
    let message: BailianChatChoiceMessage
}

private struct BailianChatChoiceMessage: Decodable {
    let content: BailianFlexibleContent

    var contentText: String {
        content.text
    }
}

private struct BailianStreamOptions: Encodable {
    let includeUsage: Bool

    enum CodingKeys: String, CodingKey {
        case includeUsage = "include_usage"
    }
}

private struct BailianStreamingChunk: Decodable {
    let choices: [BailianStreamingChoice]
}

private struct BailianStreamingChoice: Decodable {
    let delta: BailianStreamingDelta
}

private struct BailianStreamingDelta: Decodable {
    let content: BailianFlexibleContent?

    var contentText: String? {
        content?.text
    }
}

private struct BailianFlexibleContent: Decodable {
    let text: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            text = stringValue
            return
        }

        if let parts = try? container.decode([BailianContentPart].self) {
            text = parts.map(\.text).joined()
            return
        }

        text = ""
    }
}

private struct BailianContentPart: Decodable {
    let type: String?
    let text: String
}

private struct LLMStructuredResponse: Decodable {
    let reply: String
    let drafts: [LLMStructuredDraft]
}

private struct LLMStructuredDraft: Decodable {
    let type: String
    let title: String
    let subtitle: String
    let trip: LLMTripPayload?
    let event: LLMEventPayload?
    let reminder: LLMReminderPayload?
}

private struct LLMTripPayload: Decodable {
    let title: String
    let destination: String
    let dateRangeText: String
    let summary: String
    let items: [LLMEventPayload]
    let reminders: [LLMReminderPayload]
}

private struct LLMEventPayload: Decodable {
    let title: String
    let start: String
    let end: String
    let location: String?
    let notes: String?
    let alarmOffsetMinutes: Int?

    var startDate: Date? {
        Date.iso8601WithFractionalSeconds.date(from: start) ?? Date.iso8601Basic.date(from: start)
    }

    var endDate: Date? {
        Date.iso8601WithFractionalSeconds.date(from: end) ?? Date.iso8601Basic.date(from: end)
    }
}

private struct LLMReminderPayload: Decodable {
    let title: String
    let dueDateText: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case title
        case dueDateText = "dueDate"
        case notes
    }

    var dueDateValue: Date? {
        guard let dueDateText else { return nil }
        return Date.iso8601WithFractionalSeconds.date(from: dueDateText) ?? Date.iso8601Basic.date(from: dueDateText)
    }

    var dueDate: Date? {
        dueDateValue
    }
}

private extension Date {
    static let iso8601Basic: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter
    }()

    static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withColonSeparatorInTimeZone]
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter
    }()
}
