import Testing
@testable import AndroidMacNotifyMac

struct AppDeviceSessionProjectionTests {
    @Test
    func testRegisteredDeviceReplacesExistingAndProjectsNewDevice() {
        let projector = AppConnectionStateProjector(staleTimeoutMillis: 45_000)
        let oldDevice = device(id: "android-1", name: "Old Phone", lastSeenAt: 100)
        let newDevice = device(id: "android-1", name: "OCE-AN10", lastSeenAt: 200)

        let projection = AppDeviceSessionProjector.registered(
            device: newDevice,
            existingDevices: [oldDevice],
            isReceiverPaused: false,
            now: 201,
            connectionStateProjector: projector
        )

        #expect(projection.registeredDevices == [newDevice])
        #expect(projection.pairedDeviceName == "OCE-AN10")
        #expect(projection.connectionState == .connected(deviceName: "OCE-AN10"))
    }

    @Test
    func testHeartbeatUpdatesDeviceAndMarksRelayActive() {
        let projector = AppConnectionStateProjector()
        let pausedDevice = device(id: "android-1", name: "OCE-AN10", lastSeenAt: 100, relayState: .paused)

        let projection = AppDeviceSessionProjector.heartbeat(
            deviceId: "android-1",
            at: 200,
            existingDevices: [pausedDevice],
            currentPairedDeviceName: nil,
            currentConnectionState: .waitingForPair,
            isReceiverPaused: false,
            connectionStateProjector: projector
        )

        #expect(projection.registeredDevices.first?.lastSeenAt == 200)
        #expect(projection.registeredDevices.first?.relayState == .active)
        #expect(projection.pairedDeviceName == "OCE-AN10")
        #expect(projection.connectionState == .connected(deviceName: "OCE-AN10"))
    }

    @Test
    func testUnknownHeartbeatKeepsCurrentStateWhenThereAreNoDevices() {
        let projector = AppConnectionStateProjector()

        let projection = AppDeviceSessionProjector.heartbeat(
            deviceId: "missing",
            at: 200,
            existingDevices: [],
            currentPairedDeviceName: "OCE-AN10",
            currentConnectionState: .connected(deviceName: "OCE-AN10"),
            isReceiverPaused: false,
            connectionStateProjector: projector
        )

        #expect(projection.registeredDevices.isEmpty)
        #expect(projection.pairedDeviceName == "OCE-AN10")
        #expect(projection.connectionState == .connected(deviceName: "OCE-AN10"))
    }

    @Test
    func testUnregisteredDeviceProjectsRemainingMostRecentDevice() {
        let projector = AppConnectionStateProjector()
        let removedDevice = device(id: "android-1", name: "Old Phone", lastSeenAt: 100)
        let remainingDevice = device(id: "android-2", name: "New Phone", lastSeenAt: 200)

        let projection = AppDeviceSessionProjector.unregistered(
            deviceId: "android-1",
            existingDevices: [removedDevice, remainingDevice],
            isReceiverPaused: false,
            now: 201,
            connectionStateProjector: projector
        )

        #expect(projection.registeredDevices == [remainingDevice])
        #expect(projection.pairedDeviceName == "New Phone")
        #expect(projection.connectionState == .connected(deviceName: "New Phone"))
    }

    private func device(
        id: String,
        name: String,
        lastSeenAt: Int64,
        relayState: RelayState? = .active
    ) -> LocalRegisteredDevice {
        LocalRegisteredDevice(
            deviceId: id,
            platform: "android",
            displayName: name,
            deviceToken: "token-\(id)",
            lastSeenAt: lastSeenAt,
            relayState: relayState
        )
    }
}
