import SwiftUI

struct NotificationSummaryCard: View {
    enum Style {
        case action
        case compact
    }

    let summary: LocalNotificationSummary
    @ObservedObject var appState: AppState
    var style: Style = .action
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: style == .compact ? 6 : 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(summary.displaySourceTitle)
                    .font(style == .compact ? .callout.weight(.medium) : .headline)
                    .lineLimit(1)

                if let badgeText {
                    StateBadge(text: badgeText, tone: badgeTone)
                }

                Spacer()

                Text(summary.receivedDate, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let verificationCode = summary.verificationCode {
                Text(verificationCode)
                    .font(style == .compact ? .title3.weight(.semibold) : .title2.weight(.semibold))
                    .textSelection(.enabled)
            }

            Text(summary.primaryPreview)
                .font(style == .compact ? .caption : .callout)
                .foregroundStyle(.secondary)
                .lineLimit(style == .compact ? 2 : 3)
                .textSelection(.enabled)

            if style != .compact, let routingExplanation = summary.routingExplanation {
                RoutingExplanationLine(
                    explanation: routingExplanation,
                    compact: style == .compact
                )
            }

            if let failedActionMessage {
                ActionStateLine(
                    message: failedActionMessage,
                    systemImage: "exclamationmark.triangle",
                    color: .orange
                )
            }

            if style != .compact {
                NotificationActionList(
                    summary: summary,
                    appState: appState,
                    compact: false,
                    hidingCompletedActions: shouldHideCompletedActions
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(style == .compact ? 10 : 14)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(cardBackground)
                .overlay {
                    if isHovered {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.035))
                    }
                }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(cardStrokeColor, lineWidth: 1)
        )
        .contextMenu {
            Button(role: .destructive) {
                appState.clearNotification(summary)
            } label: {
                Label("清除这条", systemImage: "trash")
            }
        }
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    private var badgeText: String? {
        if !appState.failedActionResults(for: summary).isEmpty {
            return "需重试"
        }
        if style == .action {
            return "待处理"
        }
        if appState.isEventHandled(summary) {
            return "已处理"
        }
        return summary.routeBadgeText
    }

    private var badgeTone: StateBadge.Tone {
        if !appState.failedActionResults(for: summary).isEmpty {
            return .warning
        }
        if appState.isEventHandled(summary) {
            return .success
        }
        if style == .action {
            return .accent
        }
        return .neutral
    }

    private var failedActionMessage: String? {
        appState.failedActionResults(for: summary).first?.message
    }

    private var cardBackground: Color {
        switch style {
        case .action:
            return Color.accentColor.opacity(0.06)
        case .compact:
            return Color.secondary.opacity(0.045)
        }
    }

    private var cardStrokeColor: Color {
        if !appState.failedActionResults(for: summary).isEmpty {
            return .orange.opacity(0.38)
        }
        if style == .action {
            return Color.accentColor.opacity(0.22)
        }
        return Color.secondary.opacity(0.10)
    }

    private var shouldHideCompletedActions: Bool {
        style == .action || appState.isEventHandled(summary)
    }
}
