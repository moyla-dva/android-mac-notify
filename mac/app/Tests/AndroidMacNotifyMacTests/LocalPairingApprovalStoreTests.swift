import Foundation
import Testing
@testable import AndroidMacNotifyMac

struct LocalPairingApprovalStoreTests {
    @Test
    func testCreatePendingAndReuseByDevice() {
        var store = LocalPairingApprovalStore()
        let request = store.createPending(
            requestId: "pair-1",
            device: testPairingDevice(),
            requestedAt: 100,
            expiresAt: 200
        )

        let pending = store.pendingRecord(forDeviceId: "android-test")

        #expect(request.status == .pending)
        #expect(pending?.request.requestId == "pair-1")
        #expect(store.pendingRecord(forDeviceId: "other") == nil)
    }

    @Test
    func testApproveAttachesRegistrationAndLeavesNonPendingUntouched() {
        var store = LocalPairingApprovalStore()
        _ = store.createPending(
            requestId: "pair-1",
            device: testPairingDevice(),
            requestedAt: 100,
            expiresAt: 200
        )

        let registration = PairRegisterResponse(
            deviceToken: "token-1",
            macDeviceId: "mac-test",
            macDisplayName: "Test Mac",
            serverTime: 150
        )
        let approved = store.approve(requestId: "pair-1", registration: registration)
        let secondApprove = store.approve(requestId: "pair-1", registration: registration)

        #expect(approved?.request.status == .approved)
        #expect(approved?.registration?.deviceToken == "token-1")
        #expect(secondApprove == nil)
    }

    @Test
    func testPruneExpiresPendingRecordsAndLaterDropsTerminalRecords() {
        var store = LocalPairingApprovalStore()
        _ = store.createPending(
            requestId: "pair-1",
            device: testPairingDevice(),
            requestedAt: 100,
            expiresAt: 200
        )

        let expired = store.prune(at: 250, retainedTerminalRecordMillis: 100)

        #expect(expired.map(\.requestId) == ["pair-1"])
        #expect(store.record(for: "pair-1")?.request.status == .expired)

        let expiredAgain = store.prune(at: 301, retainedTerminalRecordMillis: 100)

        #expect(expiredAgain.isEmpty)
        #expect(store.record(for: "pair-1") == nil)
    }

    @Test
    func testStatusMessagesMatchProtocolCopy() {
        #expect(LocalPairingApprovalStore.message(for: .pending) == "Waiting for approval on Mac.")
        #expect(LocalPairingApprovalStore.message(for: .approved) == "Pairing request was approved.")
        #expect(LocalPairingApprovalStore.message(for: .rejected) == "Pairing request was rejected on Mac.")
        #expect(LocalPairingApprovalStore.message(for: .expired) == "Pairing request expired.")
    }
}

private func testPairingDevice() -> DeviceIdentity {
    DeviceIdentity(deviceId: "android-test", platform: "android", displayName: "Android Test")
}
