import Testing
@testable import AndroidMacNotifyMac

struct ActionClassifierTests {
    @Test
    func testVerificationCodeSmsDoesNotOfferCopyTextFallback() {
        let actions = ActionClassifier.candidates(
            for: InboundEvent(
                eventId: "sms-verification-code",
                kind: .notification,
                sourceDeviceId: "android",
                occurredAt: 1,
                receivedAt: 1,
                payload: .notification(
                    NotificationPayload(
                        appPackage: "com.android.mms",
                        appName: "短信",
                        title: "登录短信码",
                        text: "你的短信码是 864219，5 分钟内有效。",
                        notificationKey: "sms-key"
                    )
                ),
                metadata: EventMetadata(route: "notification", sourceAppPackage: "com.android.mms")
            )
        )

        #expect(actions.contains { $0.kind == .copyVerificationCode && $0.verificationCode == "864219" })
        #expect(!actions.contains { $0.kind == .copyText })
    }

    @Test
    func testPlainSmsStillOffersCopyText() {
        let actions = ActionClassifier.candidates(
            for: InboundEvent(
                eventId: "plain-sms",
                kind: .notification,
                sourceDeviceId: "android",
                occurredAt: 1,
                receivedAt: 1,
                payload: .notification(
                    NotificationPayload(
                        appPackage: "com.android.mms",
                        appName: "短信",
                        title: "朋友",
                        text: "今晚八点见",
                        notificationKey: "plain-sms-key"
                    )
                ),
                metadata: EventMetadata(route: "notification", sourceAppPackage: "com.android.mms")
            )
        )

        #expect(actions.contains { $0.kind == .copyText && $0.textValue == "今晚八点见" })
    }
}
