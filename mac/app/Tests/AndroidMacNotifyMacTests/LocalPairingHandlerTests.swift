import Foundation
import Testing
@testable import AndroidMacNotifyMac

struct LocalPairingHandlerTests {
    @Test
    func testApprovalRequestCreatesPendingThenReusesPendingForSameDevice() throws {
        let handler = testPairingHandler()
        var approvalStore = LocalPairingApprovalStore()

        let first = try handler.handleApprovalRequest(
            payload: PairApprovalRequestPayload(device: testPairingHandlerDevice()),
            approvalStore: &approvalStore,
            macDeviceId: "mac-test",
            macDisplayName: "Test Mac",
            now: 100,
            requestIdFactory: { "pair-1" }
        )
        let duplicate = try handler.handleApprovalRequest(
            payload: PairApprovalRequestPayload(device: testPairingHandlerDevice()),
            approvalStore: &approvalStore,
            macDeviceId: "mac-test",
            macDisplayName: "Test Mac",
            now: 120,
            requestIdFactory: { "pair-2" }
        )
        let firstResponse = try decodePairing(PairApprovalStartResponse.self, from: first.response)
        let duplicateResponse = try decodePairing(PairApprovalStartResponse.self, from: duplicate.response)

        #expect(first.response.statusCode == 202)
        #expect(firstResponse.requestId == "pair-1")
        #expect(first.events.first?.pairingRequestedId == "pair-1")
        #expect(duplicateResponse.requestId == "pair-1")
        #expect(duplicate.events.isEmpty)
    }

    @Test
    func testApprovalStatusReturnsApprovedRegistration() throws {
        let handler = testPairingHandler()
        var approvalStore = LocalPairingApprovalStore()
        _ = approvalStore.createPending(
            requestId: "pair-1",
            device: testPairingHandlerDevice(),
            requestedAt: 100,
            expiresAt: 1_000
        )
        let registration = PairRegisterResponse(
            deviceToken: "token-1",
            macDeviceId: "mac-test",
            macDisplayName: "Test Mac",
            serverTime: 200
        )
        _ = approvalStore.approve(requestId: "pair-1", registration: registration)

        let result = try handler.handleApprovalStatus(
            requestId: "pair-1",
            deviceId: "android-test",
            approvalStore: &approvalStore,
            macDeviceId: "mac-test",
            macDisplayName: "Test Mac",
            now: 300
        )
        let response = try decodePairing(PairApprovalStatusResponse.self, from: result.response)

        #expect(response.status == .approved)
        #expect(response.registration?.deviceToken == "token-1")
        #expect(!result.shouldPersist)
        #expect(result.events.isEmpty)
    }

    @Test
    func testRegisterRejectsInvalidPairingToken() throws {
        let handler = testPairingHandler()
        var tokenManager = LocalPairingTokenManager(lifetimeMillis: 100)
        _ = tokenManager.rotate(at: 100, tokenFactory: { "pair-good" })
        var registry = LocalDeviceRegistry()

        let result = try handler.handleRegister(
            pairRequest: PairRegisterRequest(pairingToken: "pair-bad", device: testPairingHandlerDevice()),
            pairingTokenManager: &tokenManager,
            deviceRegistry: &registry,
            macDeviceId: "mac-test",
            macDisplayName: "Test Mac",
            now: 120,
            deviceTokenFactory: { "device-token" },
            pairingTokenFactory: { "pair-next" }
        )

        #expect(result.response.statusCode == 401)
        #expect(!result.shouldPersist)
        #expect(!result.didRotatePairingToken)
        #expect(registry.count == 0)
    }

    @Test
    func testRegisterCreatesDeviceAndRotatesPairingToken() throws {
        let handler = testPairingHandler()
        var tokenManager = LocalPairingTokenManager(lifetimeMillis: 100)
        _ = tokenManager.rotate(at: 100, tokenFactory: { "pair-good" })
        var registry = LocalDeviceRegistry()

        let result = try handler.handleRegister(
            pairRequest: PairRegisterRequest(pairingToken: "pair-good", device: testPairingHandlerDevice()),
            pairingTokenManager: &tokenManager,
            deviceRegistry: &registry,
            macDeviceId: "mac-test",
            macDisplayName: "Test Mac",
            now: 120,
            deviceTokenFactory: { "device-token" },
            pairingTokenFactory: { "pair-next" }
        )
        let response = try decodePairing(PairRegisterResponse.self, from: result.response)

        #expect(result.shouldPersist)
        #expect(result.didRotatePairingToken)
        #expect(response.deviceToken == "device-token")
        #expect(tokenManager.currentToken == "pair-next")
        #expect(registry.device(withId: "android-test")?.deviceToken == "device-token")
        #expect(result.events.first?.registeredDeviceId == "android-test")
    }

    @Test
    func testApproveRequestRegistersDeviceAndStoresRegistration() {
        let handler = testPairingHandler()
        var approvalStore = LocalPairingApprovalStore()
        var registry = LocalDeviceRegistry()
        _ = approvalStore.createPending(
            requestId: "pair-1",
            device: testPairingHandlerDevice(),
            requestedAt: 100,
            expiresAt: 1_000
        )

        let result = handler.approveRequest(
            requestId: "pair-1",
            approvalStore: &approvalStore,
            deviceRegistry: &registry,
            macDeviceId: "mac-test",
            macDisplayName: "Test Mac",
            now: 200,
            deviceTokenFactory: { "device-token" }
        )

        #expect(result.request?.status == .approved)
        #expect(result.shouldPersist)
        #expect(approvalStore.record(for: "pair-1")?.registration?.deviceToken == "device-token")
        #expect(registry.device(withId: "android-test")?.deviceToken == "device-token")
        #expect(result.events.map(\.pairingUpdatedId).contains("pair-1"))
        #expect(result.events.map(\.registeredDeviceId).contains("android-test"))
    }

    @Test
    func testRejectRequestUpdatesApprovalWithoutPersistence() {
        let handler = testPairingHandler()
        var approvalStore = LocalPairingApprovalStore()
        _ = approvalStore.createPending(
            requestId: "pair-1",
            device: testPairingHandlerDevice(),
            requestedAt: 100,
            expiresAt: 1_000
        )

        let result = handler.rejectRequest(
            requestId: "pair-1",
            approvalStore: &approvalStore,
            now: 200
        )

        #expect(result.request?.status == .rejected)
        #expect(!result.shouldPersist)
        #expect(result.events.first?.pairingUpdatedId == "pair-1")
    }
}

private func testPairingHandler() -> LocalPairingHandler {
    LocalPairingHandler(
        approvalLifetimeMillis: 500,
        retainedTerminalRecordMillis: 500,
        approvalPollAfterMillis: 2_000
    )
}

private func testPairingHandlerDevice() -> DeviceIdentity {
    DeviceIdentity(deviceId: "android-test", platform: "android", displayName: "Android Test")
}

private func decodePairing<Value: Decodable>(_ type: Value.Type, from response: HTTPResponse) throws -> Value {
    try JSONDecoder().decode(Value.self, from: response.body)
}

private extension LocalServerEvent {
    var pairingRequestedId: String? {
        if case let .pairingApprovalRequested(request) = self {
            return request.requestId
        }
        return nil
    }

    var pairingUpdatedId: String? {
        if case let .pairingApprovalUpdated(request) = self {
            return request.requestId
        }
        return nil
    }

    var registeredDeviceId: String? {
        if case let .deviceRegistered(device) = self {
            return device.deviceId
        }
        return nil
    }
}
