import Foundation
import Testing
@testable import AndroidMacNotifyMac

struct LocalNotificationHandlerTests {
    @Test
    func testAcceptedNotificationPersistsAndEmitsSummary() throws {
        let handler = LocalNotificationHandler()
        var registry = LocalDeviceRegistry()
        _ = registry.register(
            testNotificationDevice(),
            at: 100,
            tokenFactory: { "device-token" }
        )
        var store = LocalNotificationIngestStore()

        let result = try handler.handleEvent(
            payload: notificationPayload(eventId: "event-1"),
            headers: authorizationHeaders(),
            registry: &registry,
            ingestStore: &store,
            receiverState: .active,
            now: 200
        )
        let response = try decodeNotification(NotificationAcceptedResponse.self, from: result.response)

        #expect(result.response.statusCode == 202)
        #expect(result.shouldPersist)
        #expect(response.accepted)
        #expect(!response.deduplicated)
        #expect(result.event?.notificationEventId == "event-1")
        #expect(store.storedSummaries.map(\.eventId) == ["event-1"])
    }

    @Test
    func testDuplicateNotificationDoesNotEmitSummary() throws {
        let handler = LocalNotificationHandler()
        var registry = LocalDeviceRegistry()
        _ = registry.register(
            testNotificationDevice(),
            at: 100,
            tokenFactory: { "device-token" }
        )
        var store = LocalNotificationIngestStore()
        let payload = notificationPayload(eventId: "event-1")
        _ = try handler.handleEvent(
            payload: payload,
            headers: authorizationHeaders(),
            registry: &registry,
            ingestStore: &store,
            receiverState: .active,
            now: 200
        )

        let duplicate = try handler.handleEvent(
            payload: payload,
            headers: authorizationHeaders(),
            registry: &registry,
            ingestStore: &store,
            receiverState: .active,
            now: 300
        )
        let response = try decodeNotification(NotificationAcceptedResponse.self, from: duplicate.response)

        #expect(duplicate.shouldPersist)
        #expect(response.deduplicated)
        #expect(duplicate.event == nil)
        #expect(store.storedSummaries.map(\.eventId) == ["event-1"])
    }

    @Test
    func testPausedReceiverReturnsRetryableConflictAndUpdatesLastSeen() throws {
        let handler = LocalNotificationHandler()
        var registry = LocalDeviceRegistry()
        _ = registry.register(
            testNotificationDevice(),
            at: 100,
            tokenFactory: { "device-token" }
        )
        var store = LocalNotificationIngestStore()

        let result = try handler.handleEvent(
            payload: notificationPayload(eventId: "event-paused"),
            headers: authorizationHeaders(),
            registry: &registry,
            ingestStore: &store,
            receiverState: .paused,
            now: 500
        )

        #expect(result.response.statusCode == 409)
        #expect(result.shouldPersist)
        #expect(result.event == nil)
        #expect(store.storedSummaries.isEmpty)
        #expect(registry.device(withId: "android-test")?.lastSeenAt == 500)
    }
}

private func testNotificationDevice() -> DeviceIdentity {
    DeviceIdentity(deviceId: "android-test", platform: "android", displayName: "Android Test")
}

private func authorizationHeaders() -> [String: String] {
    ["authorization": "Bearer device-token"]
}

private func notificationPayload(eventId: String) -> NotificationEventPayload {
    NotificationEventPayload(
        eventId: eventId,
        deviceId: "android-test",
        appPackage: "com.example.browser",
        appName: "Browser",
        title: "Continue",
        text: "https://example.com",
        postedAt: 100,
        notificationKey: "key-\(eventId)"
    )
}

private func decodeNotification<Value: Decodable>(_ type: Value.Type, from response: HTTPResponse) throws -> Value {
    try JSONDecoder().decode(Value.self, from: response.body)
}

private extension LocalServerEvent {
    var notificationEventId: String? {
        if case let .notificationAccepted(summary) = self {
            return summary.eventId
        }
        return nil
    }
}
