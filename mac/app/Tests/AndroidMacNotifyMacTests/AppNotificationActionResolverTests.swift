import Testing
@testable import AndroidMacNotifyMac

struct AppNotificationActionResolverTests {
    @Test
    func testUnknownActionIdentifierReturnsFailureMessage() {
        let resolution = AppNotificationActionResolver.resolve(
            eventId: "event-1",
            actionIdentifier: "unknown_action",
            summary: summary(eventId: "event-1", actions: [])
        )

        #expect(resolution == .failureMessage("未知通知动作: unknown_action"))
    }

    @Test
    func testMissingSummaryReturnsFailureMessage() {
        let resolution = AppNotificationActionResolver.resolve(
            eventId: "event-1",
            actionIdentifier: ActionKind.openLink.rawValue,
            summary: nil
        )

        #expect(resolution == .failureMessage("找不到这条通知对应的动作"))
    }

    @Test
    func testResolvesVisibleActionFirst() {
        let copyAction = action(kind: .copyText, eventId: "event-1")
        let linkAction = action(kind: .openLink, eventId: "event-1")
        let summary = summary(
            eventId: "event-1",
            actions: [copyAction, linkAction],
            visibleActionIds: [linkAction.actionId]
        )

        let resolution = AppNotificationActionResolver.resolve(
            eventId: "event-1",
            actionIdentifier: ActionKind.openLink.rawValue,
            summary: summary
        )

        #expect(resolution == .resolved(linkAction, summary))
    }

    @Test
    func testFallsBackToExposedNonVisibleAction() {
        let linkAction = action(kind: .openLink, eventId: "event-1")
        let summary = summary(
            eventId: "event-1",
            actions: [linkAction],
            primarySurface: .history
        )

        let resolution = AppNotificationActionResolver.resolve(
            eventId: "event-1",
            actionIdentifier: ActionKind.openLink.rawValue,
            summary: summary
        )

        #expect(summary.visibleActionCandidates.isEmpty)
        #expect(resolution == .resolved(linkAction, summary))
    }

    @Test
    func testMissingActionReturnsKindSpecificFailureMessage() {
        let summary = summary(eventId: "event-1", actions: [])

        let resolution = AppNotificationActionResolver.resolve(
            eventId: "event-1",
            actionIdentifier: ActionKind.copyText.rawValue,
            summary: summary
        )

        #expect(resolution == .failureMessage("当前通知没有可执行的复制文本"))
    }

    private func summary(
        eventId: String,
        actions: [ActionCandidate],
        visibleActionIds: [String]? = nil,
        primarySurface: RouteSurface = .actionInbox
    ) -> LocalNotificationSummary {
        let resolvedVisibleActionIds = visibleActionIds
            ?? (primarySurface == .actionInbox ? actions.map(\.actionId) : [])

        return LocalNotificationSummary(
            eventId: eventId,
            deviceId: "android-test",
            appPackage: "com.example",
            appName: "Example",
            title: "测试通知",
            text: "https://example.com",
            receivedAt: 100,
            verificationContext: nil,
            actionCandidates: actions,
            ruleDecision: RuleDecision(
                shouldPresentSystemNotification: false,
                historyPolicy: .record,
                visibleActionIds: resolvedVisibleActionIds,
                defaultActionId: resolvedVisibleActionIds.first,
                reasonCodes: ["test"],
                primarySurface: primarySurface,
                secondarySurfaces: primarySurface == .actionInbox ? [.actionInbox] : [],
                persistencePolicy: .record
            )
        )
    }

    private func action(kind: ActionKind, eventId: String) -> ActionCandidate {
        ActionCandidate(
            actionId: "\(eventId)-\(kind.rawValue)",
            sourceEventId: eventId,
            kind: kind,
            title: kind.displayTitle,
            value: value(for: kind),
            priority: .medium,
            payload: payload(for: kind)
        )
    }

    private func value(for kind: ActionKind) -> String? {
        switch kind {
        case .openLink:
            return "https://example.com"
        case .copyText:
            return "测试文本"
        case .copyVerificationCode:
            return "123456"
        case .openFile, .revealFile, .copyFilePath:
            return "/tmp/test.txt"
        case .showNotification, .recordHistory:
            return nil
        }
    }

    private func payload(for kind: ActionKind) -> ActionPayload {
        switch kind {
        case .openLink:
            return .link(url: "https://example.com")
        case .copyText:
            return .text(value: "测试文本")
        case .copyVerificationCode:
            return .verificationCode(code: "123456", senderLabel: "短信")
        case .openFile, .revealFile, .copyFilePath:
            return .file(path: "/tmp/test.txt", fileName: "test.txt", mimeType: "text/plain")
        case .showNotification:
            return .notificationPreview(title: "测试通知", text: "测试文本")
        case .recordHistory:
            return .historyRecord
        }
    }
}
