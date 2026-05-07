import Testing
@testable import AndroidMacNotifyMac

struct AppUIDisplayFormattingTests {
    @Test
    func testDisplayAppNameMapsKnownPackages() {
        #expect(summary(appPackage: "com.tencent.mm", appName: "com.tencent.mm").displayAppName == "微信")
        #expect(summary(appPackage: "com.sankuai.meituan.takeoutnew", appName: "meituan").displayAppName == "美团外卖")
        #expect(summary(appPackage: "org.telegram.messenger.web", appName: "telegram").displayAppName == "Telegram")
    }

    @Test
    func testDisplayAppNameFallsBackToLastPackageComponent() {
        #expect(summary(appPackage: nil, appName: "com.example.longname").displayAppName == "longname")
    }

    @Test
    func testDisplaySourceTitleAvoidsRepeatingAppName() {
        #expect(summary(appPackage: "com.tencent.mm", appName: "微信", title: "微信").displaySourceTitle == "微信")
        #expect(summary(appPackage: "com.tencent.mm", appName: "微信", title: "文件传输助手").displaySourceTitle == "微信 · 文件传输助手")
    }

    @Test
    func testPrimaryPreviewPrefersVerificationSenderThenTextThenTitle() {
        let verificationSummary = summary(
            title: "验证码",
            text: "正文",
            actions: [
                ActionCandidate(
                    actionId: "action-code",
                    sourceEventId: "event",
                    kind: .copyVerificationCode,
                    title: "复制验证码",
                    value: "123456",
                    priority: .high,
                    payload: .verificationCode(code: "123456", senderLabel: "银行")
                ),
            ]
        )
        let textSummary = summary(title: "标题", text: "正文")
        let titleOnlySummary = summary(title: "标题", text: "   ")

        #expect(verificationSummary.primaryPreview == "发送方 银行")
        #expect(textSummary.primaryPreview == "正文")
        #expect(titleOnlySummary.primaryPreview == "标题")
    }

    @Test
    func testSharedFileDisplayFields() {
        let fileAction = ActionCandidate(
            actionId: "open-file",
            sourceEventId: "event-file",
            kind: .openFile,
            title: "打开文件",
            value: "/tmp/demo.txt",
            priority: .medium,
            payload: .file(path: "/tmp/demo.txt", fileName: "demo.txt", mimeType: "text/plain")
        )
        let fileSummary = summary(
            eventId: "event-file",
            title: "demo.txt",
            text: "12 KB · /tmp/demo.txt",
            actions: [fileAction],
            ruleDecision: RuleDecision(
                shouldPresentSystemNotification: false,
                historyPolicy: .record,
                visibleActionIds: [fileAction.actionId],
                defaultActionId: fileAction.actionId,
                reasonCodes: ["shared_file_received"],
                primarySurface: .actionInbox,
                persistencePolicy: .record
            )
        )

        #expect(fileSummary.sharedFilePath == "/tmp/demo.txt")
        #expect(fileSummary.sharedFileSizeText == "12 KB")
        #expect(fileSummary.routeBadgeText == "文件")
    }

    private func summary(
        eventId: String = "event",
        appPackage: String? = "com.example",
        appName: String = "Example",
        title: String = "标题",
        text: String = "正文",
        actions: [ActionCandidate] = [],
        ruleDecision: RuleDecision? = nil
    ) -> LocalNotificationSummary {
        LocalNotificationSummary(
            eventId: eventId,
            deviceId: "android-test",
            appPackage: appPackage,
            appName: appName,
            title: title,
            text: text,
            receivedAt: 100,
            verificationContext: nil,
            actionCandidates: actions,
            ruleDecision: ruleDecision ?? .passthrough(eventId: eventId, actionCandidates: actions)
        )
    }
}
