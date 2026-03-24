import SwiftUI

struct AppShellView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        TabView {
            Tab("今日", systemImage: "sun.max.fill") {
                NavigationStack {
                    TodayDashboardView(viewModel: container.todayViewModel)
                }
            }

            Tab("助理", systemImage: "sparkles.rectangle.stack.fill") {
                NavigationStack {
                    AssistantChatView(
                        viewModel: container.assistantViewModel,
                        voiceInputViewModel: container.voiceInputViewModel
                    )
                }
            }

            Tab("行程", systemImage: "map.fill") {
                NavigationStack {
                    TripPlannerView(viewModel: container.tripViewModel)
                }
            }

            Tab("费用", systemImage: "wallet.pass.fill") {
                NavigationStack {
                    ExpenseCenterView(viewModel: container.expenseViewModel)
                }
            }

            Tab("设置", systemImage: "slider.horizontal.3") {
                NavigationStack {
                    SettingsView(integrationStatus: container.integrationStatus)
                }
            }
        }
        .tint(AppTheme.Colors.primary)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
