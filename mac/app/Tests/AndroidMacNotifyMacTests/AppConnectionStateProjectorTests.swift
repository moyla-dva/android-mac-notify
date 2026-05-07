import Foundation
import Testing
@testable import AndroidMacNotifyMac

struct AppConnectionStateProjectorTests {
    @Test
    func testNoDeviceWaitsForPairing() {
        let projector = AppConnectionStateProjector()

        let projection = projector.project(devices: [], isReceiverPaused: false, now: 100)

        #expect(projection.pairedDeviceName == nil)
        #expect(projection.connectionState == .waitingForPair)
    }

    @Test
    func testFreshDeviceIsConnected() {
        let projector = AppConnectionStateProjector(staleTimeoutMillis: 45_000)
        let device = registeredDevice(displayName: "OCE-AN10", lastSeenAt: 100)

        let state = projector.project(device: device, isReceiverPaused: false, now: 45_100)

        #expect(state == .connected(deviceName: "OCE-AN10"))
    }

    @Test
    func testMacPauseOverridesFreshDevice() {
        let projector = AppConnectionStateProjector()
        let device = registeredDevice(displayName: "OCE-AN10", lastSeenAt: 100)

        let state = projector.project(device: device, isReceiverPaused: true, now: 200)

        #expect(state == .macReceiverPaused(deviceName: "OCE-AN10"))
    }

    @Test
    func testDevicePauseOverridesFreshDevice() {
        let projector = AppConnectionStateProjector()
        let device = registeredDevice(displayName: "OCE-AN10", lastSeenAt: 100, relayState: .paused)

        let state = projector.project(device: device, isReceiverPaused: false, now: 200)

        #expect(state == .deviceRelayPaused(deviceName: "OCE-AN10"))
    }

    @Test
    func testStaleDeviceRetriesConnection() {
        let projector = AppConnectionStateProjector(staleTimeoutMillis: 45_000)
        let device = registeredDevice(displayName: "OCE-AN10", lastSeenAt: 100)

        let state = projector.project(device: device, isReceiverPaused: false, now: 45_101)

        #expect(state == .disconnectedRetrying)
    }

    @Test
    func testProjectionUsesMostRecentDevice() {
        let projector = AppConnectionStateProjector()
        let staleDevice = registeredDevice(displayName: "Old Phone", lastSeenAt: 100)
        let recentDevice = registeredDevice(displayName: "New Phone", lastSeenAt: 200)

        let projection = projector.project(
            devices: [staleDevice, recentDevice],
            isReceiverPaused: false,
            now: 250
        )

        #expect(projection.pairedDeviceName == "New Phone")
        #expect(projection.connectionState == .connected(deviceName: "New Phone"))
    }

    private func registeredDevice(
        displayName: String,
        lastSeenAt: Int64,
        relayState: RelayState? = .active
    ) -> LocalRegisteredDevice {
        LocalRegisteredDevice(
            deviceId: displayName,
            platform: "android",
            displayName: displayName,
            deviceToken: "token-\(displayName)",
            lastSeenAt: lastSeenAt,
            relayState: relayState
        )
    }
}
