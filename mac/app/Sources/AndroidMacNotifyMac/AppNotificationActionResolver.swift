import Foundation

enum AppNotificationActionResolution: Equatable {
    case resolved(ActionCandidate, LocalNotificationSummary)
    case failureMessage(String)
}

enum AppNotificationActionResolver {
    static func resolve(
        eventId: String,
        actionIdentifier: String,
        summary: LocalNotificationSummary?
    ) -> AppNotificationActionResolution {
        guard let actionKind = ActionKind(rawValue: actionIdentifier) else {
            return .failureMessage("未知通知动作: \(actionIdentifier)")
        }

        guard let summary else {
            return .failureMessage("找不到这条通知对应的动作")
        }

        guard let action = summary.visibleActionCandidates.first(where: { $0.kind == actionKind })
            ?? summary.actionCandidates.first(where: { action in
                action.kind == actionKind && NotificationHistoryPolicy.shouldExpose(action: action, for: summary)
            })
        else {
            return .failureMessage("当前通知没有可执行的\(actionKind.displayTitle)")
        }

        return .resolved(action, summary)
    }
}
