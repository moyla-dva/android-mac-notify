import Foundation
import Testing
@testable import AndroidMacNotifyMac

struct LocalRelayReceiverGateTests {
    @Test
    func testActiveReceiverUpdatesLastSeenAndAllowsRelay() {
        let gate = LocalRelayReceiverGate()
        var registry = relayGateRegistry()

        let response = gate.prepareInboundRelay(
            deviceId: "android-test",
            registry: &registry,
            receiverState: .active,
            at: 500
        )

        #expect(response == nil)
        #expect(registry.device(withId: "android-test")?.lastSeenAt == 500)
        #expect(registry.device(withId: "android-test")?.relayState == .active)
    }

    @Test
    func testPausedReceiverUpdatesLastSeenAndRejectsRelay() {
        let gate = LocalRelayReceiverGate()
        var registry = relayGateRegistry()

        let response = gate.prepareInboundRelay(
            deviceId: "android-test",
            registry: &registry,
            receiverState: .paused,
            at: 500
        )

        #expect(response?.statusCode == 409)
        #expect(registry.device(withId: "android-test")?.lastSeenAt == 500)
        #expect(registry.device(withId: "android-test")?.relayState == .active)
    }
}

private func relayGateRegistry() -> LocalDeviceRegistry {
    var registry = LocalDeviceRegistry()
    _ = registry.register(
        DeviceIdentity(deviceId: "android-test", platform: "android", displayName: "Phone"),
        at: 100,
        tokenFactory: { "token-1" }
    )
    return registry
}
