import Foundation

enum MockData {
    static let profile = UserProfile(
        displayName: "YQ",
        homeCity: "上海",
        preferredTravelMode: .taxi,
        defaultCalendarName: "工作",
        defaultReminderListName: "Orion"
    )

    static let quickPrompts = [
        "明天下午三点安排产品评审",
        "我要去丹东两天，给我安排下行程",
        "后天上午九点提醒我提交报销",
        "帮我规划明天去虹桥站的出发时间"
    ]

    static let emptyExpenseSummary = ExpenseSummary(
        monthLabel: "本月",
        totalAmount: 0,
        categoryBreakdown: [],
        pendingSubmissionCount: 0,
        pendingReviewCount: 0,
        recentItems: []
    )

    static let integrationStatus = IntegrationStatus(
        calendarAccessGranted: false,
        remindersAccessGranted: false,
        notificationsAccessGranted: false,
        locationAccessGranted: false,
        cameraAccessGranted: false,
        microphoneAccessGranted: true,
        speechRecognitionGranted: true,
        llmProviderName: "百炼（待配置）"
    )

    static let initialLLMDebugStatus = LLMDebugStatus(
        providerName: "百炼兼容接口",
        modelName: BailianSettingsStore.model,
        isConfigured: BailianSettingsStore.isConfigured,
        lastSource: .unknown,
        lastErrorMessage: nil,
        lastUpdatedAt: nil
    )
}
