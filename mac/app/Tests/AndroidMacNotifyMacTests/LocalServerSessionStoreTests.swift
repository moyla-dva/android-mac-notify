import Foundation
import Testing
@testable import AndroidMacNotifyMac

struct LocalServerSessionStoreTests {
    @Test
    func testReceiverPauseStateIsOwnedBySessionStore() {
        var store = LocalServerSessionStore()

        store.setReceiverPaused(true)
        #expect(store.receiverState == .paused)

        store.setReceiverPaused(false)
        #expect(store.receiverState == .active)

        store.setReceiverPaused(true)
        store.resetReceiverState()
        #expect(store.receiverState == .active)
    }

    @Test
    func testCurrentRegisteredDevicesAreSorted() {
        var registry = LocalDeviceRegistry()
        _ = registry.register(
            DeviceIdentity(deviceId: "phone-b", platform: "android", displayName: "Phone B"),
            at: 100,
            tokenFactory: { "token-b" }
        )
        _ = registry.register(
            DeviceIdentity(deviceId: "phone-a", platform: "android", displayName: "Phone A"),
            at: 101,
            tokenFactory: { "token-a" }
        )

        let store = LocalServerSessionStore(deviceRegistry: registry)

        #expect(store.pairedDeviceCount == 2)
        #expect(store.currentRegisteredDevices().map(\.deviceId) == ["phone-a", "phone-b"])
    }
}
