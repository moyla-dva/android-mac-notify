import Foundation

struct LocalServerStatePersistence: Sendable {
    private let stateStore: MacStateStore

    init(stateStore: MacStateStore) {
        self.stateStore = stateStore
    }

    func load(defaultMacDeviceId: String) async throws -> MacStateStore.StoredState {
        try await stateStore.load(defaultMacDeviceId: defaultMacDeviceId)
    }

    func save(
        macDeviceId: String,
        registeredDevices: [LocalRegisteredDevice],
        recentNotifications: [LocalNotificationSummary]
    ) async throws {
        try await stateStore.save(
            storedState(
                macDeviceId: macDeviceId,
                registeredDevices: registeredDevices,
                recentNotifications: recentNotifications
            )
        )
    }

    func clear(defaultMacDeviceId: String) async throws -> MacStateStore.StoredState {
        try await stateStore.clear(defaultMacDeviceId: defaultMacDeviceId)
    }

    func storedState(
        macDeviceId: String,
        registeredDevices: [LocalRegisteredDevice],
        recentNotifications: [LocalNotificationSummary]
    ) -> MacStateStore.StoredState {
        MacStateStore.StoredState(
            schemaVersion: 1,
            macDeviceId: macDeviceId,
            registeredDevices: registeredDevices,
            recentNotifications: recentNotifications
        )
    }
}
