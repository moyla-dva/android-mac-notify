import SwiftUI

struct NotificationActionList: View {
    let summary: LocalNotificationSummary
    @ObservedObject var appState: AppState
    var compact = false
    var hidingCompletedActions = false

    var body: some View {
        Group {
            if !actionCandidates.isEmpty {
                if compact {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(actionCandidates) { action in
                            actionButton(action)
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        ForEach(actionCandidates) { action in
                            actionButton(action)
                        }
                    }
                }
            }
        }
    }

    private var actionCandidates: [ActionCandidate] {
        appState.visibleActionCandidates(
            for: summary,
            hidingCompletedActions: hidingCompletedActions
        )
    }

    private func actionButton(_ action: ActionCandidate) -> some View {
        Button {
            appState.execute(action: action, from: summary)
        } label: {
            Label(actionTitle(for: action), systemImage: systemImageName(for: action))
        }
        .controlSize(compact ? .small : .regular)
        .help(actionHelp(for: action))
    }

    private func actionTitle(for action: ActionCandidate) -> String {
        guard appState.actionResult(for: action)?.status == .failed else {
            return action.title
        }
        return "重试\(action.title)"
    }

    private func systemImageName(for action: ActionCandidate) -> String {
        if appState.actionResult(for: action)?.status == .failed {
            return "arrow.clockwise"
        }
        return action.systemImageName
    }

    private func actionHelp(for action: ActionCandidate) -> String {
        guard let result = appState.actionResult(for: action), result.status == .failed else {
            return action.title
        }
        return result.message ?? "上次执行失败，可重试"
    }
}

private extension ActionCandidate {
    var systemImageName: String {
        switch kind {
        case .copyVerificationCode:
            return "doc.on.doc"
        case .openLink:
            return "safari"
        case .copyText:
            return "text.quote"
        case .openFile:
            return "doc"
        case .revealFile:
            return "folder"
        case .copyFilePath:
            return "doc.on.clipboard"
        case .showNotification:
            return "bell"
        case .recordHistory:
            return "clock.arrow.circlepath"
        }
    }
}
