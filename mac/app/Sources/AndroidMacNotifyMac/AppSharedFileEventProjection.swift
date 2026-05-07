import Foundation

struct AppSharedFileTransferProjection: Equatable {
    let sharedFileReceiveStatus: SharedFileReceiveStatus
}

struct AppSharedFileReceiptProjection: Equatable {
    let summary: LocalNotificationSummary
    let sharedFileReceiveStatus: SharedFileReceiveStatus?
    let notificationsReceived: Int
    let lastNotificationSummary: LocalNotificationSummary
    let recentNotifications: [LocalNotificationSummary]
    let transientActionSummaries: [String: LocalNotificationSummary]
    let transientNotifications: [LocalNotificationSummary]
    let actionFeedbackMessage: String
}

enum AppSharedFileEventProjector {
    static func transferUpdated(status: SharedFileReceiveStatus) -> AppSharedFileTransferProjection {
        AppSharedFileTransferProjection(sharedFileReceiveStatus: status)
    }

    static func received(
        receipt: SharedFileReceipt,
        currentNotificationsReceived: Int,
        recentNotifications: [LocalNotificationSummary],
        transientActionSummaries: [String: LocalNotificationSummary],
        now: Int64
    ) -> AppSharedFileReceiptProjection {
        let summary = SharedFileActionFactory.summary(from: receipt)
        let transientProjection = AppActionProjection.transientActionSummaryProjection(
            upserting: summary,
            into: transientActionSummaries,
            now: now
        )

        var nextRecentNotifications = recentNotifications
        nextRecentNotifications.removeAll { $0.eventId == summary.eventId }
        nextRecentNotifications.insert(summary, at: 0)
        nextRecentNotifications = NotificationHistoryPolicy.visibleSummaries(
            from: nextRecentNotifications,
            now: now
        )

        return AppSharedFileReceiptProjection(
            summary: summary,
            sharedFileReceiveStatus: nil,
            notificationsReceived: currentNotificationsReceived + 1,
            lastNotificationSummary: summary,
            recentNotifications: nextRecentNotifications,
            transientActionSummaries: transientProjection.summariesByEventId,
            transientNotifications: transientProjection.transientNotifications,
            actionFeedbackMessage: "已保存文件 \(receipt.fileName)"
        )
    }
}

enum AppSharedFilePromptPolicy {
    static func shouldPublishActionPrompt(for receipt: SharedFileReceipt) -> Bool {
        guard let batchTotal = receipt.batchTotal, batchTotal > 1 else {
            return true
        }
        guard let batchIndex = receipt.batchIndex else {
            return true
        }
        return batchIndex >= batchTotal - 1
    }
}
