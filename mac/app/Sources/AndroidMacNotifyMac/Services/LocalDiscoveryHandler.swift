import Foundation

struct LocalDiscoveryHandler: Sendable {
    let protocolVersion: Int
    let serviceType: String
    let defaultPort: Int

    init(protocolVersion: Int, serviceType: String, defaultPort: Int = 38471) {
        self.protocolVersion = protocolVersion
        self.serviceType = serviceType
        self.defaultPort = defaultPort
    }

    func handleDiscovery(
        endpoint: LocalServerEndpoint?,
        macDeviceId: String,
        macDisplayName: String,
        now: Int64
    ) throws -> HTTPResponse {
        let response = DiscoveryResponse(
            protocolVersion: protocolVersion,
            serviceType: serviceType,
            macDeviceId: macDeviceId,
            macDisplayName: macDisplayName,
            port: endpoint?.port ?? defaultPort,
            serverTime: now
        )
        return try .json(response, statusCode: 200, reasonPhrase: "OK")
    }
}
