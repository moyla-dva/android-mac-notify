import SwiftUI

@main
struct AndroidMacNotifyMacApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup("Android Mac Notify", id: "main") {
            DashboardView(appState: appState)
                .onAppear {
                    Task { @MainActor in
                        StatusBarController.shared.configure(appState: appState)
                    }
                }
        }
        .defaultSize(width: 860, height: 680)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("设置...") {
                    SettingsWindowPresenter.show(appState: appState)
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandMenu("Notify") {
                Button("显示主窗口") {
                    MainWindowPresenter.show()
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("打开设置") {
                    SettingsWindowPresenter.show(appState: appState)
                }
            }
        }

        Settings {
            SettingsView(appState: appState)
                .frame(minWidth: 420, minHeight: 280)
        }
    }
}
