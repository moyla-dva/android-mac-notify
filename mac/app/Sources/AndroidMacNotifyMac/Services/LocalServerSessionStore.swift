import Foundation

struct LocalServerSessionStore: Sendable {
    var deviceRegistry: LocalDeviceRegistry
    var receiverState: RelayState

    init(
        deviceRegistry: LocalDeviceRegistry = LocalDeviceRegistry(),
        receiverState: RelayState = .active
    ) {
        self.deviceRegistry = deviceRegistry
        self.receiverState = receiverState
    }

    mutating func setReceiverPaused(_ isPaused: Bool) {
        receiverState = isPaused ? .paused : .active
    }

    mutating func resetReceiverState() {
        receiverState = .active
    }

    func currentRegisteredDevices() -> [LocalRegisteredDevice] {
        deviceRegistry.currentRegisteredDevices()
    }

    var pairedDeviceCount: Int {
        deviceRegistry.count
    }
}
