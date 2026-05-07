import Foundation
import Testing
@testable import AndroidMacNotifyMac

struct LocalServerRoutingStateTests {
    enum TestError: Error {
        case expected
    }

    @Test
    func testMutateRouteStoresWritesAllStoresBack() {
        var state = LocalServerRoutingState(
            macDeviceId: "mac-1",
            pairingTokenLifetimeMillis: 100
        )

        state.mutateRouteStores { pairingTokenManager, deviceRegistry, notificationIngestStore, pairingApprovalStore in
            _ = pairingTokenManager.rotate(at: 10, tokenFactory: { "pair-1" })
            _ = deviceRegistry.register(
                DeviceIdentity(deviceId: "phone-1", platform: "android", displayName: "Phone"),
                at: 11,
                tokenFactory: { "device-token" }
            )
            _ = notificationIngestStore.ingest(
                payload: NotificationEventPayload(
                    eventId: "event-1",
                    deviceId: "phone-1",
                    appPackage: "com.test",
                    appName: "Test",
                    title: "Title",
                    text: "Body",
                    postedAt: 12,
                    notificationKey: "notification-1"
                ),
                receivedAt: 13
            )
            _ = pairingApprovalStore.createPending(
                requestId: "request-1",
                device: DeviceIdentity(deviceId: "phone-2", platform: "android", displayName: "Second Phone"),
                requestedAt: 14,
                expiresAt: 114
            )
        }

        #expect(state.pairingTokenManager.currentToken == "pair-1")
        #expect(state.sessionStore.deviceRegistry.device(withId: "phone-1")?.deviceToken == "device-token")
        #expect(state.notificationIngestStore.storedSummaries.map(\.eventId) == ["event-1"])
        #expect(state.pairingApprovalStore.record(for: "request-1")?.request.status == .pending)
    }

    @Test
    func testMutateRouteStoresWritesBackBeforeThrowing() {
        var state = LocalServerRoutingState(
            macDeviceId: "mac-1",
            pairingTokenLifetimeMillis: 100
        )

        do {
            try state.mutateRouteStores { pairingTokenManager, deviceRegistry, _, _ in
                _ = pairingTokenManager.rotate(at: 10, tokenFactory: { "pair-1" })
                _ = deviceRegistry.register(
                    DeviceIdentity(deviceId: "phone-1", platform: "android", displayName: "Phone"),
                    at: 11,
                    tokenFactory: { "device-token" }
                )
                throw TestError.expected
            }
        } catch TestError.expected {
            // Expected path.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(state.pairingTokenManager.currentToken == "pair-1")
        #expect(state.sessionStore.deviceRegistry.device(withId: "phone-1")?.deviceToken == "device-token")
    }
}
