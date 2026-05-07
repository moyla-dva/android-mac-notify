import Foundation
import Testing
@testable import AndroidMacNotifyMac

struct LocalServerPersistenceControllerTests {
    @Test
    func testLoadIfNeededLoadsOnlyOnce() async throws {
        let fixture = try PersistenceControllerFixture()
        defer { fixture.cleanup() }
        let controller = LocalServerPersistenceController(stateStore: fixture.stateStore)

        try await controller.save(
            LocalServerPersistenceSnapshot(
                macDeviceId: "mac-first",
                registeredDevices: [],
                recentNotifications: []
            )
        )

        let firstLoad = try await controller.loadIfNeeded(defaultMacDeviceId: "fallback")
        try await controller.save(
            LocalServerPersistenceSnapshot(
                macDeviceId: "mac-second",
                registeredDevices: [],
                recentNotifications: []
            )
        )
        let secondLoad = try await controller.loadIfNeeded(defaultMacDeviceId: "fallback")

        #expect(firstLoad?.macDeviceId == "mac-first")
        #expect(secondLoad == nil)
    }

    @Test
    func testSaveIfNeededHonorsFinalizationPolicy() async throws {
        let fixture = try PersistenceControllerFixture()
        defer { fixture.cleanup() }
        let controller = LocalServerPersistenceController(stateStore: fixture.stateStore)

        try await controller.saveIfNeeded(
            LocalServerPersistenceSnapshot(
                macDeviceId: "mac-skipped",
                registeredDevices: [],
                recentNotifications: []
            ),
            for: LocalRouteFinalization(shouldPersist: false)
        )
        let skipped = try await fixture.persistence.load(defaultMacDeviceId: "fallback")

        try await controller.saveIfNeeded(
            LocalServerPersistenceSnapshot(
                macDeviceId: "mac-saved",
                registeredDevices: [],
                recentNotifications: []
            ),
            for: LocalRouteFinalization(shouldPersist: true)
        )
        let saved = try await fixture.persistence.load(defaultMacDeviceId: "fallback")

        #expect(skipped.macDeviceId == "fallback")
        #expect(saved.macDeviceId == "mac-saved")
    }
}

private struct PersistenceControllerFixture {
    let directoryURL: URL
    let stateStore: MacStateStore
    let persistence: LocalServerStatePersistence

    init() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalServerPersistenceControllerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        stateStore = MacStateStore(fileURL: directoryURL.appendingPathComponent("state.json", isDirectory: false))
        persistence = LocalServerStatePersistence(stateStore: stateStore)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}
