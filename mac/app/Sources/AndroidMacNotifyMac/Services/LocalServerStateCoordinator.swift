import Foundation

struct LocalServerStateRestoreResult: Sendable {
    let macDeviceId: String
    let didPrunePersistedNotifications: Bool
}

struct LocalServerStateCoordinator: Sendable {
    func applyLoadedState(
        _ state: MacStateStore.StoredState,
        deviceRegistry: inout LocalDeviceRegistry,
        notificationIngestStore: inout LocalNotificationIngestStore,
        now: Int64
    ) -> LocalServerStateRestoreResult {
        deviceRegistry.replace(with: state.registeredDevices)
        let didPrunePersistedNotifications = notificationIngestStore.replacePersistedSummaries(
            state.recentNotifications,
            now: now
        )
        return LocalServerStateRestoreResult(
            macDeviceId: state.macDeviceId,
            didPrunePersistedNotifications: didPrunePersistedNotifications
        )
    }

    func resetPairingState(
        deviceRegistry: inout LocalDeviceRegistry,
        notificationIngestStore: inout LocalNotificationIngestStore,
        pairingApprovalStore: inout LocalPairingApprovalStore
    ) {
        deviceRegistry.removeAll()
        notificationIngestStore.removeAll()
        pairingApprovalStore.removeAll()
    }

    func clearNotificationHistory(
        notificationIngestStore: inout LocalNotificationIngestStore
    ) {
        notificationIngestStore.removeAll()
    }

    func clearNotification(
        eventId: String,
        notificationIngestStore: inout LocalNotificationIngestStore
    ) {
        notificationIngestStore.clear(eventId: eventId)
    }

    func snapshot(
        endpoint: LocalServerEndpoint,
        pairingToken: String,
        pairingTokenExpiresAt: Int64,
        macDeviceId: String,
        macDisplayName: String,
        deviceRegistry: LocalDeviceRegistry,
        notificationIngestStore: LocalNotificationIngestStore
    ) -> LocalServerSnapshot {
        LocalServerSnapshot(
            endpoint: endpoint,
            pairingToken: pairingToken,
            pairingTokenExpiresAt: pairingTokenExpiresAt,
            macDeviceId: macDeviceId,
            macDisplayName: macDisplayName,
            pairedDeviceCount: deviceRegistry.count,
            registeredDevices: deviceRegistry.currentRegisteredDevices(),
            recentNotifications: notificationIngestStore.storedSummaries
        )
    }
}
