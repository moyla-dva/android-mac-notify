import Foundation
import Testing
@testable import AndroidMacNotifyMac

struct LocalServerStateCoordinatorTests {
    @Test
    func testApplyLoadedStateRestoresRegistryAndPrunesExpiredNotifications() {
        let coordinator = LocalServerStateCoordinator()
        let device = stateCoordinatorDevice()
        let expiredSummary = stateCoordinatorSummary(eventId: "old-event", receivedAt: 100)
        let state = MacStateStore.StoredState(
            schemaVersion: 1,
            macDeviceId: "mac-restored",
            registeredDevices: [device],
            recentNotifications: [expiredSummary]
        )
        var registry = LocalDeviceRegistry()
        var notificationStore = LocalNotificationIngestStore()

        let result = coordinator.applyLoadedState(
            state,
            deviceRegistry: &registry,
            notificationIngestStore: &notificationStore,
            now: 100 + NotificationHistoryPolicy.maxStoredAgeMillis + 1
        )

        #expect(result.macDeviceId == "mac-restored")
        #expect(result.didPrunePersistedNotifications)
        #expect(registry.device(withId: "android-test") == device)
        #expect(notificationStore.storedSummaries.isEmpty)
    }

    @Test
    func testResetPairingStateClearsRuntimeStores() {
        let coordinator = LocalServerStateCoordinator()
        var registry = LocalDeviceRegistry()
        _ = registry.register(
            DeviceIdentity(deviceId: "android-test", platform: "android", displayName: "Phone"),
            at: 100,
            tokenFactory: { "device-token" }
        )
        var notificationStore = LocalNotificationIngestStore()
        _ = notificationStore.ingest(
            payload: stateCoordinatorPayload(eventId: "event-1"),
            receivedAt: 100
        )
        var approvalStore = LocalPairingApprovalStore()
        _ = approvalStore.createPending(
            requestId: "pair-1",
            device: DeviceIdentity(deviceId: "android-test", platform: "android", displayName: "Phone"),
            requestedAt: 100,
            expiresAt: 1_000
        )

        coordinator.resetPairingState(
            deviceRegistry: &registry,
            notificationIngestStore: &notificationStore,
            pairingApprovalStore: &approvalStore
        )

        #expect(registry.count == 0)
        #expect(notificationStore.storedSummaries.isEmpty)
        #expect(approvalStore.record(for: "pair-1") == nil)
    }

    @Test
    func testNotificationHistoryMutationsAreScopedToNotificationStore() {
        let coordinator = LocalServerStateCoordinator()
        var notificationStore = LocalNotificationIngestStore()
        _ = notificationStore.ingest(payload: stateCoordinatorPayload(eventId: "event-1"), receivedAt: 100)
        _ = notificationStore.ingest(payload: stateCoordinatorPayload(eventId: "event-2"), receivedAt: 101)

        coordinator.clearNotification(eventId: "event-1", notificationIngestStore: &notificationStore)

        #expect(notificationStore.storedSummaries.map(\.eventId) == ["event-2"])

        coordinator.clearNotificationHistory(notificationIngestStore: &notificationStore)

        #expect(notificationStore.storedSummaries.isEmpty)
    }

    @Test
    func testSnapshotProjectsRuntimeState() {
        let coordinator = LocalServerStateCoordinator()
        var registry = LocalDeviceRegistry()
        let device = registry.register(
            DeviceIdentity(deviceId: "android-test", platform: "android", displayName: "Phone"),
            at: 100,
            tokenFactory: { "device-token" }
        )
        var notificationStore = LocalNotificationIngestStore()
        _ = notificationStore.ingest(payload: stateCoordinatorPayload(eventId: "event-1"), receivedAt: 100)

        let snapshot = coordinator.snapshot(
            endpoint: LocalServerEndpoint(host: "127.0.0.1", port: 38471),
            pairingToken: "pair-token",
            pairingTokenExpiresAt: 9_999,
            macDeviceId: "mac-test",
            macDisplayName: "Test Mac",
            deviceRegistry: registry,
            notificationIngestStore: notificationStore
        )

        #expect(snapshot.endpoint == LocalServerEndpoint(host: "127.0.0.1", port: 38471))
        #expect(snapshot.pairingToken == "pair-token")
        #expect(snapshot.pairingTokenExpiresAt == 9_999)
        #expect(snapshot.macDeviceId == "mac-test")
        #expect(snapshot.macDisplayName == "Test Mac")
        #expect(snapshot.pairedDeviceCount == 1)
        #expect(snapshot.registeredDevices == [device])
        #expect(snapshot.recentNotifications.map(\.eventId) == ["event-1"])
    }
}

private func stateCoordinatorDevice() -> LocalRegisteredDevice {
    LocalRegisteredDevice(
        deviceId: "android-test",
        platform: "android",
        displayName: "Phone",
        deviceToken: "device-token",
        lastSeenAt: 100,
        relayState: .active
    )
}

private func stateCoordinatorSummary(eventId: String, receivedAt: Int64) -> LocalNotificationSummary {
    LocalNotificationSummary(
        eventId: eventId,
        deviceId: "android-test",
        appPackage: "com.example.browser",
        appName: "Browser",
        title: "Continue",
        text: "https://example.com",
        receivedAt: receivedAt,
        verificationContext: nil
    )
}

private func stateCoordinatorPayload(eventId: String) -> NotificationEventPayload {
    NotificationEventPayload(
        eventId: eventId,
        deviceId: "android-test",
        appPackage: "com.example.browser",
        appName: "Browser",
        title: "Continue",
        text: "https://example.com",
        postedAt: 100,
        notificationKey: "key-\(eventId)"
    )
}
