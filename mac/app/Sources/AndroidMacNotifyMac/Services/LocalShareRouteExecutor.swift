import Foundation
import Network

struct LocalShareRouteExecutor: Sendable {
    private let handler: LocalShareHandler

    init(handler: LocalShareHandler) {
        self.handler = handler
    }

    func handleText(
        _ request: HTTPRequest,
        routingState: inout LocalServerRoutingState,
        runtime: LocalServerRuntime
    ) throws -> LocalServerRouteExecution {
        try LocalServerRouteExecution.decoded(
            request: request,
            as: ShareTextRequest.self,
            runtime: runtime
        ) { payload in
            let receiverState = routingState.sessionStore.receiverState
            return try handler.handleText(
                headers: request.headers,
                payload: payload,
                registry: &routingState.sessionStore.deviceRegistry,
                receiverState: receiverState,
                now: runtime.nowMillis()
            )
        }
    }

    func prepareStreamedFile(
        head: HTTPRequestHead,
        routingState: inout LocalServerRoutingState,
        runtime: LocalServerRuntime
    ) throws -> LocalStreamedSharePreparation {
        let receiverState = routingState.sessionStore.receiverState
        return try handler.prepareStreamedFile(
            head: head,
            registry: &routingState.sessionStore.deviceRegistry,
            receiverState: receiverState,
            now: runtime.nowMillis()
        )
    }

    func receiveStreamedFile(
        metadata: StreamedShareFileMetadata,
        head: HTTPRequestHead,
        connection: NWConnection,
        directoryURL: URL?,
        progressEventSink: (@Sendable (LocalServerEvent) -> Void)?
    ) async throws -> LocalServerRouteExecution {
        let result = try await handler.receiveStreamedFile(
            metadata: metadata,
            head: head,
            connection: connection,
            directoryURL: directoryURL,
            progressEventSink: progressEventSink
        )
        return LocalServerRouteExecution(result: result)
    }
}
