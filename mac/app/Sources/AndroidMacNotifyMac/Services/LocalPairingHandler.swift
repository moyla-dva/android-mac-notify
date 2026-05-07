import Foundation

struct LocalPairingRouteResult: Sendable {
    let response: HTTPResponse
    let shouldPersist: Bool
    let events: [LocalServerEvent]
    let didRotatePairingToken: Bool
}

struct LocalPairingActionResult: Sendable {
    let request: PairingApprovalRequest?
    let shouldPersist: Bool
    let events: [LocalServerEvent]
}

struct LocalPairingHandler: Sendable {
    let approvalLifetimeMillis: Int64
    let retainedTerminalRecordMillis: Int64
    let approvalPollAfterMillis: Int

    func handleApprovalRequest(
        payload: PairApprovalRequestPayload,
        approvalStore: inout LocalPairingApprovalStore,
        macDeviceId: String,
        macDisplayName: String,
        now: Int64,
        requestIdFactory: () -> String
    ) throws -> LocalPairingRouteResult {
        var events = expiredApprovalEvents(
            approvalStore.prune(at: now, retainedTerminalRecordMillis: retainedTerminalRecordMillis)
        )

        if let existing = approvalStore.pendingRecord(forDeviceId: payload.device.deviceId) {
            return try LocalPairingRouteResult(
                response: .json(
                    startResponse(
                        request: existing.request,
                        macDeviceId: macDeviceId,
                        macDisplayName: macDisplayName,
                        serverTime: now
                    ),
                    statusCode: 202,
                    reasonPhrase: "Accepted"
                ),
                shouldPersist: false,
                events: events,
                didRotatePairingToken: false
            )
        }

        let approvalRequest = approvalStore.createPending(
            requestId: requestIdFactory(),
            device: payload.device,
            requestedAt: now,
            expiresAt: now + approvalLifetimeMillis
        )
        events.append(.pairingApprovalRequested(approvalRequest))

        return try LocalPairingRouteResult(
            response: .json(
                startResponse(
                    request: approvalRequest,
                    macDeviceId: macDeviceId,
                    macDisplayName: macDisplayName,
                    serverTime: now
                ),
                statusCode: 202,
                reasonPhrase: "Accepted"
            ),
            shouldPersist: false,
            events: events,
            didRotatePairingToken: false
        )
    }

    func handleApprovalStatus(
        requestId: String?,
        deviceId: String?,
        approvalStore: inout LocalPairingApprovalStore,
        macDeviceId: String,
        macDisplayName: String,
        now: Int64
    ) throws -> LocalPairingRouteResult {
        let events = expiredApprovalEvents(
            approvalStore.prune(at: now, retainedTerminalRecordMillis: retainedTerminalRecordMillis)
        )

        guard let requestId, let deviceId, !requestId.isEmpty, !deviceId.isEmpty else {
            return LocalPairingRouteResult(
                response: invalidPairStatusRequest(),
                shouldPersist: false,
                events: events,
                didRotatePairingToken: false
            )
        }

        guard let record = approvalStore.record(for: requestId) else {
            return LocalPairingRouteResult(
                response: pairRequestNotFound(),
                shouldPersist: false,
                events: events,
                didRotatePairingToken: false
            )
        }

        guard record.request.device.deviceId == deviceId else {
            return LocalPairingRouteResult(
                response: pairRequestDeviceMismatch(),
                shouldPersist: false,
                events: events,
                didRotatePairingToken: false
            )
        }

        let response = PairApprovalStatusResponse(
            requestId: requestId,
            status: record.request.status,
            macDeviceId: macDeviceId,
            macDisplayName: macDisplayName,
            serverTime: now,
            message: LocalPairingApprovalStore.message(for: record.request.status),
            registration: record.registration
        )
        return try LocalPairingRouteResult(
            response: .json(response, statusCode: 200, reasonPhrase: "OK"),
            shouldPersist: false,
            events: events,
            didRotatePairingToken: false
        )
    }

    func handleRegister(
        pairRequest: PairRegisterRequest,
        pairingTokenManager: inout LocalPairingTokenManager,
        deviceRegistry: inout LocalDeviceRegistry,
        macDeviceId: String,
        macDisplayName: String,
        now: Int64,
        deviceTokenFactory: () -> String,
        pairingTokenFactory: @Sendable () -> String
    ) throws -> LocalPairingRouteResult {
        guard pairingTokenManager.isValid(pairRequest.pairingToken, at: now) else {
            return LocalPairingRouteResult(
                response: invalidPairingToken(),
                shouldPersist: false,
                events: [],
                didRotatePairingToken: false
            )
        }

        let registeredDevice = deviceRegistry.register(
            pairRequest.device,
            at: now,
            reuseExistingToken: true,
            tokenFactory: deviceTokenFactory
        )
        _ = pairingTokenManager.rotate(at: now, tokenFactory: pairingTokenFactory)

        let response = PairRegisterResponse(
            deviceToken: registeredDevice.deviceToken,
            macDeviceId: macDeviceId,
            macDisplayName: macDisplayName,
            serverTime: now
        )
        return try LocalPairingRouteResult(
            response: .json(response, statusCode: 200, reasonPhrase: "OK"),
            shouldPersist: true,
            events: [.deviceRegistered(registeredDevice)],
            didRotatePairingToken: true
        )
    }

    func approveRequest(
        requestId: String,
        approvalStore: inout LocalPairingApprovalStore,
        deviceRegistry: inout LocalDeviceRegistry,
        macDeviceId: String,
        macDisplayName: String,
        now: Int64,
        deviceTokenFactory: () -> String
    ) -> LocalPairingActionResult {
        var events = expiredApprovalEvents(
            approvalStore.prune(at: now, retainedTerminalRecordMillis: retainedTerminalRecordMillis)
        )

        guard let record = approvalStore.pendingRecord(forRequestId: requestId) else {
            return LocalPairingActionResult(request: nil, shouldPersist: false, events: events)
        }

        let registeredDevice = deviceRegistry.register(
            record.request.device,
            at: now,
            tokenFactory: deviceTokenFactory
        )
        let registration = PairRegisterResponse(
            deviceToken: registeredDevice.deviceToken,
            macDeviceId: macDeviceId,
            macDisplayName: macDisplayName,
            serverTime: now
        )

        guard let approvedRecord = approvalStore.approve(requestId: requestId, registration: registration) else {
            return LocalPairingActionResult(request: nil, shouldPersist: false, events: events)
        }

        events.append(.pairingApprovalUpdated(approvedRecord.request))
        events.append(.deviceRegistered(registeredDevice))
        return LocalPairingActionResult(
            request: approvedRecord.request,
            shouldPersist: true,
            events: events
        )
    }

    func rejectRequest(
        requestId: String,
        approvalStore: inout LocalPairingApprovalStore,
        now: Int64
    ) -> LocalPairingActionResult {
        var events = expiredApprovalEvents(
            approvalStore.prune(at: now, retainedTerminalRecordMillis: retainedTerminalRecordMillis)
        )

        guard let rejectedRecord = approvalStore.reject(requestId: requestId) else {
            return LocalPairingActionResult(request: nil, shouldPersist: false, events: events)
        }

        events.append(.pairingApprovalUpdated(rejectedRecord.request))
        return LocalPairingActionResult(
            request: rejectedRecord.request,
            shouldPersist: false,
            events: events
        )
    }

    private func startResponse(
        request: PairingApprovalRequest,
        macDeviceId: String,
        macDisplayName: String,
        serverTime: Int64
    ) -> PairApprovalStartResponse {
        PairApprovalStartResponse(
            requestId: request.requestId,
            status: request.status,
            macDeviceId: macDeviceId,
            macDisplayName: macDisplayName,
            expiresAt: request.expiresAt,
            serverTime: serverTime,
            pollAfterMillis: approvalPollAfterMillis
        )
    }

    private func expiredApprovalEvents(_ requests: [PairingApprovalRequest]) -> [LocalServerEvent] {
        requests.map(LocalServerEvent.pairingApprovalUpdated)
    }

    private func invalidPairStatusRequest() -> HTTPResponse {
        .error(
            statusCode: 400,
            reasonPhrase: "Bad Request",
            code: "INVALID_REQUEST",
            message: "requestId and deviceId are required.",
            retryable: false
        )
    }

    private func pairRequestNotFound() -> HTTPResponse {
        .error(
            statusCode: 404,
            reasonPhrase: "Not Found",
            code: "PAIR_REQUEST_NOT_FOUND",
            message: "Pairing request was not found or has expired.",
            retryable: false
        )
    }

    private func pairRequestDeviceMismatch() -> HTTPResponse {
        .error(
            statusCode: 403,
            reasonPhrase: "Forbidden",
            code: "PAIR_REQUEST_DEVICE_MISMATCH",
            message: "Pairing request does not belong to this device.",
            retryable: false
        )
    }

    private func invalidPairingToken() -> HTTPResponse {
        .error(
            statusCode: 401,
            reasonPhrase: "Unauthorized",
            code: "INVALID_PAIRING_TOKEN",
            message: "Pairing token is invalid or expired.",
            retryable: false
        )
    }
}
