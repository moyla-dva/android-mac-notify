import SwiftUI

struct MenuHeader: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: appState.menuSymbolName)
                .font(.title3)
                .foregroundStyle(connectionColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(appState.connectionState.title)
                    .font(.headline)
                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                toggleReceiver()
            } label: {
                Image(systemName: receiverButtonSymbol)
            }
            .help(receiverButtonHelp)
        }
    }

    private var statusLine: String {
        if let summary = appState.lastNotificationSummary {
            return "最近接力 \(summary.receivedRelativeText) · 今日 \(appState.notificationsReceived) 个事件"
        }
        return "今日 \(appState.notificationsReceived) 个事件"
    }

    private var connectionColor: Color {
        switch appState.connectionState {
        case .connected:
            return .green
        case .waitingForPair, .disconnectedRetrying, .macReceiverPaused, .deviceRelayPaused:
            return .orange
        case .unpaired, .authFailed, .networkUnavailable:
            return .secondary
        }
    }

    private var receiverButtonSymbol: String {
        switch appState.serverStatus {
        case .running:
            return appState.isReceiverPaused ? "play.circle" : "pause.circle"
        case .stopped, .failed:
            return "play.circle"
        }
    }

    private var receiverButtonHelp: String {
        switch appState.serverStatus {
        case .running:
            return appState.isReceiverPaused ? "恢复接力" : "暂停接力"
        case .stopped, .failed:
            return "开始接力"
        }
    }

    private func toggleReceiver() {
        switch appState.serverStatus {
        case .running:
            appState.toggleReceiverPause()
        case .stopped, .failed:
            appState.startLocalServer()
        }
    }
}
