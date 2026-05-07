import SwiftUI

struct MenuNotificationRow: View {
    let summary: LocalNotificationSummary
    @ObservedObject var appState: AppState
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(summary.displaySourceTitle)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)

                Spacer()

                Text(summary.receivedDate, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if let verificationCode = summary.verificationCode {
                Text(verificationCode)
                    .font(.subheadline.weight(.semibold))
                    .textSelection(.enabled)
            }

            Text(summary.primaryPreview)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(compact ? 1 : 2)

            NotificationActionList(
                summary: summary,
                appState: appState,
                compact: true,
                hidingCompletedActions: !compact
            )
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct MenuSharedFileDeliveryGroupRow: View {
    let group: SharedFileDeliveryGroup
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(titleText)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)

                Spacer()

                Text(group.receivedDate, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Text(subtitleText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)

            if group.fileCount > 1 {
                HStack(spacing: 6) {
                    Button {
                        appState.revealSharedFileDeliveryGroup(group)
                    } label: {
                        Label("显示全部", systemImage: "folder")
                    }
                    Button {
                        appState.copySharedFileDeliveryGroupPaths(group)
                    } label: {
                        Label("复制全部路径", systemImage: "doc.on.clipboard")
                    }
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            } else {
                NotificationActionList(
                    summary: group.latestSummary,
                    appState: appState,
                    compact: true,
                    hidingCompletedActions: false
                )
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    private var titleText: String {
        if group.fileCount == 1 {
            return group.latestSummary.title
        }
        return "收到 \(group.fileCount) 个文件"
    }

    private var subtitleText: String {
        if group.fileCount == 1 {
            return group.latestSummary.primaryPreview
        }
        let previewNames = group.summaries
            .prefix(3)
            .map(\.title)
            .joined(separator: "、")
        let suffix = group.fileCount > 3 ? " 等" : ""
        return "\(previewNames)\(suffix)"
    }
}

struct MenuPairingRow: View {
    let request: PairingApprovalRequest
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(request.device.displayName)
                .font(.caption.weight(.medium))
            HStack {
                Button("拒绝", role: .destructive) {
                    appState.rejectPairingRequest(request)
                }
                Button("允许") {
                    appState.approvePairingRequest(request)
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.small)
        }
        .padding(10)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}
