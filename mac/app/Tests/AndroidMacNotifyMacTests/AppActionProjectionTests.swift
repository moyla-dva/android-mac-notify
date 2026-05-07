import Testing
@testable import AndroidMacNotifyMac

struct AppActionProjectionTests {
    @Test
    func testActionInboxHidesHandledNotifications() {
        let summary = notificationSummary(eventId: "event-code", receivedAt: 2, actionKinds: [.copyVerificationCode])
        let action = summary.visibleActionCandidates[0]
        let result = ActionResult(
            actionId: action.actionId,
            sourceEventId: summary.eventId,
            status: .success,
            executedAt: 3,
            message: "已复制验证码"
        )

        let inbox = AppActionProjection.actionInboxNotifications(
            lastNotificationSummary: summary,
            transientNotifications: [],
            recentNotifications: [],
            actionResultsById: [result.actionId: result]
        )

        #expect(inbox.isEmpty)
        #expect(AppActionProjection.isEventHandled(summary, actionResultsById: [result.actionId: result]))
    }

    @Test
    func testRecentActivityKeepsHandledTransientActionSummary() {
        let summary = notificationSummary(
            eventId: "event-im",
            appPackage: "com.tencent.mm",
            appName: "微信",
            receivedAt: 2,
            actionKinds: [.copyText]
        )
        let action = summary.visibleActionCandidates[0]
        let result = ActionResult(
            actionId: action.actionId,
            sourceEventId: summary.eventId,
            status: .success,
            executedAt: 3,
            message: "已复制文本"
        )

        let activity = AppActionProjection.recentActivityNotifications(
            lastNotificationSummary: summary,
            transientNotifications: [],
            recentNotifications: [],
            actionResultsById: [result.actionId: result],
            now: 4
        )

        #expect(activity.map(\.eventId) == [summary.eventId])
    }

    @Test
    func testSharedFileReceiptsStayOutOfActionInboxAndRecentActivity() {
        let summary = SharedFileActionFactory.summary(
            from: SharedFileReceipt(
                shareId: "share-1",
                deviceId: "android-test",
                fileName: "photo.jpg",
                savedPath: "/Users/test/Downloads/Android Mac Notify/photo.jpg",
                size: 1_024,
                receivedAt: 2
            )
        )

        let inbox = AppActionProjection.actionInboxNotifications(
            lastNotificationSummary: summary,
            transientNotifications: [],
            recentNotifications: [summary],
            actionResultsById: [:]
        )
        let activity = AppActionProjection.recentActivityNotifications(
            lastNotificationSummary: summary,
            transientNotifications: [],
            recentNotifications: [summary],
            actionResultsById: [:],
            now: 3
        )

        #expect(summary.isSharedFileReceipt)
        #expect(inbox.isEmpty)
        #expect(activity.isEmpty)
        #expect(summary.visibleActionCandidates.map(\.kind) == [.openFile, .revealFile, .copyFilePath])
    }

    @Test
    func testTransientActionSummaryProjectionDeduplicatesAndSorts() {
        let older = notificationSummary(eventId: "older", receivedAt: 1, actionKinds: [.copyText])
        let newer = notificationSummary(eventId: "newer", receivedAt: 3, actionKinds: [.copyText])
        let replacement = notificationSummary(eventId: "older", receivedAt: 5, actionKinds: [.copyText])

        let first = AppActionProjection.transientActionSummaryProjection(
            upserting: older,
            into: [:],
            now: 6
        )
        let second = AppActionProjection.transientActionSummaryProjection(
            upserting: newer,
            into: first.summariesByEventId,
            now: 6
        )
        let third = AppActionProjection.transientActionSummaryProjection(
            upserting: replacement,
            into: second.summariesByEventId,
            now: 6
        )

        #expect(third.transientNotifications.map(\.eventId) == ["older", "newer"])
        #expect(third.summariesByEventId["older"]?.receivedAt == 5)
    }

    private func notificationSummary(
        eventId: String,
        appPackage: String? = "com.android.mms",
        appName: String = "短信",
        receivedAt: Int64,
        actionKinds: [ActionKind]
    ) -> LocalNotificationSummary {
        let actions = actionKinds.map { actionKind in
            ActionCandidate(
                actionId: "act_\(eventId)_\(actionKind.rawValue)",
                sourceEventId: eventId,
                kind: actionKind,
                title: actionKind.displayTitle,
                value: actionKind == .copyText ? "测试文本" : "123456",
                priority: .medium,
                payload: payload(for: actionKind)
            )
        }

        return LocalNotificationSummary(
            eventId: eventId,
            deviceId: "android-test",
            appPackage: appPackage,
            appName: appName,
            title: "测试通知",
            text: "测试文本",
            receivedAt: receivedAt,
            verificationContext: nil,
            actionCandidates: actions,
            ruleDecision: .passthrough(eventId: eventId, actionCandidates: actions)
        )
    }

    private func payload(for actionKind: ActionKind) -> ActionPayload {
        switch actionKind {
        case .copyVerificationCode:
            return .verificationCode(code: "123456", senderLabel: "短信")
        case .openLink:
            return .link(url: "https://example.com")
        case .copyText:
            return .text(value: "测试文本")
        case .openFile, .revealFile, .copyFilePath:
            return .file(path: "/tmp/test.txt", fileName: "test.txt", mimeType: "text/plain")
        case .showNotification, .recordHistory:
            return .none
        }
    }
}
