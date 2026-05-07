import Foundation
import SwiftUI

struct SharedFileReceiveInlineCardView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        if let status = appState.sharedFileReceiveStatus {
            SharedFileReceiveCardContent(status: status) {
                appState.dismissSharedFileReceiveStatus()
            }
        }
    }
}

private struct SharedFileReceiveCardContent: View {
    let status: SharedFileReceiveStatus
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: status.systemImageName)
                    .font(.title3)
                    .foregroundStyle(status.accentColor)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(status.title)
                        .font(.headline)
                    Text(status.fileName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                HStack(spacing: 6) {
                    if let batchPositionText = status.batchPositionText {
                        StatusBadge(text: batchPositionText, color: status.accentColor)
                    }
                    StatusBadge(text: "直传", color: status.accentColor)
                }

                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("隐藏接收状态")
            }

            if status.totalBytes > 0 {
                ProgressView(value: status.progress)
                    .tint(status.accentColor)
            } else {
                ProgressView()
                    .tint(status.accentColor)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(status.bytesText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let speedText = status.speedText {
                    Text(speedText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let remainingText = status.remainingText {
                    Text(remainingText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 6) {
                if let message = status.message, !message.isEmpty {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(status.stage == .failed ? Color.red : Color.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text("更新于 \(status.updatedDate, style: .time)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }
}

private extension SharedFileReceiveStatus {
    var title: String {
        switch stage {
        case .receiving:
            return "正在接收文件"
        case .failed:
            return "文件接收失败"
        }
    }

    var systemImageName: String {
        switch stage {
        case .receiving:
            return "tray.and.arrow.down"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    var accentColor: Color {
        switch stage {
        case .receiving:
            return .blue
        case .failed:
            return .red
        }
    }

    var bytesText: String {
        guard totalBytes > 0 else {
            return "\(Self.byteText(receivedBytes)) 已接收"
        }
        return "\(Self.byteText(receivedBytes)) / \(Self.byteText(totalBytes))"
    }

    var speedText: String? {
        guard let speedBytesPerSecond, speedBytesPerSecond > 0 else {
            return nil
        }
        return "\(Self.byteText(speedBytesPerSecond))/s"
    }

    var remainingText: String? {
        guard stage == .receiving, let remainingSeconds, remainingSeconds > 0 else {
            return nil
        }

        if remainingSeconds < 60 {
            return "剩余 \(remainingSeconds) 秒"
        }

        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        if minutes < 60 {
            return seconds > 0 ? "剩余 \(minutes) 分 \(seconds) 秒" : "剩余 \(minutes) 分"
        }

        let hours = minutes / 60
        let tailMinutes = minutes % 60
        return tailMinutes > 0 ? "剩余 \(hours) 小时 \(tailMinutes) 分" : "剩余 \(hours) 小时"
    }

    var updatedDate: Date {
        Date(timeIntervalSince1970: TimeInterval(updatedAt) / 1000)
    }

    static func byteText(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
