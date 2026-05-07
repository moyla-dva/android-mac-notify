import Foundation

struct LocalSessionRouteResult: Sendable {
    let response: HTTPResponse
    let shouldPersist: Bool
    let event: LocalServerEvent?
}

struct LocalSessionHandler: Sendable {
    private let deviceAuthenticator: LocalDeviceAuthenticator

    init(deviceAuthenticator: LocalDeviceAuthenticator = LocalDeviceAuthenticator()) {
        self.deviceAuthenticator = deviceAuthenticator
    }

    func handleHeartbeat(
        headers: [String: String],
        payload: HeartbeatRequest,
        registry: inout LocalDeviceRegistry,
        receiverState: RelayState,
        now: Int64
    ) throws -> LocalSessionRouteResult {
        _ = try deviceAuthenticator.requireAuthenticatedDeviceId(
            headers: headers,
            suppliedDeviceId: payload.deviceId,
            registry: registry
        )

        registry.updateLastSeen(for: payload.deviceId, at: now, relayState: .active)
        let response = HeartbeatResponse(
            ok: true,
            serverTime: now,
            sessionState: registry.sessionState(for: payload.deviceId, receiverState: receiverState, now: now)
        )

        return try LocalSessionRouteResult(
            response: .json(response, statusCode: 200, reasonPhrase: "OK"),
            shouldPersist: true,
            event: .heartbeat(deviceId: payload.deviceId, at: now)
        )
    }

    func handleRelayStateUpdate(
        headers: [String: String],
        payload: RelayStateRequest,
        registry: inout LocalDeviceRegistry,
        receiverState: RelayState,
        now: Int64
    ) throws -> LocalSessionRouteResult {
        _ = try deviceAuthenticator.requireAuthenticatedDeviceId(
            headers: headers,
            suppliedDeviceId: payload.deviceId,
            registry: registry
        )

        guard let device = registry.updateLastSeen(for: payload.deviceId, at: now, relayState: payload.relayState) else {
            return LocalSessionRouteResult(
                response: LocalHTTPErrorResponses.deviceNotRegistered(),
                shouldPersist: false,
                event: nil
            )
        }

        let response = RelayStateResponse(
            ok: true,
            serverTime: now,
            sessionState: registry.sessionState(for: payload.deviceId, receiverState: receiverState, now: now)
        )
        return try LocalSessionRouteResult(
            response: .json(response, statusCode: 200, reasonPhrase: "OK"),
            shouldPersist: true,
            event: .deviceSessionUpdated(device)
        )
    }

    func handleSessionForget(
        headers: [String: String],
        payload: SessionForgetRequest,
        registry: inout LocalDeviceRegistry,
        now: Int64
    ) throws -> LocalSessionRouteResult {
        _ = try deviceAuthenticator.requireAuthenticatedDeviceId(
            headers: headers,
            suppliedDeviceId: payload.deviceId,
            registry: registry
        )

        guard registry.removeDevice(deviceId: payload.deviceId) != nil else {
            return LocalSessionRouteResult(
                response: LocalHTTPErrorResponses.deviceNotRegistered(),
                shouldPersist: false,
                event: nil
            )
        }

        let response = SessionForgetResponse(
            ok: true,
            serverTime: now,
            sessionState: "unpaired"
        )
        return try LocalSessionRouteResult(
            response: .json(response, statusCode: 200, reasonPhrase: "OK"),
            shouldPersist: true,
            event: .deviceUnregistered(deviceId: payload.deviceId)
        )
    }

    func handleSessionStatus(
        headers: [String: String],
        requestedDeviceId: String,
        registry: LocalDeviceRegistry,
        receiverState: RelayState,
        now: Int64,
        macDeviceId: String,
        macDisplayName: String
    ) throws -> LocalSessionRouteResult {
        _ = try deviceAuthenticator.requireAuthenticatedDeviceId(
            headers: headers,
            suppliedDeviceId: requestedDeviceId,
            registry: registry,
            mismatchMessage: "Device token does not match the requested device ID."
        )
        let device = try deviceAuthenticator.requireRegisteredDevice(requestedDeviceId, registry: registry)

        let response = SessionStatusResponse(
            deviceId: device.deviceId,
            sessionState: registry.sessionState(for: device.deviceId, receiverState: receiverState, now: now),
            lastSeenAt: device.lastSeenAt,
            macDeviceId: macDeviceId,
            macDisplayName: macDisplayName
        )
        return try LocalSessionRouteResult(
            response: .json(response, statusCode: 200, reasonPhrase: "OK"),
            shouldPersist: false,
            event: nil
        )
    }
}
