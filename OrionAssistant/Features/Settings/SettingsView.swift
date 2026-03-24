import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var container: AppContainer
    let integrationStatus: IntegrationStatus
    @AppStorage(BailianSettingsStore.apiKeyKey) private var bailianAPIKey = ""
    @AppStorage(BailianSettingsStore.baseURLKey) private var bailianBaseURL = BailianSettingsStore.defaultBaseURL
    @AppStorage(BailianSettingsStore.modelKey) private var bailianModel = BailianSettingsStore.defaultModel

    var body: some View {
        List {
            Section("系统集成") {
                permissionRow("日历", granted: integrationStatus.calendarAccessGranted)
                permissionRow("提醒事项", granted: integrationStatus.remindersAccessGranted)
                permissionRow("通知", granted: integrationStatus.notificationsAccessGranted)
                permissionRow("定位", granted: integrationStatus.locationAccessGranted)
                permissionRow("相机", granted: integrationStatus.cameraAccessGranted)
                permissionRow("麦克风", granted: integrationStatus.microphoneAccessGranted)
                permissionRow("语音识别", granted: integrationStatus.speechRecognitionGranted)
            }

            Section("AI") {
                LabeledContent("LLM Provider", value: bailianAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? integrationStatus.llmProviderName : "百炼（已配置）")
                LabeledContent("当前模型", value: container.llmDebugStatus.modelName)
                LabeledContent("最近调用", value: container.llmDebugStatus.summaryText)
                LabeledContent("动作执行策略", value: "先确认后写入系统")
                if let lastErrorMessage = container.llmDebugStatus.lastErrorMessage, lastErrorMessage.isEmpty == false {
                    Text("最近错误：\(lastErrorMessage)")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section("百炼配置") {
                SecureField("API Key", text: $bailianAPIKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Base URL", text: $bailianBaseURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                TextField("Model", text: $bailianModel)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Text("默认北京站点：\(BailianSettingsStore.defaultBaseURL)")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            Section("接下来") {
                Text("当前已接入百炼兼容接口、EventKit 和语音输入。下一阶段继续补 MapKit、票据扫描和费用管理。")
            }
        }
        .navigationTitle("设置")
        .scrollContentBackground(.hidden)
        .background(AppBackgroundView())
    }

    private func permissionRow(_ title: String, granted: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(granted ? AppTheme.Colors.accent : AppTheme.Colors.warning)
        }
    }
}
