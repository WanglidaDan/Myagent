import SwiftUI

struct AssistantChatView: View {
    let viewModel: AssistantChatViewModel
    @ObservedObject var voiceInputViewModel: VoiceInputViewModel
    @EnvironmentObject private var container: AppContainer

    @State private var draftInput = ""
    @State private var messages: [AssistantMessage]
    @State private var pendingDrafts: [AssistantActionDraft]
    @State private var draftStates: [UUID: DraftExecutionState]
    @State private var isThinking = false
    @State private var streamingAssistantReply = ""
    @State private var currentRequestNeedsDrafts = false
    @State private var selectedDraftIDs: Set<UUID> = []

    init(viewModel: AssistantChatViewModel, voiceInputViewModel: VoiceInputViewModel) {
        self.viewModel = viewModel
        self.voiceInputViewModel = voiceInputViewModel
        _messages = State(initialValue: viewModel.messages)
        _pendingDrafts = State(initialValue: [])
        _draftStates = State(initialValue: [:])
    }

    var body: some View {
        ZStack {
            agentBackground

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    topControlBar

                    if messages.isEmpty && pendingDrafts.isEmpty {
                        emptyState
                    }

                    ForEach(messages) { message in
                        messageBubble(message)
                    }

                    if isThinking || streamingAssistantReply.isEmpty == false {
                        thinkingBubble
                    }

                    if processingSteps.isEmpty == false {
                        processLane
                    }

                    if pendingActionDrafts.isEmpty == false {
                        pendingActionCard
                    }

                    if completedDrafts.isEmpty == false {
                        completedActionCard
                    }
                }
                .appPageLayout()
                .padding(.top, 10)
                .padding(.bottom, 16)
            }

            if isListening {
                voiceRecordingOverlay
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            composerBar
        }
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("直接说出你的需求")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Text("我会先理解，再给出操作计划、确认卡和执行结果。")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.68))
        }
        .agentPanel(fill: Color.white.opacity(0.05), stroke: Color.white.opacity(0.06))
    }

    @ViewBuilder
    private func messageBubble(_ message: AssistantMessage) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .assistant {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        messageAvatar(for: .assistant)
                        messageLabel("助理", tint: AppTheme.Colors.accent)
                    }
                    bubble(
                        message.content,
                        fill: Color.white.opacity(0.09),
                        foreground: .white,
                        alignment: .leading,
                        stroke: Color.white.opacity(0.06)
                    )
                }
                Spacer(minLength: 34)
            } else {
                Spacer(minLength: 34)
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 6) {
                        messageLabel("你", tint: .white)
                        messageAvatar(for: .user)
                    }
                    bubble(
                        message.content,
                        fill: AppTheme.Colors.accent,
                        foreground: .white,
                        alignment: .trailing,
                        stroke: AppTheme.Colors.accent.opacity(0.15)
                    )
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func bubble(_ text: String, fill: Color, foreground: Color, alignment: Alignment, stroke: Color) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(foreground)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
            .frame(maxWidth: 540, alignment: alignment)
    }

    private var thinkingBubble: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    messageAvatar(for: .assistant)
                    messageLabel("助理", tint: AppTheme.Colors.accent)
                }
                HStack(spacing: 10) {
                    if streamingAssistantReply.isEmpty {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(AppTheme.Colors.accent)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("正在思考")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(thinkingHintText)
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.62))
                        }
                    } else {
                        Text(streamingAssistantReply)
                            .font(.body)
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
            }
            Spacer(minLength: 34)
        }
        .padding(.vertical, 2)
    }

    private func messageAvatar(for role: MessageRole) -> some View {
        ZStack {
            Circle()
                .fill(role == .assistant ? AppTheme.Colors.accent.opacity(0.18) : Color.white.opacity(0.12))
            Image(systemName: role == .assistant ? "sparkles" : "person.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(role == .assistant ? AppTheme.Colors.accent : .white)
        }
        .frame(width: 20, height: 20)
    }

    private func messageLabel(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 2)
    }

    private func planningPreviewCard(title: String, summary: String, bullets: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.accent)
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.white)

            ForEach(bullets, id: \.self) { bullet in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(AppTheme.Colors.accent.opacity(0.9))
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)
                    Text(bullet)
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.66))
                }
            }
        }
        .agentPanel(fill: Color.white.opacity(0.04), stroke: Color.white.opacity(0.05))
    }

    private var composerBar: some View {
        VStack(spacing: 10) {
            if isListening || voiceInputViewModel.liveTranscript.isEmpty == false || voiceInputViewModel.committedTranscript.isEmpty == false {
                compactVoiceStatus
            }

            HStack(spacing: 12) {
                circularToolButton(systemName: "camera.fill")

                Button {
                    Task {
                        await voiceInputViewModel.toggleRecording()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: microphoneSymbol)
                            .font(.headline)
                        Text(isListening ? "松开结束" : "按住说话")
                            .font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(isListening ? AppTheme.Colors.accent.opacity(0.9) : Color.white.opacity(0.05), lineWidth: 1)
                    )
                }

                Button {
                    if voiceInputViewModel.committedTranscript.isEmpty == false {
                        voiceInputViewModel.insertTranscript(into: &draftInput)
                    }
                } label: {
                    circularToolButton(systemName: "keyboard")
                }
                .buttonStyle(.plain)
            }

            if draftInput.isEmpty == false {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("输入你的需求...", text: $draftInput, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)

                    HStack {
                        Text("发送后会先给你计划，再确认执行。")
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.55))
                        Spacer()
                        Button("发送") {
                            sendCurrentInput()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.Colors.accent)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
            }
        }
        .appPageLayout()
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.black.opacity(0.9))
    }

    private var compactVoiceStatus: some View {
        HStack(spacing: 10) {
            Image(systemName: microphoneSymbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(microphoneTint)

            VStack(alignment: .leading, spacing: 2) {
                Text(voiceStatusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)

                if voiceInputViewModel.liveTranscript.isEmpty == false {
                    Text(voiceInputViewModel.liveTranscript)
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.72))
                        .lineLimit(2)
                } else if voiceInputViewModel.committedTranscript.isEmpty == false {
                    Text(voiceInputViewModel.committedTranscript)
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.72))
                        .lineLimit(2)
                }
            }

            Spacer()

            if voiceInputViewModel.committedTranscript.isEmpty == false {
                Button("插入") {
                    voiceInputViewModel.insertTranscript(into: &draftInput)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    private func sendCurrentInput() {
        let cleaned = draftInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.isEmpty == false else { return }

        draftInput = ""
        isThinking = true
        streamingAssistantReply = ""
        currentRequestNeedsDrafts = shouldGenerateDrafts(for: cleaned)
        Task {
            await generateDrafts(for: cleaned)
        }
    }

    @MainActor
    private func generateDrafts(for input: String) async {
        messages.append(AssistantMessage(role: .user, content: input))
        defer {
            isThinking = false
            streamingAssistantReply = ""
            currentRequestNeedsDrafts = false
        }

        let needsDrafts = shouldGenerateDrafts(for: input)
        let history = messageHistory(for: input, needsDrafts: needsDrafts)

        if needsDrafts == false {
            pendingDrafts = completedDrafts
            draftStates = draftStates.filter { _, state in
                if case .succeeded = state { return true }
                return false
            }
        }

        if let streamedReply = await streamReplyViaLLM(for: input, history: history) {
            messages.append(AssistantMessage(role: .assistant, content: streamedReply))

            if needsDrafts, let drafts = await generateDraftsOnlyViaLLM(for: input), drafts.isEmpty == false {
                let completed = completedDrafts
                pendingDrafts = completed + drafts
                for draft in drafts {
                    draftStates[draft.id] = .pending
                }
                selectedDraftIDs = Set(drafts.map(\.id))
            }
            return
        }

        let hasCalendarIntent = input.contains("日历") || input.contains("会议") || input.contains("安排") || input.contains("行程")
        var calendarEvents: [CalendarEventSummary] = []

        if hasCalendarIntent {
            let granted = await container.integrations.calendar.requestAccess()
            if granted {
                let inferredDate = inferredPlanningDate(from: input)
                calendarEvents = (try? await container.integrations.calendar.events(on: inferredDate)) ?? []
            }
        }

        let parsed = container.assistantEngine.parse(input, calendarEvents: calendarEvents)
        container.llmDebugStatus.lastSource = .localFallback
        container.llmDebugStatus.lastUpdatedAt = Date()
        messages.append(AssistantMessage(role: .assistant, content: parsed.summary))
        if parsed.drafts.isEmpty == false {
            let completed = completedDrafts
            pendingDrafts = completed + parsed.drafts
            for draft in parsed.drafts {
                draftStates[draft.id] = .pending
            }
            selectedDraftIDs = Set(parsed.drafts.map(\.id))
        }
    }

    @MainActor
    private func streamReplyViaLLM(for input: String, history: [AssistantMessage]) async -> String? {
        do {
            let reply = try await container.integrations.llm.streamReply(to: input, history: history) { partial in
                Task { @MainActor in
                    streamingAssistantReply = partial
                    isThinking = partial.isEmpty
                }
            }
            container.llmDebugStatus.providerName = "百炼兼容接口"
            container.llmDebugStatus.modelName = BailianSettingsStore.model
            container.llmDebugStatus.isConfigured = BailianSettingsStore.isConfigured
            container.llmDebugStatus.lastSource = .bailian
            container.llmDebugStatus.lastErrorMessage = nil
            container.llmDebugStatus.lastUpdatedAt = Date()
            return reply
        } catch {
            container.llmDebugStatus.providerName = "百炼兼容接口"
            container.llmDebugStatus.modelName = BailianSettingsStore.model
            container.llmDebugStatus.isConfigured = BailianSettingsStore.isConfigured
            container.llmDebugStatus.lastSource = .localFallback
            container.llmDebugStatus.lastErrorMessage = error.localizedDescription
            container.llmDebugStatus.lastUpdatedAt = Date()
            return nil
        }
    }

    @MainActor
    private func generateDraftsOnlyViaLLM(for input: String) async -> [AssistantActionDraft]? {
        do {
            return try await container.integrations.llm.generateDrafts(from: input)
        } catch {
            return nil
        }
    }

    private func shouldGenerateDrafts(for input: String) -> Bool {
        let draftKeywords = ["安排", "行程", "出差", "提醒", "会议", "日程", "任务", "规划"]
        return draftKeywords.contains { input.contains($0) }
    }

    private func shouldCarryConversationContext(for input: String, needsDrafts: Bool) -> Bool {
        if needsDrafts {
            return true
        }

        let followupKeywords = ["这个", "那个", "它", "继续", "然后", "再", "刚才", "上面", "刚刚", "前面", "为什么", "怎么说", "细一点", "展开", "详细", "具体", "推荐", "建议", "还有呢"]
        return followupKeywords.contains { input.contains($0) }
    }

    private func messageHistory(for input: String, needsDrafts: Bool) -> [AssistantMessage] {
        guard shouldCarryConversationContext(for: input, needsDrafts: needsDrafts) else {
            return []
        }

        let historyWindow = needsDrafts ? 4 : 2
        return Array(messages.dropLast().suffix(historyWindow))
    }

    private var thinkingHintText: String {
        currentRequestNeedsDrafts ? "正在拆解需求并生成可执行操作。" : "正在整理回复。"
    }

    @MainActor
    private func executeDraft(_ draft: AssistantActionDraft) async {
        draftStates[draft.id] = .executing

        do {
            switch draft.payload {
            case .event(let payload):
                let granted = await container.integrations.calendar.requestAccess()
                guard granted else {
                    draftStates[draft.id] = .failed("日历权限未授予")
                    return
                }
                try await container.integrations.calendar.createEvent(from: payload)
                draftStates[draft.id] = .succeeded("已写入系统日历")
                messages.append(AssistantMessage(role: .assistant, content: "已创建日程：\(payload.title)"))

            case .reminder(let payload):
                let granted = await container.integrations.reminders.requestAccess()
                guard granted else {
                    draftStates[draft.id] = .failed("提醒事项权限未授予")
                    return
                }
                try await container.integrations.reminders.createReminder(from: payload)
                draftStates[draft.id] = .succeeded("已写入提醒事项")
                messages.append(AssistantMessage(role: .assistant, content: "已创建提醒：\(payload.title)"))

            case .trip(let payload):
                let calendarGranted = await container.integrations.calendar.requestAccess()
                guard calendarGranted else {
                    draftStates[draft.id] = .failed("日历权限未授予")
                    return
                }

                let remindersGranted = await container.integrations.reminders.requestAccess()

                for eventDraft in payload.eventDrafts {
                    try await container.integrations.calendar.createEvent(from: eventDraft)
                }

                if remindersGranted {
                    for reminderDraft in payload.reminderDrafts {
                        try await container.integrations.reminders.createReminder(from: reminderDraft)
                    }
                }

                let summary = buildTripSummary(from: payload)
                container.tripViewModel.summary = summary
                container.todayViewModel.agendaItems = makeTodayAgendaItems(from: payload.eventDrafts)
                container.todayViewModel.suggestedAction = draft
                container.todayViewModel.routeRecommendation = makeRouteRecommendation(for: payload)

                let reminderSuffix = remindersGranted ? "并同步了提醒事项" : "，但提醒事项权限未授予"
                draftStates[draft.id] = .succeeded("已生成并写入系统行程")
                messages.append(AssistantMessage(role: .assistant, content: "已把 \(payload.destination) 行程写入系统日历\(reminderSuffix)。"))
            case .expense:
                draftStates[draft.id] = .failed("费用执行链路下一步接入")
            case .route:
                draftStates[draft.id] = .failed("路线执行链路下一步接入")
            }
        } catch {
            draftStates[draft.id] = .failed(error.localizedDescription)
        }
    }

    private func dismissDraft(_ draft: AssistantActionDraft) {
        pendingDrafts.removeAll { $0.id == draft.id }
        draftStates[draft.id] = .failed("已忽略")
        selectedDraftIDs.remove(draft.id)
    }

    private var pendingActionCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(spacing: 10) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.blue.opacity(0.9))
                Text("确认 \(pendingActionDrafts.count) 项操作")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)

            ForEach(pendingActionDrafts) { draft in
                selectableDraftListRow(draft: draft, state: draftStates[draft.id] ?? .pending)
            }

            HStack(spacing: 14) {
                Button("取消") {
                    dismissAllPendingDrafts()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button("确认") {
                    Task {
                        await executeSelectedDrafts()
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(AppTheme.Colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .disabled(selectedDraftIDs.isEmpty)
            }
        }
        .agentPanel(fill: Color.white.opacity(0.04), stroke: Color.white.opacity(0.05))
    }

    private var completedActionCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.accent)
                Text("已完成 \(completedDrafts.count) 项操作")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)

            ForEach(completedDrafts) { draft in
                draftListRow(draft: draft, state: draftStates[draft.id] ?? .succeeded("已完成"))
            }

            HStack(spacing: 12) {
                Button("查看日历") {}
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button("完成") {
                    clearCompletedDrafts()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AppTheme.Colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .agentPanel(fill: Color.white.opacity(0.04), stroke: Color.white.opacity(0.05))
    }

    private func draftListRow(draft: AssistantActionDraft, state: DraftExecutionState) -> some View {
        HStack(spacing: 14) {
            Image(systemName: iconName(for: state))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(iconTint(for: state))
                .frame(width: 18)

            statusPill(for: draft, state: state)

            VStack(alignment: .leading, spacing: 4) {
                Text(draft.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(draft.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.56))
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.white.opacity(0.3))
        }
    }

    private func selectableDraftListRow(draft: AssistantActionDraft, state: DraftExecutionState) -> some View {
        Button {
            toggleDraftSelection(draft)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: selectedDraftIDs.contains(draft.id) ? "checkmark.circle.fill" : "circle")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(selectedDraftIDs.contains(draft.id) ? AppTheme.Colors.accent : Color.white.opacity(0.25))
                    .frame(width: 22)

                statusPill(for: draft, state: state)

                VStack(alignment: .leading, spacing: 4) {
                    Text(draft.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(draft.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.56))
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.white.opacity(0.3))
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func statusPill(for draft: AssistantActionDraft, state: DraftExecutionState) -> some View {
        let text: String
        let fill: Color
        let tint: Color

        switch state {
        case .pending:
            text = draft.actionType == .createTrip ? "计划" : "创建"
            fill = AppTheme.Colors.accent.opacity(0.18)
            tint = AppTheme.Colors.accent
        case .executing:
            text = "处理中"
            fill = Color.orange.opacity(0.18)
            tint = .orange
        case .succeeded:
            text = "完成"
            fill = AppTheme.Colors.accent.opacity(0.18)
            tint = AppTheme.Colors.accent
        case .failed:
            text = "失败"
            fill = Color.red.opacity(0.18)
            tint = .red
        }

        return Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func iconName(for state: DraftExecutionState) -> String {
        switch state {
        case .pending: return "circle"
        case .executing: return "ellipsis.circle.fill"
        case .succeeded: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    private func iconTint(for state: DraftExecutionState) -> Color {
        switch state {
        case .pending: return Color.white.opacity(0.35)
        case .executing: return .orange
        case .succeeded: return AppTheme.Colors.accent
        case .failed: return .red
        }
    }

    private var processLane: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(processingSteps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 8) {
                    Image(systemName: index == processingSteps.count - 1 && isThinking ? "brain.head.profile" : "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(index == processingSteps.count - 1 && isThinking ? Color.white.opacity(0.8) : Color.white.opacity(0.45))
                    Text(step)
                        .font(.caption.weight(index == processingSteps.count - 1 ? .semibold : .regular))
                        .foregroundStyle(Color.white.opacity(index == processingSteps.count - 1 ? 0.88 : 0.48))
                }
            }
        }
        .padding(.horizontal, 6)
    }

    private var voiceRecordingOverlay: some View {
        ZStack {
            Color.black.opacity(0.32)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.accent.opacity(0.18))
                        .frame(width: 96, height: 96)
                    Circle()
                        .fill(AppTheme.Colors.accent)
                        .frame(width: 70, height: 70)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                }

                voiceWaveform

                Text(voiceOverlayTimerText)
                    .font(.system(size: 46, weight: .light, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Text("recording")
                    .font(.headline)
                    .foregroundStyle(Color.white.opacity(0.62))

                Text("向上滑动取消")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.42))
            }
            .frame(width: 300)
            .padding(.vertical, 28)
            .background(Color(red: 0.18, green: 0.18, blue: 0.19).opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )

            VStack {
                Spacer()
                Button {
                    Task {
                        await voiceInputViewModel.toggleRecording()
                    }
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.95))
                            Image(systemName: "xmark")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 74, height: 74)
                        Text("取消")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .padding(.bottom, 110)
            }
        }
        .transition(.opacity)
    }

    private var voiceWaveform: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(voiceInputViewModel.levelSamples.enumerated()), id: \.offset) { _, sample in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(AppTheme.Colors.accent)
                    .frame(width: 8, height: max(18, sample * 70))
            }
        }
        .frame(height: 80)
    }

    private var voiceOverlayTimerText: String {
        if voiceInputViewModel.liveTranscript.isEmpty {
            return "0.8s"
        }

        let estimate = Double(max(1, voiceInputViewModel.liveTranscript.count)) * 0.16
        return String(format: "%.1fs", estimate)
    }

    private var processingSteps: [String] {
        if currentRequestNeedsDrafts {
            return ["搜索完成", "正在解析时间", "正在生成操作"]
        }
        if isThinking || streamingAssistantReply.isEmpty == false {
            return ["分析中…"]
        }
        return []
    }

    private var topControlBar: some View {
        HStack {
            circularToolButton(systemName: "line.3.horizontal")
            Spacer()
            circularToolButton(systemName: "yensign.circle")
            circularToolButton(systemName: "calendar")
        }
    }

    private func circularToolButton(systemName: String) -> some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.07))
            Image(systemName: systemName)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 46, height: 46)
    }

    private var agentBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.08, blue: 0.09),
                Color(red: 0.10, green: 0.10, blue: 0.11),
                Color(red: 0.07, green: 0.08, blue: 0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay {
            Circle()
                .fill(AppTheme.Colors.accent.opacity(0.08))
                .frame(width: 280, height: 280)
                .blur(radius: 50)
                .offset(x: 0, y: -120)
        }
    }

    private var pendingActionDrafts: [AssistantActionDraft] {
        pendingDrafts.filter {
            if case .pending = draftStates[$0.id] ?? .pending { return true }
            if case .executing = draftStates[$0.id] ?? .pending { return true }
            return false
        }
    }

    private var completedDrafts: [AssistantActionDraft] {
        pendingDrafts.filter {
            if case .succeeded = draftStates[$0.id] { return true }
            return false
        }
    }

    private func executeSelectedDrafts() async {
        let drafts = pendingActionDrafts.filter { selectedDraftIDs.contains($0.id) }
        for draft in drafts {
            if case .pending = draftStates[draft.id] ?? .pending {
                await executeDraft(draft)
            }
        }
        selectedDraftIDs.subtract(drafts.map(\.id))
    }

    private func dismissAllPendingDrafts() {
        for draft in pendingActionDrafts {
            dismissDraft(draft)
        }
        selectedDraftIDs.removeAll()
    }

    private func clearCompletedDrafts() {
        pendingDrafts.removeAll {
            if case .succeeded = draftStates[$0.id] { return true }
            return false
        }
        draftStates = draftStates.filter { _, state in
            if case .succeeded = state { return false }
            return true
        }
    }

    private func toggleDraftSelection(_ draft: AssistantActionDraft) {
        if selectedDraftIDs.contains(draft.id) {
            selectedDraftIDs.remove(draft.id)
        } else {
            selectedDraftIDs.insert(draft.id)
        }
    }

    private var isListening: Bool {
        if case .listening = voiceInputViewModel.phase {
            return true
        }
        return false
    }

    private var voiceStatusText: String {
        switch voiceInputViewModel.phase {
        case .idle:
            return voiceInputViewModel.permissionSummary.statusText
        case .requestingPermission:
            return "正在请求麦克风与语音识别权限"
        case .listening:
            return "正在聆听，请直接说出你的日程或提醒需求"
        case .transcribing:
            return "正在整理转写结果"
        case .ready:
            return "转写完成，可一键插入输入框"
        case .failed(let message):
            return message
        }
    }

    private var microphoneSymbol: String {
        isListening ? "stop.circle.fill" : "mic.fill"
    }

    private var microphoneTint: Color {
        switch voiceInputViewModel.phase {
        case .failed:
            return .red
        case .listening:
            return AppTheme.Colors.accent
        default:
            return .white
        }
    }

    private func inferredPlanningDate(from input: String) -> Date {
        let calendar = Calendar.current
        if input.contains("后天") {
            return calendar.date(byAdding: .day, value: 2, to: Date()) ?? Date()
        }
        if input.contains("明天") {
            return calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        }
        return Date()
    }

    private func buildTripSummary(from payload: TripDraftPayload) -> TripPlanSummary {
        let timelineItems = payload.eventDrafts.map { draft in
            TripTimelineItem(
                time: draft.startDate.formatted(date: .omitted, time: .shortened),
                title: draft.title,
                detail: draft.location ?? draft.notes ?? payload.destination
            )
        }

        return TripPlanSummary(
            title: payload.title,
            dateRange: payload.dateRangeText,
            summary: payload.summary,
            timelineItems: timelineItems,
            budgetSpent: 0,
            budgetTotal: 0,
            pendingItems: [
                "确认交通班次",
                "补充酒店和联系人信息",
                "按实际情况调整主行程"
            ]
        )
    }

    private func makeTodayAgendaItems(from eventDrafts: [CalendarEventDraftPayload]) -> [TodayAgendaItem] {
        eventDrafts.prefix(4).map { draft in
            TodayAgendaItem(
                timeRange: "\(draft.startDate.formatted(date: .omitted, time: .shortened)) - \(draft.endDate.formatted(date: .omitted, time: .shortened))",
                title: draft.title,
                detail: draft.location ?? draft.notes ?? "已由助理生成",
                kind: agendaKind(for: draft.title)
            )
        }
    }

    private func agendaKind(for title: String) -> AgendaKind {
        if title.contains("出发") || title.contains("返程") {
            return .travel
        }
        if title.contains("入住") {
            return .task
        }
        return .meeting
    }

    private func makeRouteRecommendation(for payload: TripDraftPayload) -> RouteRecommendation {
        RouteRecommendation(
            departureTime: payload.eventDrafts.first?.startDate.formatted(date: .omitted, time: .shortened) ?? "待确认",
            origin: container.profile.homeCity,
            destination: payload.destination,
            durationMinutes: 120,
            bufferMinutes: 45,
            options: [
                RouteOption(title: "高铁优先", detail: "\(container.profile.homeCity) → \(payload.destination)", badge: "推荐"),
                RouteOption(title: "航班备选", detail: "适合跨省快速抵达", badge: nil)
            ]
        )
    }
}

private extension View {
    func agentPanel(fill: Color, stroke: Color) -> some View {
        self
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(fill)
                    .stroke(stroke, lineWidth: 1)
            )
    }
}
