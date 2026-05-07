import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var isConfirmingClearHistory = false
    @State private var isConfirmingResetPairing = false

    var body: some View {
        Form {
            SettingsPairingRequestsSection(appState: appState)
            SettingsRelayOverviewSection(appState: appState)
            SettingsPrivacyHistorySection {
                isConfirmingClearHistory = true
            }
            SettingsFileDeliverySection(appState: appState)
            SettingsAdvancedSection(appState: appState) {
                isConfirmingResetPairing = true
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 640, minHeight: 600)
        .confirmationDialog(
            "清空通知历史？",
            isPresented: $isConfirmingClearHistory,
            titleVisibility: .visible
        ) {
            Button("清空通知历史", role: .destructive) {
                appState.clearNotificationHistory()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这会删除 Mac 本地保存的最近通知和动作结果，不会影响配对设备。")
        }
        .confirmationDialog(
            "重置配对状态？",
            isPresented: $isConfirmingResetPairing,
            titleVisibility: .visible
        ) {
            Button("重置配对状态", role: .destructive) {
                appState.resetPairing()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这会删除 Mac 本地配对信息和通知历史，Android 端需要重新配对。")
        }
    }
}
