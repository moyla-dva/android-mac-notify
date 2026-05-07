import SwiftUI

struct SharedFileDeliverySection: View {
    @ObservedObject var appState: AppState
    var displayLimit: Int = 6

    var body: some View {
        let groups = appState.recentSharedFileDeliveryGroups
        DashboardSection(
            title: "文件投递",
            systemImage: "tray.and.arrow.down",
            accessoryText: sharedFileDeliveryAccessoryText(groups: groups)
        ) {
            if groups.isEmpty {
                EmptySectionRow(
                    title: "还没有收到文件",
                    systemImage: "tray"
                )
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    let visibleGroups = Array(groups.prefix(displayLimit))
                    if let latestGroup = visibleGroups.first {
                        SharedFileDeliveryGroupCard(group: latestGroup, appState: appState)
                    }

                    if visibleGroups.count > 1 {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("之前收到")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)

                            ForEach(visibleGroups.dropFirst()) { group in
                                SharedFileDeliveryHistoryRow(group: group, appState: appState)
                            }
                        }
                    }
                }
            }
        }
    }

    private func sharedFileDeliveryAccessoryText(groups: [SharedFileDeliveryGroup]) -> String {
        guard !groups.isEmpty else {
            return "0"
        }
        return groups.count == 1 ? "1 批" : "\(groups.count) 批"
    }
}

private let maxExpandedSharedFileGroupItems = 5

struct SharedFileDeliveryHistoryRow: View {
    let group: SharedFileDeliveryGroup
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: group.fileCount > 1 ? "doc.on.doc" : "doc")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(titleText)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if group.summaries.contains(where: \.sharedFileWasSavedWithNewName) {
                        StateBadge(text: "改名", tone: .warning)
                    }
                }

                Text(sharedFileSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Text(group.receivedDate, style: .time)
                .font(.caption)
                .foregroundStyle(.secondary)

            SharedFileCompactActionButtons(group: group, appState: appState)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
    }

    private var titleText: String {
        if group.fileCount == 1 {
            return group.latestSummary.title
        }
        return "收到 \(group.fileCount) 个文件"
    }

    private var sharedFileSubtitle: String {
        if group.fileCount > 1 {
            let previewNames = group.summaries
                .prefix(3)
                .map(\.title)
                .joined(separator: "、")
            let suffix = group.fileCount > 3 ? " 等" : ""
            return "\(previewNames)\(suffix)"
        }
        let summary = group.latestSummary
        if let size = summary.sharedFileSizeText, let path = summary.sharedFilePath {
            return "\(size) · \(path)"
        }
        if let path = summary.sharedFilePath {
            return path
        }
        return summary.primaryPreview
    }
}

private struct SharedFileCompactActionButtons: View {
    let group: SharedFileDeliveryGroup
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 6) {
            Button {
                appState.revealSharedFileDeliveryGroup(group)
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .help(group.fileCount > 1 ? "在 Finder 中显示这批文件" : "在 Finder 中显示文件")
            .accessibilityLabel(group.fileCount > 1 ? "显示全部" : "显示文件")

            Button {
                appState.copySharedFileDeliveryGroupPaths(group)
            } label: {
                Image(systemName: "doc.on.clipboard")
            }
            .buttonStyle(.borderless)
            .help(group.fileCount > 1 ? "复制这批文件的保存路径" : "复制文件路径")
            .accessibilityLabel(group.fileCount > 1 ? "复制全部路径" : "复制路径")
        }
        .fixedSize()
    }
}

struct SharedFileDeliveryGroupCard: View {
    let group: SharedFileDeliveryGroup
    @ObservedObject var appState: AppState
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: group.fileCount > 1 ? "doc.on.doc" : "doc")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(titleText)
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        StateBadge(text: "已保存", tone: .success)
                        if group.fileCount > 1 {
                            StateBadge(text: "多文件", tone: .accent)
                        }
                        if group.summaries.contains(where: \.sharedFileWasSavedWithNewName) {
                            StateBadge(text: group.fileCount > 1 ? "含改名" : "已改名", tone: .warning)
                        }
                    }

                    Text(sharedFileSubtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                Spacer()

                Text(group.receivedDate, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if group.fileCount == 1 {
                NotificationActionList(
                    summary: group.latestSummary,
                    appState: appState,
                    compact: false,
                    hidingCompletedActions: false
                )
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    SharedFileGroupActionBar(group: group, appState: appState)

                    ForEach(group.summaries.prefix(maxExpandedSharedFileGroupItems), id: \.eventId) { summary in
                        SharedFileGroupItemRow(summary: summary, appState: appState)
                    }

                    let remainingCount = group.summaries.count - maxExpandedSharedFileGroupItems
                    if remainingCount > 0 {
                        SharedFileGroupMoreRow(remainingCount: remainingCount)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.055))
                .overlay {
                    if isHovered {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.035))
                    }
                }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    private var titleText: String {
        if group.fileCount == 1 {
            return group.latestSummary.title
        }
        return "收到 \(group.fileCount) 个文件"
    }

    private var sharedFileSubtitle: String {
        if group.fileCount > 1 {
            let previewNames = group.summaries
                .prefix(3)
                .map(\.title)
                .joined(separator: "、")
            let suffix = group.fileCount > 3 ? " 等" : ""
            return "\(previewNames)\(suffix)"
        }
        let summary = group.latestSummary
        if let size = summary.sharedFileSizeText, let path = summary.sharedFilePath {
            return "\(size) · \(path)"
        }
        if let path = summary.sharedFilePath {
            return path
        }
        return summary.primaryPreview
    }
}

private struct SharedFileGroupMoreRow: View {
    let remainingCount: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text("还有 \(remainingCount) 个文件，可用上方批量按钮处理")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

private struct SharedFileGroupActionBar: View {
    let group: SharedFileDeliveryGroup
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 8) {
            Button {
                appState.revealSharedFileDeliveryGroup(group)
            } label: {
                Label("显示全部", systemImage: "folder")
            }
            .help("在 Finder 中显示这批文件")

            Button {
                appState.copySharedFileDeliveryGroupPaths(group)
            } label: {
                Label("复制全部路径", systemImage: "doc.on.clipboard")
            }
            .help("复制这批文件的保存路径")

            Spacer()
        }
        .controlSize(.small)
    }
}

private struct SharedFileGroupItemRow: View {
    let summary: LocalNotificationSummary
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "doc")
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(summary.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let size = summary.sharedFileSizeText {
                    Text(size)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            SharedFileMiniActionButtons(summary: summary, appState: appState)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SharedFileMiniActionButtons: View {
    let summary: LocalNotificationSummary
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 6) {
            ForEach(actionCandidates) { action in
                Button {
                    appState.execute(action: action, from: summary)
                } label: {
                    Image(systemName: action.fileActionSystemImageName)
                }
                .buttonStyle(.borderless)
                .help(action.title)
                .accessibilityLabel(action.title)
            }
        }
        .fixedSize()
    }

    private var actionCandidates: [ActionCandidate] {
        appState.visibleActionCandidates(
            for: summary,
            hidingCompletedActions: false
        )
    }
}

private extension ActionCandidate {
    var fileActionSystemImageName: String {
        switch kind {
        case .openFile:
            return "doc"
        case .revealFile:
            return "folder"
        case .copyFilePath:
            return "doc.on.clipboard"
        default:
            return "bolt"
        }
    }
}
