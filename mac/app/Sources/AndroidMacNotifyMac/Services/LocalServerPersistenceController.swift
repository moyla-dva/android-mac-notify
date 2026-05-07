import Foundation

struct LocalServerPersistenceSnapshot: Sendable {
    let macDeviceId: String
    let registeredDevices: [LocalRegisteredDevice]
    let recentNotifications: [LocalNotificationSummary]
}

actor LocalServerPersistenceController {
    private let persistence: LocalServerStatePersistence
    private var hasLoadedState = false

    init(stateStore: MacStateStore) {
        persistence = LocalServerStatePersistence(stateStore: stateStore)
    }

    func loadIfNeeded(defaultMacDeviceId: String) async throws -> MacStateStore.StoredState? {
        guard !hasLoadedState else {
            return nil
        }

        let state = try await persistence.load(defaultMacDeviceId: defaultMacDeviceId)
        hasLoadedState = true
        return state
    }

    func save(_ snapshot: LocalServerPersistenceSnapshot) async throws {
        try await persistence.save(
            macDeviceId: snapshot.macDeviceId,
            registeredDevices: snapshot.registeredDevices,
            recentNotifications: snapshot.recentNotifications
        )
    }

    func saveIfNeeded(
        _ snapshot: LocalServerPersistenceSnapshot,
        for finalization: LocalRouteFinalization
    ) async throws {
        guard finalization.shouldPersist else {
            return
        }
        try await save(snapshot)
    }

    func clear(defaultMacDeviceId: String) async throws -> MacStateStore.StoredState {
        try await persistence.clear(defaultMacDeviceId: defaultMacDeviceId)
    }
}
