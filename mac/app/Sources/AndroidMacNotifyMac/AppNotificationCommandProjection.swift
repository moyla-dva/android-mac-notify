import Foundation

struct AppNotificationCommandProjection: Equatable {
    let notificationsReceived: Int
    let lastNotificationSummary: LocalNotificationSummary?
    let recentNotifications: [LocalNotificationSummary]
    let transientNotifications: [LocalNotificationSummary]
    let transientActionSummaries: [String: LocalNotificationSummary]
    let actionResultsById: [String: ActionResult]
    let actionFeedbackMessage: String
}

enum AppNotificationCommandProjector {
    static func remove(
        eventId: String,
        notificationsReceived: Int,
        lastNotificationSummary: LocalNotificationSummary?,
        recentNotifications: [LocalNotificationSummary],
        transientNotifications: [LocalNotificationSummary],
        transientActionSummaries: [String: LocalNotificationSummary],
        actionResultsById: [String: ActionResult]
    ) -> AppNotificationCommandProjection {
        AppNotificationCommandProjection(
            notificationsReceived: notificationsReceived,
            lastNotificationSummary: lastNotificationSummary?.eventId == eventId ? nil : lastNotificationSummary,
            recentNotifications: recentNotifications.filter { $0.eventId != eventId },
            transientNotifications: transientNotifications.filter { $0.eventId != eventId },
            transientActionSummaries: transientActionSummaries.filter { key, _ in key != eventId },
            actionResultsById: actionResultsById.filter { _, result in result.sourceEventId != eventId },
            actionFeedbackMessage: "已清除这条"
        )
    }

    static func clearHistory() -> AppNotificationCommandProjection {
        AppNotificationCommandProjection(
            notificationsReceived: 0,
            lastNotificationSummary: nil,
            recentNotifications: [],
            transientNotifications: [],
            transientActionSummaries: [:],
            actionResultsById: [:],
            actionFeedbackMessage: "已清空通知历史"
        )
    }
}
