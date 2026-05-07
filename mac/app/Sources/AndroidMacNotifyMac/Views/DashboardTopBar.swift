import SwiftUI

struct DashboardTopBar: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text("Android Mac Notify")
                    .font(.title3.weight(.semibold))

                Spacer()

                ConnectionBadge(
                    title: appState.connectionState.title,
                    systemImage: appState.menuSymbolName,
                    color: connectionColor
                )
            }

            HStack(spacing: 18) {
                TopStatusItem(
                    title: "最近接收",
                    value: appState.lastNotificationSummary?.receivedRelativeText ?? "暂无",
                    systemImage: "clock"
                )
                TopStatusItem(
                    title: "待处理",
                    value: "\(appState.actionInboxNotifications.count)",
                    systemImage: "bolt.horizontal.circle"
                )
                TopStatusItem(
                    title: "今日接收",
                    value: "\(appState.notificationsReceived)",
                    systemImage: "tray.and.arrow.down"
                )
                TopStatusItem(
                    title: "Mac 接收服务",
                    value: receiverSummary,
                    systemImage: "dot.radiowaves.left.and.right"
                )
            }
        }
        .padding(.bottom, 14)
        .overlay(
            Rectangle()
                .fill(Color.secondary.opacity(0.14))
                .frame(height: 1),
            alignment: .bottom
        )
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

    private var receiverSummary: String {
        switch appState.serverStatus {
        case let .running(host, port):
            return appState.isReceiverPaused ? "\(host):\(port) · 已暂停接收" : "\(host):\(port)"
        case .stopped:
            return "未启动"
        case .failed:
            return "异常"
        }
    }
}

struct SettingsButton: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Button {
            SettingsWindowPresenter.show(appState: appState)
        } label: {
            Label("设置", systemImage: "gearshape")
                .labelStyle(.iconOnly)
        }
        .help("设置")
        .accessibilityLabel("设置")
    }
}

private struct ConnectionBadge: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.callout.weight(.medium))
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

private struct TopStatusItem: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)
        }
        .labelStyle(.titleAndIcon)
        .frame(minWidth: 96, alignment: .leading)
    }
}
