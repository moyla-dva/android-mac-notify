import Foundation

struct LocalNotificationRouteResult: Sendable {
    let response: HTTPResponse
    let shouldPersist: Bool
    let event: LocalServerEvent?
}

struct LocalNotificationHandler: Sendable {
    private let deviceAuthenticator = LocalDeviceAuthenticator()
    private let receiverGate = LocalRelayReceiverGate()

    func handleEvent(
        payload: NotificationEventPayload,
        headers: [String: String],
        registry: inout LocalDeviceRegistry,
        ingestStore: inout LocalNotificationIngestStore,
        receiverState: RelayState,
        now: Int64
    ) throws -> LocalNotificationRouteResult {
        _ = try deviceAuthenticator.requireAuthenticatedDeviceId(
            headers: headers,
            suppliedDeviceId: payload.deviceId,
            registry: registry
        )

        if let pausedResponse = receiverGate.prepareInboundRelay(
            deviceId: payload.deviceId,
            registry: &registry,
            receiverState: receiverState,
            at: now
        ) {
            return LocalNotificationRouteResult(
                response: pausedResponse,
                shouldPersist: true,
                event: nil
            )
        }

        let ingestResult = ingestStore.ingest(payload: payload, receivedAt: now)
        let event = ingestResult.acceptedSummary.map(LocalServerEvent.notificationAccepted)
        return try LocalNotificationRouteResult(
            response: .json(ingestResult.response, statusCode: 202, reasonPhrase: "Accepted"),
            shouldPersist: true,
            event: event
        )
    }
}
