import Foundation

struct LocalDiscoveryRouteExecutor: Sendable {
    private let handler: LocalDiscoveryHandler

    init(handler: LocalDiscoveryHandler) {
        self.handler = handler
    }

    func handleDiscovery(
        endpoint: LocalServerEndpoint?,
        routingState: LocalServerRoutingState,
        macDisplayName: String,
        runtime: LocalServerRuntime
    ) throws -> LocalServerRouteExecution {
        let response = try handler.handleDiscovery(
            endpoint: endpoint,
            macDeviceId: routingState.macDeviceId,
            macDisplayName: macDisplayName,
            now: runtime.nowMillis()
        )
        return LocalServerRouteExecution(response: response)
    }
}
