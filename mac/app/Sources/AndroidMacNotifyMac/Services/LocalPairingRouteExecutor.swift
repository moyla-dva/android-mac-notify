import Foundation

struct LocalPairingRouteExecutor: Sendable {
    private let handler: LocalPairingHandler

    init(handler: LocalPairingHandler) {
        self.handler = handler
    }

    func handleApprovalRequest(
        _ request: HTTPRequest,
        routingState: inout LocalServerRoutingState,
        macDisplayName: String,
        runtime: LocalServerRuntime
    ) throws -> LocalServerRouteExecution {
        let macDeviceId = routingState.macDeviceId
        let now = runtime.nowMillis()
        return try LocalServerRouteExecution.decoded(
            request: request,
            as: PairApprovalRequestPayload.self,
            runtime: runtime
        ) { payload in
            try handler.handleApprovalRequest(
                payload: payload,
                approvalStore: &routingState.pairingApprovalStore,
                macDeviceId: macDeviceId,
                macDisplayName: macDisplayName,
                now: now,
                requestIdFactory: { runtime.generateToken(prefix: "pair_req") }
            )
        }
    }

    func handleApprovalStatus(
        _ request: HTTPRequest,
        routingState: inout LocalServerRoutingState,
        macDisplayName: String,
        runtime: LocalServerRuntime
    ) throws -> LocalServerRouteExecution {
        let result = try handler.handleApprovalStatus(
            requestId: request.queryItems["requestId"],
            deviceId: request.queryItems["deviceId"],
            approvalStore: &routingState.pairingApprovalStore,
            macDeviceId: routingState.macDeviceId,
            macDisplayName: macDisplayName,
            now: runtime.nowMillis()
        )
        return LocalServerRouteExecution(result: result)
    }

    func handleRegister(
        _ request: HTTPRequest,
        routingState: inout LocalServerRoutingState,
        macDisplayName: String,
        runtime: LocalServerRuntime
    ) throws -> LocalServerRouteExecution {
        try LocalServerRouteExecution.decoded(
            request: request,
            as: PairRegisterRequest.self,
            runtime: runtime
        ) { pairRequest in
            let macDeviceId = routingState.macDeviceId
            let now = runtime.nowMillis()
            return try routingState.mutateRouteStores { pairingTokenManager, deviceRegistry, _, _ in
                try handler.handleRegister(
                    pairRequest: pairRequest,
                    pairingTokenManager: &pairingTokenManager,
                    deviceRegistry: &deviceRegistry,
                    macDeviceId: macDeviceId,
                    macDisplayName: macDisplayName,
                    now: now,
                    deviceTokenFactory: { runtime.generateToken(prefix: "dev") },
                    pairingTokenFactory: { runtime.generateToken(prefix: "pair") }
                )
            }
        }
    }

    func approvePairingRequest(
        requestId: String,
        routingState: inout LocalServerRoutingState,
        macDisplayName: String,
        runtime: LocalServerRuntime
    ) -> LocalPairingActionResult {
        let macDeviceId = routingState.macDeviceId
        let now = runtime.nowMillis()
        return routingState.mutateRouteStores { _, deviceRegistry, _, pairingApprovalStore in
            handler.approveRequest(
                requestId: requestId,
                approvalStore: &pairingApprovalStore,
                deviceRegistry: &deviceRegistry,
                macDeviceId: macDeviceId,
                macDisplayName: macDisplayName,
                now: now,
                deviceTokenFactory: { runtime.generateToken(prefix: "dev") }
            )
        }
    }

    func rejectPairingRequest(
        requestId: String,
        routingState: inout LocalServerRoutingState,
        runtime: LocalServerRuntime
    ) -> LocalPairingActionResult {
        handler.rejectRequest(
            requestId: requestId,
            approvalStore: &routingState.pairingApprovalStore,
            now: runtime.nowMillis()
        )
    }
}
