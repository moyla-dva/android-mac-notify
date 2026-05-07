import SwiftUI

struct DashboardInboxSection: View {
    @ObservedObject var appState: AppState
    var actionLimit: Int = 6
    var fileGroupLimit: Int = 3

    var body: some View {
        let actionNotifications = Array(appState.actionInboxNotifications.prefix(actionLimit))
        let fileGroups = Array(appState.recentSharedFileDeliveryGroups.prefix(fileGroupLimit))

        DashboardSection(
            title: "收件箱",
            systemImage: "tray.full",
            accessoryText: inboxAccessoryText(
                actionCount: appState.actionInboxNotifications.count,
                fileGroupCount: appState.recentSharedFileDeliveryGroups.count,
                hasActiveStatus: appState.sharedFileReceiveStatus != nil
            )
        ) {
            if actionNotifications.isEmpty &&
                fileGroups.isEmpty &&
                appState.sharedFileReceiveStatus == nil {
                EmptySectionRow(
                    title: "没有需要处理的内容",
                    systemImage: "checkmark.circle"
                )
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    if appState.sharedFileReceiveStatus != nil {
                        InboxSubheader(title: "进行中")
                        SharedFileReceiveInlineCardView(appState: appState)
                    }

                    if !actionNotifications.isEmpty {
                        InboxSubheader(
                            title: "通知动作",
                            detail: "\(appState.actionInboxNotifications.count)"
                        )
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(actionNotifications, id: \.eventId) { summary in
                                NotificationSummaryCard(summary: summary, appState: appState, style: .action)
                            }
                        }
                    }

                    if !fileGroups.isEmpty {
                        InboxSubheader(
                            title: "文件投递",
                            detail: sharedFileDeliveryAccessoryText(groups: appState.recentSharedFileDeliveryGroups)
                        )
                        VStack(alignment: .leading, spacing: 10) {
                            if let latestGroup = fileGroups.first {
                                SharedFileDeliveryGroupCard(group: latestGroup, appState: appState)
                            }

                            if fileGroups.count > 1 {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(fileGroups.dropFirst()) { group in
                                        SharedFileDeliveryHistoryRow(group: group, appState: appState)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func inboxAccessoryText(
        actionCount: Int,
        fileGroupCount: Int,
        hasActiveStatus: Bool
    ) -> String {
        let total = actionCount + fileGroupCount + (hasActiveStatus ? 1 : 0)
        return "\(total)"
    }

    private func sharedFileDeliveryAccessoryText(groups: [SharedFileDeliveryGroup]) -> String {
        guard !groups.isEmpty else {
            return "0"
        }
        return groups.count == 1 ? "1 批" : "\(groups.count) 批"
    }
}

private struct InboxSubheader: View {
    let title: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if let detail {
                Text(detail)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.10), in: Capsule())
            }

            Spacer()
        }
    }
}

struct ActionInboxSection: View {
    @ObservedObject var appState: AppState

    var body: some View {
        DashboardSection(
            title: "待处理动作",
            systemImage: "bolt.horizontal.circle",
            accessoryText: "\(appState.actionInboxNotifications.count)"
        ) {
            if appState.actionInboxNotifications.isEmpty {
                EmptySectionRow(
                    title: "没有待处理动作",
                    systemImage: "checkmark.circle"
                )
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(appState.actionInboxNotifications.prefix(8), id: \.eventId) { summary in
                        NotificationSummaryCard(summary: summary, appState: appState, style: .action)
                    }
                }
            }
        }
    }
}

struct ActiveStatusSection: View {
    @ObservedObject var appState: AppState

    var body: some View {
        DashboardSection(title: "进行状态", systemImage: "progress.indicator") {
            if appState.sharedFileReceiveStatus == nil {
                EmptySectionRow(
                    title: "没有进行中的状态",
                    systemImage: "circle.dotted"
                )
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    SharedFileReceiveInlineCardView(appState: appState)
                }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct RecentActivitySection: View {
    @ObservedObject var appState: AppState
    var displayLimit: Int = 8

    var body: some View {
        DashboardSection(
            title: "最近接收",
            systemImage: "clock.arrow.circlepath",
            accessoryText: "\(appState.recentActivityNotifications.count)"
        ) {
            if appState.recentActivityNotifications.isEmpty {
                EmptySectionRow(
                    title: "还没有接收记录",
                    systemImage: "tray"
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(appState.recentActivityNotifications.prefix(displayLimit), id: \.eventId) { summary in
                        NotificationSummaryCard(summary: summary, appState: appState, style: .compact)
                    }
                }
            }
        }
    }
}
