import SwiftUI

@main
struct OrionAssistantApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .environmentObject(container)
                .task {
                    await container.refreshIntegrationStatus()
                }
        }
    }
}
