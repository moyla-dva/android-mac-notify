import Foundation

struct LocalSessionRouteExecutor: Sendable {
    private let handler: LocalSessionHandler

    init(handler: LocalSessionHandler) {
        self.handler = handler
    }

    func handleHeartbeat(
        _ request: HTTPRequest,
        routingState: inout LocalServerRoutingState,
        runtime: LocalServerRuntime
    ) throws -> LocalServerRouteExecution {
        try LocalServerRouteExecution.decoded(
            request: request,
            as: HeartbeatRequest.self,
            runtime: runtime
        ) { payload in
            let receiverState = routingState.sessionStore.receiverState
            return try handler.handleHeartbeat(
                headers: request.headers,
                payload: payload,
                registry: &routingState.sessionStore.deviceRegistry,
                receiverState: receiverState,
                now: runtime.nowMillis()
            )
        }
    }

    func handleRelayStateUpdate(
        _ request: HTTPRequest,
        routingState: inout LocalServerRoutingState,
        runtime: LocalServerRuntime
    ) throws -> LocalServerRouteExecution {
        try LocalServerRouteExecution.decoded(
            request: request,
            as: RelayStateRequest.self,
            runtime: runtime
        ) { payload in
            let receiverState = routingState.sessionStore.receiverState
            return try handler.handleRelayStateUpdate(
                headers: request.headers,
                payload: payload,
                registry: &routingState.sessionStore.deviceRegistry,
                receiverState: receiverState,
                now: runtime.nowMillis()
            )
        }
    }

    func handleSessionForget(
        _ request: HTTPRequest,
        routingState: inout LocalServerRoutingState,
        runtime: LocalServerRuntime
    ) throws -> LocalServerRouteExecution {
        try LocalServerRouteExecution.decoded(
            request: request,
            as: SessionForgetRequest.self,
            runtime: runtime
        ) { payload in
            try handler.handleSessionForget(
                headers: request.headers,
                payload: payload,
                registry: &routingState.sessionStore.deviceRegistry,
                now: runtime.nowMillis()
            )
        }
    }

    func handleSessionStatus(
        _ request: HTTPRequest,
        routingState: LocalServerRoutingState,
        macDisplayName: String,
        runtime: LocalServerRuntime
    ) throws -> LocalServerRouteExecution {
        let requestedDeviceId = request.queryItems["deviceId"] ?? ""
        let result = try handler.handleSessionStatus(
            headers: request.headers,
            requestedDeviceId: requestedDeviceId,
            registry: routingState.sessionStore.deviceRegistry,
            receiverState: routingState.sessionStore.receiverState,
            now: runtime.nowMillis(),
            macDeviceId: routingState.macDeviceId,
            macDisplayName: macDisplayName
        )
        return LocalServerRouteExecution(result: result)
    }
}
