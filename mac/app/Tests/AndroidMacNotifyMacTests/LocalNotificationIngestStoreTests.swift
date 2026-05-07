import Foundation
import Testing
@testable import AndroidMacNotifyMac

struct LocalNotificationIngestStoreTests {
    @Test
    func testIngestStoresRecordableNotificationAndDeduplicatesRepeat() {
        var store = LocalNotificationIngestStore()
        let payload = notificationPayload(
            eventId: "event-1",
            appPackage: "com.example.browser",
            appName: "Browser",
            title: "Continue",
            text: "https://example.com"
        )

        let first = store.ingest(payload: payload, receivedAt: 1_000)
        let second = store.ingest(payload: payload, receivedAt: 2_000)

        #expect(first.response.accepted)
        #expect(!first.response.deduplicated)
        #expect(first.acceptedSummary?.eventId == "event-1")
        #expect(store.storedSummaries.map(\.eventId) == ["event-1"])
        #expect(second.response.deduplicated)
        #expect(second.acceptedSummary == nil)
        #expect(store.storedSummaries.map(\.eventId) == ["event-1"])
    }

    @Test
    func testVerificationCodeIsAcceptedButNotStoredInHistory() {
        var store = LocalNotificationIngestStore()
        let payload = notificationPayload(
            eventId: "event-code",
            appPackage: "com.android.mms",
            appName: "短信",
            title: "登录验证码",
            text: "验证码 123456，5 分钟内有效"
        )

        let result = store.ingest(payload: payload, receivedAt: 1_000)

        #expect(result.acceptedSummary?.verificationCode == "123456")
        #expect(store.storedSummaries.isEmpty)
    }

    @Test
    func testNumericSenderSmsVerificationCodeCreatesCopyCodeAction() {
        var store = LocalNotificationIngestStore()
        let payload = notificationPayload(
            eventId: "event-numeric-sender-code",
            appPackage: "com.android.mms",
            appName: "com.android.mms",
            title: "106814270015948",
            text: "…您的验证码是 004488，请于15分钟内正确输入。"
        )

        let result = store.ingest(payload: payload, receivedAt: 1_000)

        #expect(result.acceptedSummary?.verificationCode == "004488")
        #expect(result.acceptedSummary?.visibleActionCandidates.map(\.kind) == [.copyVerificationCode])
        #expect(store.storedSummaries.isEmpty)
    }

    @Test
    func testReplacePersistedSummariesRebuildsDedupIndex() {
        var store = LocalNotificationIngestStore()
        let payload = notificationPayload(
            eventId: "event-1",
            appPackage: "com.example.browser",
            appName: "Browser",
            title: "Continue",
            text: "https://example.com"
        )
        let summary = store.ingest(payload: payload, receivedAt: 1_000).acceptedSummary!

        var restoredStore = LocalNotificationIngestStore()
        let didPrune = restoredStore.replacePersistedSummaries([summary], now: 2_000)
        let duplicate = restoredStore.ingest(payload: payload, receivedAt: 3_000)

        #expect(!didPrune)
        #expect(duplicate.response.deduplicated)
        #expect(restoredStore.storedSummaries.map(\.eventId) == ["event-1"])
    }

    private func notificationPayload(
        eventId: String,
        appPackage: String,
        appName: String,
        title: String,
        text: String
    ) -> NotificationEventPayload {
        NotificationEventPayload(
            eventId: eventId,
            deviceId: "android-test",
            appPackage: appPackage,
            appName: appName,
            title: title,
            text: text,
            postedAt: 100,
            notificationKey: "key-\(eventId)"
        )
    }
}
