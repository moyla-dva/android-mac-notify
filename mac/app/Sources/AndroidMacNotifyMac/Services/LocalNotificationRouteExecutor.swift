import Foundation

struct LocalNotificationRouteExecutor: Sendable {
    private let handler: LocalNotificationHandler

    init(handler: LocalNotificationHandler) {
        self.handler = handler
    }

    func handleEvent(
        _ request: HTTPRequest,
        routingState: inout LocalServerRoutingState,
        runtime: LocalServerRuntime
    ) throws -> LocalServerRouteExecution {
        try LocalServerRouteExecution.decoded(
            request: request,
            as: NotificationEventPayload.self,
            runtime: runtime
        ) { payload in
            let receiverState = routingState.sessionStore.receiverState
            let now = runtime.nowMillis()
            return try routingState.mutateRouteStores { _, deviceRegistry, notificationIngestStore, _ in
                try handler.handleEvent(
                    payload: payload,
                    headers: request.headers,
                    registry: &deviceRegistry,
                    ingestStore: &notificationIngestStore,
                    receiverState: receiverState,
                    now: now
                )
            }
        }
    }
}
