import Testing
@testable import AndroidMacNotifyMac

struct AppNotificationEventProjectionTests {
    @Test
    func testAcceptedRecordableNotificationIncrementsAndPersistsRecent() {
        let summary = notificationSummary(
            eventId: "event-link",
            appPackage: "com.example.browser",
            appName: "Browser",
            receivedAt: 100,
            actionKinds: [.openLink]
        )

        let projection = AppNotificationEventProjector.accepted(
            summary: summary,
            currentNotificationsReceived: 2,
            recentNotifications: [],
            transientActionSummaries: [:],
            now: 100
        )

        #expect(projection.notificationsReceived == 3)
        #expect(projection.lastNotificationSummary == summary)
        #expect(projection.recentNotifications.map(\.eventId) == ["event-link"])
        #expect(projection.transientActionSummaries.isEmpty)
        #expect(projection.transientNotifications.isEmpty)
        #expect(projection.actionFeedbackMessage == nil)
    }

    @Test
    func testAcceptedVerificationCodeDoesNotPersistHistoryButKeepsTransientActionLookup() {
        let summary = notificationSummary(
            eventId: "event-code",
            appPackage: "com.android.mms",
            appName: "短信",
            receivedAt: 100,
            actionKinds: [.copyVerificationCode]
        )

        let projection = AppNotificationEventProjector.accepted(
            summary: summary,
            currentNotificationsReceived: 0,
            recentNotifications: [],
            transientActionSummaries: [:],
            now: 100
        )

        #expect(projection.notificationsReceived == 1)
        #expect(projection.recentNotifications.isEmpty)
        #expect(projection.transientActionSummaries["event-code"] == summary)
        #expect(projection.transientNotifications.map(\.eventId) == ["event-code"])
    }

    @Test
    func testAcceptedNotificationReplacesDuplicateRecentEntry() {
        let oldSummary = notificationSummary(
            eventId: "event-link",
            appPackage: "com.example.browser",
            appName: "Browser",
            title: "旧标题",
            receivedAt: 100,
            actionKinds: [.openLink]
        )
        let newSummary = notificationSummary(
            eventId: "event-link",
            appPackage: "com.example.browser",
            appName: "Browser",
            title: "新标题",
            receivedAt: 200,
            actionKinds: [.openLink]
        )

        let projection = AppNotificationEventProjector.accepted(
            summary: newSummary,
            currentNotificationsReceived: 1,
            recentNotifications: [oldSummary],
            transientActionSummaries: [oldSummary.eventId: oldSummary],
            now: 200
        )

        #expect(projection.notificationsReceived == 2)
        #expect(projection.recentNotifications == [newSummary])
        #expect(projection.transientActionSummaries.isEmpty)
    }

    private func notificationSummary(
        eventId: String,
        appPackage: String?,
        appName: String,
        title: String = "测试通知",
        receivedAt: Int64,
        actionKinds: [ActionKind]
    ) -> LocalNotificationSummary {
        let actions = actionKinds.map { actionKind in
            ActionCandidate(
                actionId: "act_\(eventId)_\(actionKind.rawValue)",
                sourceEventId: eventId,
                kind: actionKind,
                title: actionKind.displayTitle,
                value: value(for: actionKind),
                priority: .medium,
                payload: payload(for: actionKind)
            )
        }

        return LocalNotificationSummary(
            eventId: eventId,
            deviceId: "android-test",
            appPackage: appPackage,
            appName: appName,
            title: title,
            text: "测试文本",
            receivedAt: receivedAt,
            verificationContext: nil,
            actionCandidates: actions,
            ruleDecision: .passthrough(eventId: eventId, actionCandidates: actions)
        )
    }

    private func value(for actionKind: ActionKind) -> String? {
        switch actionKind {
        case .copyVerificationCode:
            return "123456"
        case .openLink:
            return "https://example.com"
        case .copyText:
            return "测试文本"
        case .openFile, .revealFile, .copyFilePath:
            return "/tmp/test.txt"
        case .showNotification, .recordHistory:
            return nil
        }
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
