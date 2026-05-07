import Testing
@testable import AndroidMacNotifyMac

struct AppLocalServerRuntimeProjectionTests {
    @Test
    func testSnapshotProjectsRunningStateAndRecentNotifications() {
        let device = registeredDevice(name: "OCE-AN10", lastSeenAt: 1_000)
        let recentNotification = notificationSummary(eventId: "event-1", receivedAt: 1_100)
        let snapshot = localServerSnapshot(
            registeredDevices: [device],
            recentNotifications: [recentNotification]
        )

        let projection = AppLocalServerRuntimeProjector.snapshot(
            snapshot,
            isReceiverPaused: false,
            now: 1_200,
            connectionStateProjector: AppConnectionStateProjector()
        )

        #expect(projection.currentHost == "192.168.1.2")
        #expect(projection.currentPort == 38471)
        #expect(projection.serverStatus == .running(host: "192.168.1.2", port: 38471))
        #expect(projection.registeredDevices == [device])
        #expect(projection.notificationsReceived == 1)
        #expect(projection.recentNotifications == [recentNotification])
        #expect(projection.lastNotificationSummary == recentNotification)
        #expect(projection.transientNotifications.isEmpty)
        #expect(projection.transientActionSummaries.isEmpty)
        #expect(projection.pairedDeviceName == "OCE-AN10")
        #expect(projection.connectionState == .connected(deviceName: "OCE-AN10"))
    }

    @Test
    func testSnapshotHonorsReceiverPause() {
        let device = registeredDevice(name: "OCE-AN10", lastSeenAt: 1_000)
        let snapshot = localServerSnapshot(registeredDevices: [device])

        let projection = AppLocalServerRuntimeProjector.snapshot(
            snapshot,
            isReceiverPaused: true,
            now: 1_200,
            connectionStateProjector: AppConnectionStateProjector()
        )

        #expect(projection.pairedDeviceName == "OCE-AN10")
        #expect(projection.connectionState == .macReceiverPaused(deviceName: "OCE-AN10"))
    }

    @Test
    func testStoppedClearsRuntimeReceiverState() {
        let projection = AppLocalServerRuntimeProjector.stopped(pairedDeviceName: "OCE-AN10")

        #expect(projection.serverStatus == .stopped)
        #expect(projection.isReceiverPaused == false)
        #expect(projection.pairingToken == nil)
        #expect(projection.pairingTokenExpiresAt == nil)
        #expect(projection.connectionState == .macReceiverPaused(deviceName: "OCE-AN10"))
        #expect(projection.sharedFileReceiveStatus == nil)
    }

    @Test
    func testStoppedWithoutDeviceBecomesUnpaired() {
        let projection = AppLocalServerRuntimeProjector.stopped(pairedDeviceName: nil)

        #expect(projection.connectionState == .unpaired)
    }

    @Test
    func testFailureProjectsNetworkUnavailable() {
        let projection = AppLocalServerRuntimeProjector.failed(message: "端口被占用")

        #expect(projection.lastError == "端口被占用")
        #expect(projection.serverStatus == .failed(message: "端口被占用"))
        #expect(projection.connectionState == .networkUnavailable)
    }

    private func localServerSnapshot(
        registeredDevices: [LocalRegisteredDevice] = [],
        recentNotifications: [LocalNotificationSummary] = []
    ) -> LocalServerSnapshot {
        LocalServerSnapshot(
            endpoint: LocalServerEndpoint(host: "192.168.1.2", port: 38471),
            pairingToken: "pair-token",
            pairingTokenExpiresAt: 9_999,
            macDeviceId: "mac-1",
            macDisplayName: "Valnve's Mac",
            pairedDeviceCount: registeredDevices.count,
            registeredDevices: registeredDevices,
            recentNotifications: recentNotifications
        )
    }

    private func registeredDevice(name: String, lastSeenAt: Int64) -> LocalRegisteredDevice {
        LocalRegisteredDevice(
            deviceId: "android-\(name)",
            platform: "android",
            displayName: name,
            deviceToken: "token-\(name)",
            lastSeenAt: lastSeenAt,
            relayState: .active
        )
    }

    private func notificationSummary(eventId: String, receivedAt: Int64) -> LocalNotificationSummary {
        LocalNotificationSummary(
            eventId: eventId,
            deviceId: "android-test",
            appPackage: "com.example.browser",
            appName: "Browser",
            title: "测试通知",
            text: "https://example.com",
            receivedAt: receivedAt,
            verificationContext: nil,
            actionCandidates: [],
            ruleDecision: .passthrough(eventId: eventId, actionCandidates: [])
        )
    }
}
