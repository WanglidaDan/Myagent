import Foundation

struct ParsedAssistantIntent {
    let summary: String
    let drafts: [AssistantActionDraft]
}

final class AssistantEngine {
    func parse(_ input: String, calendarEvents: [CalendarEventSummary] = []) -> ParsedAssistantIntent {
        let normalizedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let drafts = makeDrafts(from: normalizedInput, calendarEvents: calendarEvents)
        let routeAdvice = makeRouteAdvice(for: normalizedInput)

        let summary: String
        if normalizedInput.isEmpty {
            summary = "等待输入"
        } else if let routeAdvice {
            summary = routeAdvice
        } else if let tripDraft = drafts.first(where: { $0.actionType == .createTrip }),
                  case .trip(let payload) = tripDraft.payload {
            summary = "我已经为你生成 \(payload.destination) 的真实行程草案，共 \(payload.eventDrafts.count) 个日程和 \(payload.reminderDrafts.count) 个提醒，确认后会写入系统。"
        } else if let eventDraft = drafts.first(where: { $0.actionType == .createEvent }),
                  case .event(let payload) = eventDraft.payload,
                  payload.conflictTitles.isEmpty == false {
            summary = "我检测到这个安排和现有日历冲突，已为你准备候选时段。"
        } else if drafts.isEmpty == false {
            summary = "我已经把你的输入整理成 \(drafts.count) 个可确认动作，可以直接执行到系统。"
        } else {
            summary = "我已经理解你的需求，但这次还没有生成可执行草案。你可以补充具体时间、时长或提醒要求。"
        }

        return ParsedAssistantIntent(summary: summary, drafts: drafts)
    }

    private func makeDrafts(from input: String, calendarEvents: [CalendarEventSummary]) -> [AssistantActionDraft] {
        guard input.isEmpty == false else { return [] }

        if let tripDraft = makeTripDraft(from: input) {
            return [tripDraft]
        }

        let eventDraft = makeEventDraft(from: input, calendarEvents: calendarEvents)
        let reminderDraft = makeReminderDraft(from: input, eventDraft: eventDraft)

        return [eventDraft, reminderDraft].compactMap { $0 }
    }

    private func makeTripDraft(from input: String) -> AssistantActionDraft? {
        guard input.contains("去"), input.contains("天"), (input.contains("安排") || input.contains("行程") || input.contains("出差")) else {
            return nil
        }

        guard let destination = inferredDestination(from: input) else { return nil }

        let calendar = Calendar.current
        let durationDays = inferredTripDurationDays(from: input)
        let startDate = inferredTripStartDate(from: input, calendar: calendar)
        let eventDrafts = makeTripEventDrafts(destination: destination, startDate: startDate, durationDays: durationDays, calendar: calendar)
        let reminderDrafts = makeTripReminderDrafts(destination: destination, eventDrafts: eventDrafts, calendar: calendar)
        let endDate = calendar.date(byAdding: .day, value: max(durationDays - 1, 0), to: startDate) ?? startDate
        let dateRangeText = tripDateRangeText(startDate: startDate, endDate: endDate)
        let title = "\(destination)\(durationDays)天行程"
        let summary = "\(durationDays) 天在 \(destination) 的出行安排，含出发、入住、当日主行程和返程准备。"

        return AssistantActionDraft(
            title: title,
            subtitle: "\(dateRangeText) · 将创建 \(eventDrafts.count) 个日程和 \(reminderDrafts.count) 个提醒",
            actionType: .createTrip,
            requiresConfirmation: true,
            payload: .trip(
                TripDraftPayload(
                    title: title,
                    destination: destination,
                    dateRangeText: dateRangeText,
                    summary: summary,
                    eventDrafts: eventDrafts,
                    reminderDrafts: reminderDrafts
                )
            )
        )
    }

    private func makeEventDraft(from input: String, calendarEvents: [CalendarEventSummary]) -> AssistantActionDraft? {
        guard input.contains("日历") || input.contains("会议") || input.contains("安排") || input.contains("行程") else {
            return nil
        }

        let calendar = Calendar.current
        let startDate = inferredStartDate(from: input, calendar: calendar)
        let endDate = inferredEndDate(from: input, startDate: startDate, calendar: calendar)
        let title = inferredTitle(from: input)
        let alarmOffset = inferredAlarmMinutes(from: input)
        let conflicts = conflictingEvents(for: startDate, endDate: endDate, from: calendarEvents)
        let alternatives = suggestedAlternatives(for: startDate, endDate: endDate, existingEvents: calendarEvents, calendar: calendar)

        let subtitle = conflicts.isEmpty
            ? dateSubtitle(start: startDate, end: endDate, alarmMinutes: alarmOffset)
            : "\(dateSubtitle(start: startDate, end: endDate, alarmMinutes: alarmOffset)) · 与 \(conflicts.count) 个日程冲突"

        return AssistantActionDraft(
            title: title,
            subtitle: subtitle,
            actionType: .createEvent,
            requiresConfirmation: true,
            payload: .event(
                CalendarEventDraftPayload(
                    title: title,
                    startDate: startDate,
                    endDate: endDate,
                    notes: input,
                    location: inferredLocation(from: input),
                    alarmOffsetMinutes: alarmOffset,
                    conflictTitles: conflicts.map(\.title),
                    suggestedAlternatives: alternatives
                )
            )
        )
    }

    private func makeReminderDraft(from input: String, eventDraft: AssistantActionDraft?) -> AssistantActionDraft? {
        guard input.contains("提醒") else { return nil }

        let dueDate: Date?
        let title: String

        if let eventDraft, case .event(let payload) = eventDraft.payload {
            title = "提醒：\(payload.title)"
            if let alarmOffset = payload.alarmOffsetMinutes {
                dueDate = Calendar.current.date(byAdding: .minute, value: -alarmOffset, to: payload.startDate)
            } else {
                dueDate = payload.startDate
            }
        } else {
            title = inferredTitle(from: input)
            dueDate = inferredStartDate(from: input, calendar: .current)
        }

        return AssistantActionDraft(
            title: title,
            subtitle: dueDate.map { "将在 \($0.formatted(date: .abbreviated, time: .shortened)) 提醒你" } ?? "需要你补充提醒时间",
            actionType: .createReminder,
            requiresConfirmation: true,
            payload: .reminder(ReminderDraftPayload(title: title, dueDate: dueDate, notes: input))
        )
    }

    private func makeRouteAdvice(for input: String) -> String? {
        let routeKeywords = ["抵达", "怎么去", "如何去", "怎么到", "如何到", "坐什么车", "坐高铁", "坐飞机", "路线", "路程", "交通"]
        guard routeKeywords.contains(where: { input.contains($0) }) else { return nil }

        let destination = inferredDestinationFromTravelQuestion(from: input)
        let origin = inferredOrigin(from: input)

        if let destination, let origin {
            return "我可以先按 \(origin) 到 \(destination) 给你做交通建议。当前本地兜底还查不到实时车次和航班，但我建议优先看高铁，其次看航班；如果你告诉我出发日期和大概时段，我会继续帮你缩小到更合适的出发方案。"
        }

        if let destination {
            return "可以，我先帮你规划怎么抵达 \(destination)。你再补一句出发城市和大概出发时间，我就能继续按高铁、飞机或自驾这几种方式给你整理建议。"
        }

        return "可以，我先帮你规划抵达方式。你告诉我出发城市、目的地和大概出发日期后，我会继续给你拆成更具体的交通建议。"
    }

    private func conflictingEvents(for startDate: Date, endDate: Date, from events: [CalendarEventSummary]) -> [CalendarEventSummary] {
        events.filter { event in
            max(event.startDate, startDate) < min(event.endDate, endDate)
        }
    }

    private func suggestedAlternatives(
        for startDate: Date,
        endDate: Date,
        existingEvents: [CalendarEventSummary],
        calendar: Calendar
    ) -> [CalendarTimeOption] {
        let duration = endDate.timeIntervalSince(startDate)
        let sortedEvents = existingEvents.sorted { $0.startDate < $1.startDate }
        let workdayStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: startDate) ?? startDate
        let workdayEnd = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: startDate) ?? endDate

        var cursor = max(workdayStart, startDate)
        var options: [CalendarTimeOption] = []

        for event in sortedEvents {
            if event.endDate <= cursor { continue }

            if event.startDate.timeIntervalSince(cursor) >= duration {
                let optionEnd = cursor.addingTimeInterval(duration)
                options.append(CalendarTimeOption(
                    title: "\(cursor.formatted(date: .omitted, time: .shortened)) - \(optionEnd.formatted(date: .omitted, time: .shortened))",
                    startDate: cursor,
                    endDate: optionEnd
                ))
            }

            cursor = max(cursor, event.endDate)
            if options.count >= 3 { break }
        }

        while options.count < 3, cursor.addingTimeInterval(duration) <= workdayEnd {
            let optionEnd = cursor.addingTimeInterval(duration)
            options.append(CalendarTimeOption(
                title: "\(cursor.formatted(date: .omitted, time: .shortened)) - \(optionEnd.formatted(date: .omitted, time: .shortened))",
                startDate: cursor,
                endDate: optionEnd
            ))
            cursor = calendar.date(byAdding: .minute, value: 30, to: cursor) ?? cursor.addingTimeInterval(1800)
        }

        return Array(options.prefix(3))
    }

    private func inferredStartDate(from input: String, calendar: Calendar) -> Date {
        let baseDate: Date
        if input.contains("后天") {
            baseDate = calendar.date(byAdding: .day, value: 2, to: Date()) ?? Date()
        } else if input.contains("明天") {
            baseDate = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        } else {
            baseDate = Date()
        }

        let hour = inferredHour(from: input) ?? 10
        let minute = inferredMinute(from: input) ?? 0
        let afternoonBoost = input.contains("下午") && hour < 12 ? 12 : 0

        return calendar.date(bySettingHour: min(hour + afternoonBoost, 23), minute: minute, second: 0, of: baseDate) ?? baseDate
    }

    private func inferredEndDate(from input: String, startDate: Date, calendar: Calendar) -> Date {
        if let hourRange = inferredHourRange(from: input) {
            let afternoonBoost = input.contains("下午") && hourRange.1 < 12 ? 12 : 0
            let candidate = calendar.date(bySettingHour: min(hourRange.1 + afternoonBoost, 23), minute: 0, second: 0, of: startDate)
            if let candidate, candidate > startDate {
                return candidate
            }
        }

        return calendar.date(byAdding: .hour, value: 1, to: startDate) ?? startDate.addingTimeInterval(3600)
    }

    private func inferredTitle(from input: String) -> String {
        if input.contains("评审") { return "产品评审" }
        if input.contains("会议") { return "会议安排" }
        if input.contains("出差") { return "出差安排" }
        return "新的助理安排"
    }

    private func inferredLocation(from input: String) -> String? {
        if let destination = inferredDestination(from: input) {
            return destination
        }
        if input.contains("虹桥") { return "上海虹桥" }
        if input.contains("杭州") { return "杭州" }
        if input.contains("浦东") { return "上海浦东" }
        return nil
    }

    private func inferredAlarmMinutes(from input: String) -> Int? {
        if input.contains("一小时") || input.contains("1小时") {
            return 60
        }
        if input.contains("三十分钟") || input.contains("30分钟") {
            return 30
        }
        return input.contains("提醒") ? 15 : nil
    }

    private func inferredHourRange(from input: String) -> (Int, Int)? {
        let values = extractedHourValues(from: input)
        guard values.count >= 2 else { return nil }
        return (values[0], values[1])
    }

    private func inferredHour(from input: String) -> Int? {
        extractedHourValues(from: input).first
    }

    private func inferredMinute(from input: String) -> Int? {
        input.contains("半") ? 30 : 0
    }

    private func extractedHourValues(from input: String) -> [Int] {
        let patterns = [
            "([0-9]{1,2})点",
            "([一二三四五六七八九十两]{1,3})点"
        ]

        var results: [Int] = []

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let matches = regex.matches(in: input, range: NSRange(input.startIndex..., in: input))
            for match in matches {
                guard match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: input) else { continue }
                let token = String(input[range])
                if let value = Int(token) {
                    results.append(value)
                } else if let value = chineseHourValue(token) {
                    results.append(value)
                }
            }
        }

        return results
    }

    private func inferredDestination(from input: String) -> String? {
        let patterns = [
            "去([\\p{Han}A-Za-z]{2,12}?)(?:[0-9一二三四五六七八九十两]+天|一天|两天|三天|四天|五天|出差|玩|旅行|安排|行程)",
            "到([\\p{Han}A-Za-z]{2,12}?)(?:[0-9一二三四五六七八九十两]+天|一天|两天|三天|四天|五天|出差|玩|旅行|安排|行程)"
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(input.startIndex..., in: input)
            guard let match = regex.firstMatch(in: input, range: range),
                  let tokenRange = Range(match.range(at: 1), in: input) else { continue }
            let value = String(input[tokenRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty == false {
                return value
            }
        }

        return nil
    }

    private func inferredDestinationFromTravelQuestion(from input: String) -> String? {
        if let destination = inferredDestination(from: input) {
            return destination
        }

        let patterns = [
            "(?:去|到|抵达|前往)([\\p{Han}A-Za-z]{2,12})",
            "([\\p{Han}A-Za-z]{2,12})(?:怎么去|如何去|怎么到|如何到|怎么抵达|如何抵达)"
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(input.startIndex..., in: input)
            guard let match = regex.firstMatch(in: input, range: range),
                  let tokenRange = Range(match.range(at: 1), in: input) else { continue }
            let value = String(input[tokenRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty == false {
                return value
            }
        }

        return nil
    }

    private func inferredOrigin(from input: String) -> String? {
        let patterns = [
            "从([\\p{Han}A-Za-z]{2,12})(?:出发|去|到)",
            "([\\p{Han}A-Za-z]{2,12})到[\\p{Han}A-Za-z]{2,12}"
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(input.startIndex..., in: input)
            guard let match = regex.firstMatch(in: input, range: range),
                  let tokenRange = Range(match.range(at: 1), in: input) else { continue }
            let value = String(input[tokenRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty == false {
                return value
            }
        }

        return nil
    }

    private func inferredTripDurationDays(from input: String) -> Int {
        if input.contains("五天") { return 5 }
        if input.contains("四天") { return 4 }
        if input.contains("三天") { return 3 }
        if input.contains("两天") || input.contains("2天") { return 2 }
        if input.contains("一天") || input.contains("1天") { return 1 }

        if let regex = try? NSRegularExpression(pattern: "([0-9]{1,2})天"),
           let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)),
           let range = Range(match.range(at: 1), in: input),
           let value = Int(input[range]) {
            return max(1, value)
        }

        return 2
    }

    private func inferredTripStartDate(from input: String, calendar: Calendar) -> Date {
        let startBase: Date
        if input.contains("后天") {
            startBase = calendar.date(byAdding: .day, value: 2, to: Date()) ?? Date()
        } else if input.contains("明天") {
            startBase = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        } else {
            startBase = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        }

        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: startBase) ?? startBase
    }

    private func makeTripEventDrafts(destination: String, startDate: Date, durationDays: Int, calendar: Calendar) -> [CalendarEventDraftPayload] {
        var drafts: [CalendarEventDraftPayload] = []

        let departureStart = startDate
        let departureEnd = calendar.date(byAdding: .hour, value: 2, to: departureStart) ?? departureStart.addingTimeInterval(7200)
        drafts.append(
            CalendarEventDraftPayload(
                title: "前往\(destination)出发准备",
                startDate: departureStart,
                endDate: departureEnd,
                notes: "检查证件、车票/机票、行李和酒店订单",
                location: nil,
                alarmOffsetMinutes: 60,
                conflictTitles: [],
                suggestedAlternatives: []
            )
        )

        let arrivalStart = calendar.date(byAdding: .hour, value: 5, to: departureStart) ?? departureStart.addingTimeInterval(18_000)
        let arrivalEnd = calendar.date(byAdding: .hour, value: 1, to: arrivalStart) ?? arrivalStart.addingTimeInterval(3600)
        drafts.append(
            CalendarEventDraftPayload(
                title: "抵达\(destination)并办理入住",
                startDate: arrivalStart,
                endDate: arrivalEnd,
                notes: "确认酒店位置和入住时间",
                location: destination,
                alarmOffsetMinutes: 30,
                conflictTitles: [],
                suggestedAlternatives: []
            )
        )

        for dayIndex in 0..<durationDays {
            let baseDay = calendar.date(byAdding: .day, value: dayIndex, to: startDate) ?? startDate
            let agendaStartHour = dayIndex == 0 ? 14 : 9
            let agendaStart = calendar.date(bySettingHour: agendaStartHour, minute: 30, second: 0, of: baseDay) ?? baseDay
            let agendaEnd = calendar.date(byAdding: .hour, value: 3, to: agendaStart) ?? agendaStart.addingTimeInterval(10_800)
            drafts.append(
                CalendarEventDraftPayload(
                    title: "\(destination)第\(dayIndex + 1)天主行程",
                    startDate: agendaStart,
                    endDate: agendaEnd,
                    notes: dayIndex == 0 ? "优先安排抵达后的核心事项和晚间休整" : "集中安排拜访、游览或办事节点",
                    location: destination,
                    alarmOffsetMinutes: 30,
                    conflictTitles: [],
                    suggestedAlternatives: []
                )
            )
        }

        let returnBase = calendar.date(byAdding: .day, value: max(durationDays - 1, 0), to: startDate) ?? startDate
        let returnStart = calendar.date(bySettingHour: 16, minute: 0, second: 0, of: returnBase) ?? returnBase
        let returnEnd = calendar.date(byAdding: .hour, value: 2, to: returnStart) ?? returnStart.addingTimeInterval(7200)
        drafts.append(
            CalendarEventDraftPayload(
                title: "\(destination)返程准备",
                startDate: returnStart,
                endDate: returnEnd,
                notes: "预留退房、取票和前往车站/机场时间",
                location: destination,
                alarmOffsetMinutes: 60,
                conflictTitles: [],
                suggestedAlternatives: []
            )
        )

        return drafts.sorted { $0.startDate < $1.startDate }
    }

    private func makeTripReminderDrafts(destination: String, eventDrafts: [CalendarEventDraftPayload], calendar: Calendar) -> [ReminderDraftPayload] {
        let anchorEvents = eventDrafts.filter { $0.title.contains("出发准备") || $0.title.contains("返程准备") }

        return anchorEvents.map { event in
            let dueDate = calendar.date(byAdding: .minute, value: -30, to: event.startDate)
            return ReminderDraftPayload(
                title: "提醒：\(event.title)",
                dueDate: dueDate,
                notes: "为\(destination)行程预留整理和出发时间"
            )
        }
    }

    private func tripDateRangeText(startDate: Date, endDate: Date) -> String {
        let startText = startDate.formatted(date: .abbreviated, time: .omitted)
        let endText = endDate.formatted(date: .abbreviated, time: .omitted)
        return startText == endText ? startText : "\(startText) - \(endText)"
    }

    private func chineseHourValue(_ token: String) -> Int? {
        let mapping: [String: Int] = [
            "一": 1, "二": 2, "两": 2, "三": 3, "四": 4, "五": 5, "六": 6,
            "七": 7, "八": 8, "九": 9, "十": 10, "十一": 11, "十二": 12
        ]
        return mapping[token]
    }

    private func dateSubtitle(start: Date, end: Date, alarmMinutes: Int?) -> String {
        var parts = [
            start.formatted(date: .abbreviated, time: .shortened),
            "到",
            end.formatted(date: .omitted, time: .shortened)
        ]
        if let alarmMinutes {
            parts.append("· 提前 \(alarmMinutes) 分钟提醒")
        }
        return parts.joined(separator: " ")
    }
}
