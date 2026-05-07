import Foundation
import Testing
@testable import AndroidMacNotifyMac

struct LocalSessionHandlerTests {
    @Test
    func testHeartbeatUpdatesLastSeenAndReturnsConnectedState() throws {
        let handler = LocalSessionHandler()
        var registry = sessionRegistry()

        let result = try handler.handleHeartbeat(
            headers: sessionHeaders(),
            payload: HeartbeatRequest(deviceId: "android-test", sentAt: 10, networkType: "wifi"),
            registry: &registry,
            receiverState: .active,
            now: 500
        )
        let response = try decode(HeartbeatResponse.self, from: result.response)

        #expect(result.shouldPersist)
        #expect(response.ok)
        #expect(response.serverTime == 500)
        #expect(response.sessionState == "connected")
        #expect(registry.device(withId: "android-test")?.lastSeenAt == 500)
        #expect(registry.device(withId: "android-test")?.relayState == .active)
        #expect(result.event?.isHeartbeat(for: "android-test", at: 500) == true)
    }

    @Test
    func testRelayStateUpdateReturnsPausedStateAndDeviceEvent() throws {
        let handler = LocalSessionHandler()
        var registry = sessionRegistry()

        let result = try handler.handleRelayStateUpdate(
            headers: sessionHeaders(),
            payload: RelayStateRequest(deviceId: "android-test", relayState: .paused, sentAt: 10),
            registry: &registry,
            receiverState: .active,
            now: 600
        )
        let response = try decode(RelayStateResponse.self, from: result.response)

        #expect(result.shouldPersist)
        #expect(response.ok)
        #expect(response.sessionState == "paused")
        #expect(registry.device(withId: "android-test")?.relayState == .paused)
        #expect(result.event?.updatedDeviceId == "android-test")
    }

    @Test
    func testSessionForgetRemovesDeviceAndReturnsUnpaired() throws {
        let handler = LocalSessionHandler()
        var registry = sessionRegistry()

        let result = try handler.handleSessionForget(
            headers: sessionHeaders(),
            payload: SessionForgetRequest(deviceId: "android-test", sentAt: 10),
            registry: &registry,
            now: 700
        )
        let response = try decode(SessionForgetResponse.self, from: result.response)

        #expect(result.shouldPersist)
        #expect(response.ok)
        #expect(response.sessionState == "unpaired")
        #expect(registry.device(withId: "android-test") == nil)
        #expect(result.event?.unregisteredDeviceId == "android-test")
    }

    @Test
    func testSessionStatusDoesNotMutateOrPersist() throws {
        let handler = LocalSessionHandler()
        let registry = sessionRegistry()

        let result = try handler.handleSessionStatus(
            headers: sessionHeaders(),
            requestedDeviceId: "android-test",
            registry: registry,
            receiverState: .paused,
            now: 800,
            macDeviceId: "mac-test",
            macDisplayName: "Test Mac"
        )
        let response = try decode(SessionStatusResponse.self, from: result.response)

        #expect(!result.shouldPersist)
        #expect(result.event == nil)
        #expect(response.deviceId == "android-test")
        #expect(response.sessionState == "mac_paused")
        #expect(response.macDeviceId == "mac-test")
        #expect(response.macDisplayName == "Test Mac")
    }
}

private func sessionRegistry() -> LocalDeviceRegistry {
    var registry = LocalDeviceRegistry()
    _ = registry.register(
        DeviceIdentity(deviceId: "android-test", platform: "android", displayName: "Phone"),
        at: 100,
        tokenFactory: { "token-1" }
    )
    return registry
}

private func sessionHeaders() -> [String: String] {
    ["authorization": "Bearer token-1"]
}

private func decode<Value: Decodable>(_ type: Value.Type, from response: HTTPResponse) throws -> Value {
    try JSONDecoder().decode(Value.self, from: response.body)
}

private extension LocalServerEvent {
    func isHeartbeat(for deviceId: String, at timestamp: Int64) -> Bool {
        if case let .heartbeat(eventDeviceId, eventTimestamp) = self {
            return eventDeviceId == deviceId && eventTimestamp == timestamp
        }
        return false
    }

    var updatedDeviceId: String? {
        if case let .deviceSessionUpdated(device) = self {
            return device.deviceId
        }
        return nil
    }

    var unregisteredDeviceId: String? {
        if case let .deviceUnregistered(deviceId) = self {
            return deviceId
        }
        return nil
    }
}
