import Testing
@testable import AndroidMacNotifyMac

struct AppNotificationCommandProjectionTests {
    @Test
    func testRemoveNotificationClearsMatchingLocalStateAndActionResults() {
        let removedSummary = notificationSummary(eventId: "event-remove", receivedAt: 200)
        let keptSummary = notificationSummary(eventId: "event-keep", receivedAt: 100)
        let removedResult = actionResult(actionId: "action-remove", sourceEventId: removedSummary.eventId)
        let keptResult = actionResult(actionId: "action-keep", sourceEventId: keptSummary.eventId)

        let projection = AppNotificationCommandProjector.remove(
            eventId: removedSummary.eventId,
            notificationsReceived: 7,
            lastNotificationSummary: removedSummary,
            recentNotifications: [removedSummary, keptSummary],
            transientNotifications: [removedSummary, keptSummary],
            transientActionSummaries: [
                removedSummary.eventId: removedSummary,
                keptSummary.eventId: keptSummary,
            ],
            actionResultsById: [
                removedResult.actionId: removedResult,
                keptResult.actionId: keptResult,
            ]
        )

        #expect(projection.notificationsReceived == 7)
        #expect(projection.lastNotificationSummary == nil)
        #expect(projection.recentNotifications == [keptSummary])
        #expect(projection.transientNotifications == [keptSummary])
        #expect(projection.transientActionSummaries == [keptSummary.eventId: keptSummary])
        #expect(projection.actionResultsById == [keptResult.actionId: keptResult])
        #expect(projection.actionFeedbackMessage == "已清除这条")
    }

    @Test
    func testRemoveNotificationKeepsDifferentLastSummary() {
        let removedSummary = notificationSummary(eventId: "event-remove", receivedAt: 200)
        let keptSummary = notificationSummary(eventId: "event-keep", receivedAt: 100)

        let projection = AppNotificationCommandProjector.remove(
            eventId: removedSummary.eventId,
            notificationsReceived: 2,
            lastNotificationSummary: keptSummary,
            recentNotifications: [removedSummary, keptSummary],
            transientNotifications: [],
            transientActionSummaries: [:],
            actionResultsById: [:]
        )

        #expect(projection.lastNotificationSummary == keptSummary)
    }

    @Test
    func testClearHistoryResetsNotificationStateAndActionResults() {
        let projection = AppNotificationCommandProjector.clearHistory()

        #expect(projection.notificationsReceived == 0)
        #expect(projection.lastNotificationSummary == nil)
        #expect(projection.recentNotifications.isEmpty)
        #expect(projection.transientNotifications.isEmpty)
        #expect(projection.transientActionSummaries.isEmpty)
        #expect(projection.actionResultsById.isEmpty)
        #expect(projection.actionFeedbackMessage == "已清空通知历史")
    }

    private func notificationSummary(eventId: String, receivedAt: Int64) -> LocalNotificationSummary {
        LocalNotificationSummary(
            eventId: eventId,
            deviceId: "android-test",
            appPackage: "com.example",
            appName: "Example",
            title: "测试通知",
            text: "测试文本",
            receivedAt: receivedAt,
            verificationContext: nil,
            actionCandidates: [],
            ruleDecision: .passthrough(eventId: eventId, actionCandidates: [])
        )
    }

    private func actionResult(actionId: String, sourceEventId: String) -> ActionResult {
        ActionResult(
            actionId: actionId,
            sourceEventId: sourceEventId,
            status: .success,
            executedAt: 100,
            message: nil
        )
    }
}
