import EventKit
import Foundation

struct SystemIntegrationServices {
    let calendar: CalendarIntegrationService
    let reminders: ReminderIntegrationService
    let invoices: InvoiceProcessingService
    let routing: RoutingService
    let llm: LLMProviderService
    let voiceInput: VoiceInputService

    static let live = SystemIntegrationServices(
        calendar: EventKitCalendarIntegrationService(),
        reminders: EventKitReminderIntegrationService(),
        invoices: MockInvoiceProcessingService(),
        routing: MockRoutingService(),
        llm: BailianCompatibleLLMProviderService(),
        voiceInput: SystemVoiceInputService()
    )

    static let mock = SystemIntegrationServices(
        calendar: MockCalendarIntegrationService(),
        reminders: MockReminderIntegrationService(),
        invoices: MockInvoiceProcessingService(),
        routing: MockRoutingService(),
        llm: MockLLMProviderService(),
        voiceInput: MockVoiceInputService()
    )
}

protocol CalendarIntegrationService {
    func requestAccess() async -> Bool
    func events(on day: Date) async throws -> [CalendarEventSummary]
    func createEvent(from draft: CalendarEventDraftPayload) async throws
}

protocol ReminderIntegrationService {
    func requestAccess() async -> Bool
    func createReminder(from draft: ReminderDraftPayload) async throws
}

protocol InvoiceProcessingService {
    func processDocument(at path: String) async throws -> ExpenseItem
}

protocol RoutingService {
    func estimateRoute(origin: String, destination: String, mode: TransportMode) async throws -> RouteOption
}

protocol LLMProviderService {
    func respond(to prompt: String, history: [AssistantMessage]) async throws -> AssistantLLMResponse
    func streamReply(to prompt: String, history: [AssistantMessage], onDelta: @escaping @Sendable (String) -> Void) async throws -> String
    func generateDrafts(from prompt: String) async throws -> [AssistantActionDraft]
}

struct AssistantLLMResponse {
    let reply: String
    let drafts: [AssistantActionDraft]
}

struct MockCalendarIntegrationService: CalendarIntegrationService {
    func requestAccess() async -> Bool { false }
    func events(on day: Date) async throws -> [CalendarEventSummary] { [] }
    func createEvent(from draft: CalendarEventDraftPayload) async throws {}
}

struct MockReminderIntegrationService: ReminderIntegrationService {
    func requestAccess() async -> Bool { false }
    func createReminder(from draft: ReminderDraftPayload) async throws {}
}

struct MockInvoiceProcessingService: InvoiceProcessingService {
    func processDocument(at path: String) async throws -> ExpenseItem {
        ExpenseItem(title: "待处理票据", detail: path, amount: 0, status: .reviewNeeded)
    }
}

struct MockRoutingService: RoutingService {
    func estimateRoute(origin: String, destination: String, mode: TransportMode) async throws -> RouteOption {
        RouteOption(title: mode.rawValue, detail: "\(origin) → \(destination)", badge: "Mock")
    }
}

struct MockLLMProviderService: LLMProviderService {
    func respond(to prompt: String, history: [AssistantMessage]) async throws -> AssistantLLMResponse {
        AssistantLLMResponse(
            reply: "我先帮你理解这个需求。需要写入系统时，我会给你待确认动作。",
            drafts: try await generateDrafts(from: prompt)
        )
    }

    func streamReply(to prompt: String, history: [AssistantMessage], onDelta: @escaping @Sendable (String) -> Void) async throws -> String {
        let reply = "我先帮你理解这个需求。需要写入系统时，我会给你待确认动作。"
        onDelta(reply)
        return reply
    }

    func generateDrafts(from prompt: String) async throws -> [AssistantActionDraft] {
        [AssistantActionDraft(
            title: prompt,
            subtitle: "待接入 LLM 执行层",
            actionType: .createTrip,
            requiresConfirmation: true,
            payload: .trip(
                TripDraftPayload(
                    title: prompt,
                    destination: "待确认目的地",
                    dateRangeText: "待确认日期",
                    summary: "待接入更强的规划能力",
                    eventDrafts: [],
                    reminderDrafts: []
                )
            )
        )]
    }
}

final class EventKitCalendarIntegrationService: CalendarIntegrationService {
    private let store = EKEventStore()

    func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    func events(on day: Date) async throws -> [CalendarEventSummary] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(86_400)
        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)

        return store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map {
                CalendarEventSummary(
                    title: $0.title.isEmpty ? "未命名日程" : $0.title,
                    startDate: $0.startDate,
                    endDate: $0.endDate
                )
            }
    }

    func createEvent(from draft: CalendarEventDraftPayload) async throws {
        let event = EKEvent(eventStore: store)
        event.title = draft.title
        event.startDate = draft.startDate
        event.endDate = draft.endDate
        event.notes = draft.notes
        event.location = draft.location
        event.calendar = store.defaultCalendarForNewEvents

        if let alarmOffsetMinutes = draft.alarmOffsetMinutes {
            event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-alarmOffsetMinutes * 60)))
        }

        try store.save(event, span: .thisEvent)
    }
}

final class EventKitReminderIntegrationService: ReminderIntegrationService {
    private let store = EKEventStore()

    func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToReminders()
        } catch {
            return false
        }
    }

    func createReminder(from draft: ReminderDraftPayload) async throws {
        let reminder = EKReminder(eventStore: store)
        reminder.title = draft.title
        reminder.notes = draft.notes
        reminder.calendar = store.defaultCalendarForNewReminders()

        if let dueDate = draft.dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        }

        try store.save(reminder, commit: true)
    }
}
