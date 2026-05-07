import Foundation
import Testing
@testable import AndroidMacNotifyMac

struct LocalDeviceRegistryTests {
    @Test
    func testRegisterAuthenticatesAndReusesExistingToken() {
        var registry = LocalDeviceRegistry()
        let first = registry.register(
            DeviceIdentity(deviceId: "android-test", platform: "android", displayName: "Phone"),
            at: 100,
            tokenFactory: { "token-1" }
        )
        let second = registry.register(
            DeviceIdentity(deviceId: "android-test", platform: "android", displayName: "Phone Renamed"),
            at: 200,
            reuseExistingToken: true,
            tokenFactory: { "token-2" }
        )

        #expect(first.deviceToken == "token-1")
        #expect(second.deviceToken == "token-1")
        #expect(second.displayName == "Phone Renamed")
        #expect(registry.authenticate(headers: ["authorization": "Bearer token-1"]) == "android-test")
        #expect(registry.authenticate(headers: ["authorization": "Bearer token-2"]) == nil)
    }

    @Test
    func testSessionStateHonorsMacPauseDevicePauseAndTimeout() {
        var registry = LocalDeviceRegistry()
        _ = registry.register(
            DeviceIdentity(deviceId: "android-test", platform: "android", displayName: "Phone"),
            at: 1_000,
            tokenFactory: { "token-1" }
        )

        #expect(registry.sessionState(for: "missing", receiverState: .active, now: 1_000) == "unpaired")
        #expect(registry.sessionState(for: "android-test", receiverState: .paused, now: 1_000) == "mac_paused")
        #expect(registry.sessionState(for: "android-test", receiverState: .active, now: 46_001) == "disconnected_retrying")

        registry.updateLastSeen(for: "android-test", at: 46_001, relayState: .paused)

        #expect(registry.sessionState(for: "android-test", receiverState: .active, now: 46_001) == "paused")
    }

    @Test
    func testRemoveDeviceClearsTokenIndex() {
        var registry = LocalDeviceRegistry()
        _ = registry.register(
            DeviceIdentity(deviceId: "android-test", platform: "android", displayName: "Phone"),
            at: 100,
            tokenFactory: { "token-1" }
        )

        let removed = registry.removeDevice(deviceId: "android-test")

        #expect(removed?.deviceToken == "token-1")
        #expect(registry.count == 0)
        #expect(registry.authenticate(headers: ["authorization": "Bearer token-1"]) == nil)
    }
}
