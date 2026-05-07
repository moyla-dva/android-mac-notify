import SwiftUI

struct StatusMenuView: View {
    @ObservedObject var appState: AppState
    let onShowMainWindow: () -> Void
    let onShowSettings: () -> Void

    init(
        appState: AppState,
        onShowMainWindow: @escaping () -> Void = { MainWindowPresenter.show() },
        onShowSettings: @escaping () -> Void = {}
    ) {
        self.appState = appState
        self.onShowMainWindow = onShowMainWindow
        self.onShowSettings = onShowSettings
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuHeader(appState: appState)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            ScrollView {
                menuContent
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            Divider()
                .padding(.horizontal, 16)

            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .frame(width: 320, height: 440)
    }

    @ViewBuilder
    private var menuContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let actionFeedbackMessage = appState.actionFeedbackMessage {
                Label(
                    actionFeedbackMessage,
                    systemImage: appState.actionFeedbackIsFailure ? "exclamationmark.triangle" : "checkmark.circle"
                )
                .font(.callout)
                .foregroundStyle(appState.actionFeedbackIsFailure ? .orange : .secondary)
            }

            if let lastError = appState.lastError {
                Label(lastError, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            if !appState.actionInboxNotifications.isEmpty {
                Divider()
                MenuSection(title: "待处理", systemImage: "bolt.horizontal.circle") {
                    ForEach(Array(appState.actionInboxNotifications.prefix(3)), id: \.eventId) { summary in
                        MenuNotificationRow(summary: summary, appState: appState)
                    }

                    let remainingCount = appState.actionInboxNotifications.count - 3
                    if remainingCount > 0 {
                        Button {
                            onShowMainWindow()
                        } label: {
                            Label("还有 \(remainingCount) 条待处理", systemImage: "arrow.right.circle")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .help("打开主窗口查看全部待处理动作")
                    }
                }
            }

            if appState.sharedFileReceiveStatus != nil {
                Divider()
                MenuSection(title: "进行中", systemImage: "progress.indicator") {
                    VStack(alignment: .leading, spacing: 8) {
                        SharedFileReceiveInlineCardView(appState: appState)
                    }
                }
            }

            if !appState.recentSharedFileDeliveryGroups.isEmpty {
                Divider()
                MenuSection(title: "文件投递", systemImage: "tray.and.arrow.down") {
                    ForEach(Array(appState.recentSharedFileDeliveryGroups.prefix(2))) { group in
                        MenuSharedFileDeliveryGroupRow(group: group, appState: appState)
                    }
                }
            }

            if !appState.pendingPairingRequests.isEmpty {
                Divider()
                MenuSection(title: "配对请求", systemImage: "person.crop.circle.badge.questionmark") {
                    ForEach(appState.pendingPairingRequests.prefix(3), id: \.requestId) { request in
                        MenuPairingRow(request: request, appState: appState)
                    }
                }
            }

            if !appState.historyNotifications.isEmpty {
                Divider()
                MenuSection(title: "最近", systemImage: "clock.arrow.circlepath") {
                    ForEach(Array(appState.historyNotifications.prefix(3)), id: \.eventId) { summary in
                        MenuNotificationRow(summary: summary, appState: appState, compact: true)
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                onShowMainWindow()
            } label: {
                Label("主窗口", systemImage: "rectangle.on.rectangle")
            }

            Button {
                onShowSettings()
            } label: {
                Label("设置", systemImage: "gear")
            }
        }
        .buttonStyle(.borderless)
    }
}
