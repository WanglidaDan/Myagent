import Foundation
import Combine

struct UserProfile {
    var displayName: String
    var homeCity: String
    var preferredTravelMode: TransportMode
    var defaultCalendarName: String
    var defaultReminderListName: String
}

struct TodayAgendaItem: Identifiable {
    let id = UUID()
    let timeRange: String
    let title: String
    let detail: String
    let kind: AgendaKind
}

enum AgendaKind {
    case meeting
    case task
    case travel
}

struct AssistantMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
}

enum MessageRole {
    case user
    case assistant
}

struct AssistantActionDraft: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let actionType: ActionType
    let requiresConfirmation: Bool
    let payload: AssistantDraftPayload
}

enum ActionType: String {
    case createEvent = "创建日程"
    case createReminder = "创建提醒"
    case createTrip = "生成行程"
    case createExpense = "录入费用"
    case createRoute = "规划路线"
}

enum AssistantDraftPayload {
    case event(CalendarEventDraftPayload)
    case reminder(ReminderDraftPayload)
    case trip(TripDraftPayload)
    case expense(String)
    case route(String)
}

struct CalendarEventDraftPayload {
    let title: String
    let startDate: Date
    let endDate: Date
    let notes: String?
    let location: String?
    let alarmOffsetMinutes: Int?
    let conflictTitles: [String]
    let suggestedAlternatives: [CalendarTimeOption]
}

struct ReminderDraftPayload {
    let title: String
    let dueDate: Date?
    let notes: String?
}

struct TripDraftPayload {
    let title: String
    let destination: String
    let dateRangeText: String
    let summary: String
    let eventDrafts: [CalendarEventDraftPayload]
    let reminderDrafts: [ReminderDraftPayload]
}

struct CalendarTimeOption: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let startDate: Date
    let endDate: Date
}

struct CalendarEventSummary: Identifiable {
    let id = UUID()
    let title: String
    let startDate: Date
    let endDate: Date
}

enum DraftExecutionState: Equatable {
    case pending
    case executing
    case succeeded(String)
    case failed(String)
}

struct TripPlanSummary {
    let title: String
    let dateRange: String
    let summary: String
    let timelineItems: [TripTimelineItem]
    let budgetSpent: Decimal
    let budgetTotal: Decimal
    let pendingItems: [String]
}

struct TripTimelineItem: Identifiable {
    let id = UUID()
    let time: String
    let title: String
    let detail: String
}

struct ExpenseSummary {
    let monthLabel: String
    let totalAmount: Decimal
    let categoryBreakdown: [ExpenseCategoryBreakdown]
    let pendingSubmissionCount: Int
    let pendingReviewCount: Int
    let recentItems: [ExpenseItem]
}

struct ExpenseCategoryBreakdown: Identifiable {
    let id = UUID()
    let title: String
    let amount: Decimal
}

struct ExpenseItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let amount: Decimal
    let status: ExpenseStatus
}

enum ExpenseStatus: String {
    case pendingSubmission = "待提交"
    case reviewNeeded = "待复核"
    case reimbursed = "已报销"
}

struct RouteRecommendation {
    let departureTime: String
    let origin: String
    let destination: String
    let durationMinutes: Int
    let bufferMinutes: Int
    let options: [RouteOption]
}

struct RouteOption: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let badge: String?
}

enum TransportMode: String, CaseIterable {
    case taxi = "打车"
    case transit = "公共交通"
    case driving = "自驾"
    case walking = "步行"
}

struct IntegrationStatus {
    var calendarAccessGranted: Bool
    var remindersAccessGranted: Bool
    var notificationsAccessGranted: Bool
    var locationAccessGranted: Bool
    var cameraAccessGranted: Bool
    var microphoneAccessGranted: Bool
    var speechRecognitionGranted: Bool
    var llmProviderName: String
}

enum LLMCallSource: String {
    case unknown = "未调用"
    case bailian = "百炼成功"
    case localFallback = "本地回退"
}

struct LLMDebugStatus {
    var providerName: String
    var modelName: String
    var isConfigured: Bool
    var lastSource: LLMCallSource
    var lastErrorMessage: String?
    var lastUpdatedAt: Date?

    var summaryText: String {
        if let lastUpdatedAt {
            return "\(lastSource.rawValue) · \(lastUpdatedAt.formatted(date: .omitted, time: .shortened))"
        }
        return lastSource.rawValue
    }
}

@MainActor
final class AppContainer: ObservableObject {
    let profile: UserProfile
    let assistantEngine: AssistantEngine
    let integrations: SystemIntegrationServices
    private let permissionStatusService = PermissionStatusService()

    let todayViewModel: TodayDashboardViewModel
    let assistantViewModel: AssistantChatViewModel
    let tripViewModel: TripPlannerViewModel
    let expenseViewModel: ExpenseCenterViewModel
    @Published var integrationStatus: IntegrationStatus
    @Published var llmDebugStatus: LLMDebugStatus
    let voiceInputViewModel: VoiceInputViewModel

    init() {
        profile = MockData.profile
        integrations = .live
        assistantEngine = AssistantEngine()
        let initialIntegrationStatus = IntegrationStatus(
            calendarAccessGranted: false,
            remindersAccessGranted: false,
            notificationsAccessGranted: false,
            locationAccessGranted: false,
            cameraAccessGranted: false,
            microphoneAccessGranted: false,
            speechRecognitionGranted: false,
            llmProviderName: BailianSettingsStore.isConfigured ? "百炼（已配置）" : "百炼（待配置）"
        )
        integrationStatus = initialIntegrationStatus
        llmDebugStatus = MockData.initialLLMDebugStatus
        voiceInputViewModel = VoiceInputViewModel(service: integrations.voiceInput, integrationStatus: initialIntegrationStatus)
        todayViewModel = TodayDashboardViewModel(
            greeting: "准备开始安排今天",
            suggestedAction: nil,
            agendaItems: [],
            routeRecommendation: nil
        )
        assistantViewModel = AssistantChatViewModel(
            messages: [],
            quickPrompts: MockData.quickPrompts
        )
        tripViewModel = TripPlannerViewModel(summary: nil)
        expenseViewModel = ExpenseCenterViewModel(summary: MockData.emptyExpenseSummary)
    }

    func refreshIntegrationStatus() async {
        let permissions = await permissionStatusService.refresh()
        let providerName = BailianSettingsStore.isConfigured ? "百炼（已配置）" : "百炼（待配置）"

        integrationStatus = permissions.integrationStatus(llmProviderName: providerName)
        voiceInputViewModel.permissionSummary = permissions.voicePermissionSummary
        llmDebugStatus.providerName = "百炼兼容接口"
        llmDebugStatus.modelName = BailianSettingsStore.model
        llmDebugStatus.isConfigured = BailianSettingsStore.isConfigured
    }
}

@MainActor
final class TodayDashboardViewModel: ObservableObject {
    let greeting: String
    @Published var suggestedAction: AssistantActionDraft?
    @Published var agendaItems: [TodayAgendaItem]
    @Published var routeRecommendation: RouteRecommendation?

    init(greeting: String, suggestedAction: AssistantActionDraft?, agendaItems: [TodayAgendaItem], routeRecommendation: RouteRecommendation?) {
        self.greeting = greeting
        self.suggestedAction = suggestedAction
        self.agendaItems = agendaItems
        self.routeRecommendation = routeRecommendation
    }
}

struct AssistantChatViewModel {
    let messages: [AssistantMessage]
    let quickPrompts: [String]
}

enum VoiceInputPhase {
    case idle
    case requestingPermission
    case listening
    case transcribing
    case ready
    case failed(String)
}

struct VoicePermissionSummary {
    let microphoneGranted: Bool
    let speechRecognitionGranted: Bool

    var allGranted: Bool {
        microphoneGranted && speechRecognitionGranted
    }

    var statusText: String {
        switch (microphoneGranted, speechRecognitionGranted) {
        case (true, true): "语音输入已就绪"
        case (false, false): "需要麦克风和语音识别权限"
        case (false, true): "需要麦克风权限"
        case (true, false): "需要语音识别权限"
        }
    }
}

@MainActor
final class VoiceInputViewModel: ObservableObject {
    @Published var phase: VoiceInputPhase = .idle
    @Published var liveTranscript = ""
    @Published var committedTranscript = ""
    @Published var levelSamples: [Double] = [0.18, 0.32, 0.24, 0.44, 0.27, 0.38]
    @Published var permissionSummary: VoicePermissionSummary
    @Published var lastErrorMessage: String?

    private let service: VoiceInputService

    init(service: VoiceInputService, integrationStatus: IntegrationStatus) {
        self.service = service
        self.permissionSummary = VoicePermissionSummary(
            microphoneGranted: integrationStatus.microphoneAccessGranted,
            speechRecognitionGranted: integrationStatus.speechRecognitionGranted
        )
    }

    @MainActor
    func toggleRecording() async {
        switch phase {
        case .listening:
            await stopRecording()
        case .requestingPermission, .transcribing:
            break
        case .idle, .ready, .failed:
            await startRecording()
        }
    }

    @MainActor
    func insertTranscript(into text: inout String) {
        let cleaned = committedTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.isEmpty == false else { return }
        text = text.isEmpty ? cleaned : "\(text)\n\(cleaned)"
        committedTranscript = ""
        phase = .idle
    }

    @MainActor
    private func startRecording() async {
        phase = .requestingPermission
        lastErrorMessage = nil

        do {
            let permissions = try await service.requestPermissions()
            permissionSummary = permissions

            guard permissions.allGranted else {
                lastErrorMessage = permissions.statusText
                phase = .failed(permissions.statusText)
                return
            }

            phase = .listening
            liveTranscript = ""
            committedTranscript = ""
            levelSamples = [0.22, 0.48, 0.35, 0.62, 0.29, 0.41]

            try await service.startRecognition { [weak self] transcript, levels in
                Task { @MainActor in
                    self?.liveTranscript = transcript
                    self?.levelSamples = levels
                }
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            phase = .failed("语音输入启动失败")
        }
    }

    @MainActor
    private func stopRecording() async {
        phase = .transcribing

        do {
            let finalTranscript = try await service.stopRecognition()
            committedTranscript = finalTranscript
            liveTranscript = ""
            levelSamples = [0.16, 0.22, 0.18, 0.25, 0.14, 0.19]
            phase = .ready
        } catch {
            lastErrorMessage = error.localizedDescription
            phase = .failed("转写结果生成失败")
        }
    }
}

@MainActor
final class TripPlannerViewModel: ObservableObject {
    @Published var summary: TripPlanSummary?

    init(summary: TripPlanSummary?) {
        self.summary = summary
    }
}

struct ExpenseCenterViewModel {
    let summary: ExpenseSummary
}
