import Foundation
import Network

struct LocalServerRouteExecutor: Sendable {
    private let routeDispatcher: LocalHTTPRouteDispatcher
    private let pairingRoutes: LocalPairingRouteExecutor
    private let notificationRoutes: LocalNotificationRouteExecutor
    private let sessionRoutes: LocalSessionRouteExecutor
    private let discoveryRoutes: LocalDiscoveryRouteExecutor
    private let shareRoutes: LocalShareRouteExecutor

    init(handlers: LocalServerRouteHandlers) {
        routeDispatcher = handlers.routeDispatcher
        pairingRoutes = LocalPairingRouteExecutor(handler: handlers.pairing)
        notificationRoutes = LocalNotificationRouteExecutor(handler: handlers.notification)
        sessionRoutes = LocalSessionRouteExecutor(handler: handlers.session)
        discoveryRoutes = LocalDiscoveryRouteExecutor(handler: handlers.discovery)
        shareRoutes = LocalShareRouteExecutor(handler: handlers.share)
    }

    func route(
        request: HTTPRequest,
        routingState: inout LocalServerRoutingState,
        endpoint: LocalServerEndpoint?,
        macDisplayName: String,
        runtime: LocalServerRuntime
    ) throws -> LocalServerRouteExecution {
        switch routeDispatcher.route(for: request) {
        case .pairApprovalRequest:
            return try pairingRoutes.handleApprovalRequest(
                request,
                routingState: &routingState,
                macDisplayName: macDisplayName,
                runtime: runtime
            )
        case .pairApprovalStatus:
            return try pairingRoutes.handleApprovalStatus(
                request,
                routingState: &routingState,
                macDisplayName: macDisplayName,
                runtime: runtime
            )
        case .pairRegister:
            return try pairingRoutes.handleRegister(
                request,
                routingState: &routingState,
                macDisplayName: macDisplayName,
                runtime: runtime
            )
        case .notificationEvent:
            return try notificationRoutes.handleEvent(
                request,
                routingState: &routingState,
                runtime: runtime
            )
        case .heartbeat:
            return try sessionRoutes.handleHeartbeat(
                request,
                routingState: &routingState,
                runtime: runtime
            )
        case .relayState:
            return try sessionRoutes.handleRelayStateUpdate(
                request,
                routingState: &routingState,
                runtime: runtime
            )
        case .sessionForget:
            return try sessionRoutes.handleSessionForget(
                request,
                routingState: &routingState,
                runtime: runtime
            )
        case .sessionStatus:
            return try sessionRoutes.handleSessionStatus(
                request,
                routingState: routingState,
                macDisplayName: macDisplayName,
                runtime: runtime
            )
        case .discovery:
            return try discoveryRoutes.handleDiscovery(
                endpoint: endpoint,
                routingState: routingState,
                macDisplayName: macDisplayName,
                runtime: runtime
            )
        case .shareText:
            return try shareRoutes.handleText(
                request,
                routingState: &routingState,
                runtime: runtime
            )
        case .shareFile:
            return LocalServerRouteExecution(
                response: LocalHTTPErrorResponses.invalidRequest(
                    message: "File uploads require X-AMN-Upload-Mode: stream."
                )
            )
        case .notFound:
            return LocalServerRouteExecution(response: .notFound())
        }
    }

    func prepareStreamedShareFile(
        head: HTTPRequestHead,
        routingState: inout LocalServerRoutingState,
        runtime: LocalServerRuntime
    ) throws -> LocalStreamedSharePreparation {
        try shareRoutes.prepareStreamedFile(
            head: head,
            routingState: &routingState,
            runtime: runtime
        )
    }

    func receiveStreamedShareFile(
        metadata: StreamedShareFileMetadata,
        head: HTTPRequestHead,
        connection: NWConnection,
        directoryURL: URL?,
        progressEventSink: (@Sendable (LocalServerEvent) -> Void)?
    ) async throws -> LocalServerRouteExecution {
        try await shareRoutes.receiveStreamedFile(
            metadata: metadata,
            head: head,
            connection: connection,
            directoryURL: directoryURL,
            progressEventSink: progressEventSink
        )
    }

    func approvePairingRequest(
        requestId: String,
        routingState: inout LocalServerRoutingState,
        macDisplayName: String,
        runtime: LocalServerRuntime
    ) -> LocalPairingActionResult {
        pairingRoutes.approvePairingRequest(
            requestId: requestId,
            routingState: &routingState,
            macDisplayName: macDisplayName,
            runtime: runtime
        )
    }

    func rejectPairingRequest(
        requestId: String,
        routingState: inout LocalServerRoutingState,
        runtime: LocalServerRuntime
    ) -> LocalPairingActionResult {
        pairingRoutes.rejectPairingRequest(
            requestId: requestId,
            routingState: &routingState,
            runtime: runtime
        )
    }
}
