import Foundation

struct AppNotificationEventProjection: Equatable {
    let notificationsReceived: Int
    let lastNotificationSummary: LocalNotificationSummary
    let recentNotifications: [LocalNotificationSummary]
    let transientActionSummaries: [String: LocalNotificationSummary]
    let transientNotifications: [LocalNotificationSummary]
    let actionFeedbackMessage: String?
}

enum AppNotificationEventProjector {
    static func accepted(
        summary: LocalNotificationSummary,
        currentNotificationsReceived: Int,
        recentNotifications: [LocalNotificationSummary],
        transientActionSummaries: [String: LocalNotificationSummary],
        now: Int64
    ) -> AppNotificationEventProjection {
        let transientProjection = AppActionProjection.transientActionSummaryProjection(
            upserting: summary,
            into: transientActionSummaries,
            now: now
        )

        let nextRecentNotifications = projectedRecentNotifications(
            upserting: summary,
            into: recentNotifications,
            now: now
        )

        return AppNotificationEventProjection(
            notificationsReceived: currentNotificationsReceived + 1,
            lastNotificationSummary: summary,
            recentNotifications: nextRecentNotifications,
            transientActionSummaries: transientProjection.summariesByEventId,
            transientNotifications: transientProjection.transientNotifications,
            actionFeedbackMessage: nil
        )
    }

    private static func projectedRecentNotifications(
        upserting summary: LocalNotificationSummary,
        into recentNotifications: [LocalNotificationSummary],
        now: Int64
    ) -> [LocalNotificationSummary] {
        var notifications = recentNotifications
        notifications.removeAll { $0.eventId == summary.eventId }

        if NotificationHistoryPolicy.shouldPersist(summary, now: now) {
            notifications.insert(summary, at: 0)
        }

        return NotificationHistoryPolicy.visibleSummaries(from: notifications, now: now)
    }
}
