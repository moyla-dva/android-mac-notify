import SwiftUI

struct StatusFloatingCardView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        if let card = appState.statusCard {
            StatusCardContent(card: card, isFloating: true) {
                appState.dismissStatusCard()
            }
            .padding(10)
        }
    }
}

struct StatusInlineCardView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        if let card = appState.statusCard {
            StatusCardContent(card: card, isFloating: false) {
                appState.dismissStatusCard()
            }
        }
    }
}

private struct StatusCardContent: View {
    let card: StatusCardState
    let isFloating: Bool
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: card.systemImageName)
                    .font(.title3)
                    .foregroundStyle(card.accentColor)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(card.title)
                        .font(.headline)
                    Text(card.appName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let etaText = card.etaText {
                    Text(etaText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("关闭状态卡片")
            }

            ProgressView(value: card.stage.progress)
                .tint(card.accentColor)

            Text(card.detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text("更新于 \(card.updatedDate, style: .time)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(width: isFloating ? 340 : nil, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }
}

private extension StatusCardState {
    var updatedDate: Date {
        Date(timeIntervalSince1970: TimeInterval(updatedAt) / 1000)
    }

    var systemImageName: String {
        switch (category, stage) {
        case (.delivery, .queued):
            return "checklist"
        case (.delivery, .preparing):
            return "fork.knife"
        case (.delivery, .handoff):
            return "figure.walk"
        case (.delivery, .inProgress):
            return "bicycle"
        case (.delivery, .completed):
            return "checkmark.circle.fill"
        case (.delivery, .issue):
            return "exclamationmark.triangle.fill"
        }
    }

    var accentColor: Color {
        switch stage {
        case .queued, .preparing:
            return .blue
        case .handoff, .inProgress:
            return .orange
        case .completed:
            return .green
        case .issue:
            return .red
        }
    }
}
