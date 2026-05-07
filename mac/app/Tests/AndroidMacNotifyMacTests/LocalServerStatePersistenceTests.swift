import Foundation
import Testing
@testable import AndroidMacNotifyMac

struct LocalServerStatePersistenceTests {
    @Test
    func testSaveAndLoadRoundTrip() async throws {
        let fixture = try PersistenceFixture()
        defer { fixture.cleanup() }
        let persistence = fixture.persistence
        let device = LocalRegisteredDevice(
            deviceId: "android-test",
            platform: "android",
            displayName: "Phone",
            deviceToken: "token-1",
            lastSeenAt: 100,
            relayState: .active
        )

        try await persistence.save(
            macDeviceId: "mac-test",
            registeredDevices: [device],
            recentNotifications: []
        )
        let loaded = try await persistence.load(defaultMacDeviceId: "fallback-mac")

        #expect(loaded.schemaVersion == 1)
        #expect(loaded.macDeviceId == "mac-test")
        #expect(loaded.registeredDevices == [device])
        #expect(loaded.recentNotifications.isEmpty)
    }

    @Test
    func testClearWritesEmptyStateForDefaultMac() async throws {
        let fixture = try PersistenceFixture()
        defer { fixture.cleanup() }

        try await fixture.persistence.save(
            macDeviceId: "mac-test",
            registeredDevices: [
                LocalRegisteredDevice(
                    deviceId: "android-test",
                    platform: "android",
                    displayName: "Phone",
                    deviceToken: "token-1",
                    lastSeenAt: 100,
                    relayState: .active
                ),
            ],
            recentNotifications: []
        )

        let cleared = try await fixture.persistence.clear(defaultMacDeviceId: "mac-reset")
        let loaded = try await fixture.persistence.load(defaultMacDeviceId: "fallback-mac")

        #expect(cleared.macDeviceId == "mac-reset")
        #expect(cleared.registeredDevices.isEmpty)
        #expect(loaded.schemaVersion == cleared.schemaVersion)
        #expect(loaded.macDeviceId == cleared.macDeviceId)
        #expect(loaded.registeredDevices.isEmpty)
        #expect(loaded.recentNotifications.isEmpty)
    }

    @Test
    func testStoredStateUsesCurrentSchema() throws {
        let fixture = try PersistenceFixture()
        defer { fixture.cleanup() }

        let state = fixture.persistence.storedState(
            macDeviceId: "mac-test",
            registeredDevices: [],
            recentNotifications: []
        )

        #expect(state.schemaVersion == 1)
        #expect(state.macDeviceId == "mac-test")
    }
}

private struct PersistenceFixture {
    let directoryURL: URL
    let persistence: LocalServerStatePersistence

    init() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalServerStatePersistenceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let stateURL = directoryURL.appendingPathComponent("state.json", isDirectory: false)
        persistence = LocalServerStatePersistence(stateStore: MacStateStore(fileURL: stateURL))
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}
