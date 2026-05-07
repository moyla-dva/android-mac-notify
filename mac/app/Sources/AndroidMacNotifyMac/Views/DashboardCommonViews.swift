import SwiftUI

struct DashboardSection<Content: View>: View {
    let title: String
    let systemImage: String
    let accessoryText: String?
    let content: Content

    init(
        title: String,
        systemImage: String,
        accessoryText: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.accessoryText = accessoryText
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Label(title, systemImage: systemImage)
                    .font(.headline)

                Spacer()

                if let accessoryText {
                    Text(accessoryText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.08), in: Capsule())
                }
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct InlineFeedback: View {
    let message: String
    let isFailure: Bool

    var body: some View {
        Label(message, systemImage: isFailure ? "exclamationmark.triangle" : "checkmark.circle")
            .font(.callout)
            .foregroundStyle(isFailure ? .orange : .secondary)
            .padding(.vertical, 8)
    }
}

struct EmptySectionRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct StateBadge: View {
    enum Tone {
        case neutral
        case accent
        case success
        case warning
    }

    let text: String
    let tone: Tone

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor, in: Capsule())
    }

    private var foregroundColor: Color {
        switch tone {
        case .neutral:
            return .secondary
        case .accent:
            return .accentColor
        case .success:
            return .green
        case .warning:
            return .orange
        }
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(0.10)
    }
}

struct ActionStateLine: View {
    let message: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(message, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(color)
            .lineLimit(2)
    }
}

struct RoutingExplanationLine: View {
    let explanation: NotificationRoutingExplanation
    let compact: Bool

    var body: some View {
        Label(explanation.text, systemImage: explanation.systemImage)
            .font(compact ? .caption : .callout)
            .foregroundStyle(foregroundColor)
            .lineLimit(2)
    }

    private var foregroundColor: Color {
        switch explanation.tone {
        case .neutral:
            return .secondary
        case .accent:
            return .accentColor
        case .warning:
            return .orange
        }
    }
}
