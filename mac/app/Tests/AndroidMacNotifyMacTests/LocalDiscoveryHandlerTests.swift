import Foundation
import Testing
@testable import AndroidMacNotifyMac

struct LocalDiscoveryHandlerTests {
    @Test
    func testDiscoveryUsesActiveEndpoint() throws {
        let handler = LocalDiscoveryHandler(
            protocolVersion: 7,
            serviceType: "_test._tcp",
            defaultPort: 1111
        )

        let result = try handler.handleDiscovery(
            endpoint: LocalServerEndpoint(host: "192.168.1.8", port: 4567),
            macDeviceId: "mac-test",
            macDisplayName: "Test Mac",
            now: 123
        )
        let response = try decodeDiscovery(from: result)

        #expect(result.statusCode == 200)
        #expect(response.protocolVersion == 7)
        #expect(response.serviceType == "_test._tcp")
        #expect(response.macDeviceId == "mac-test")
        #expect(response.macDisplayName == "Test Mac")
        #expect(response.port == 4567)
        #expect(response.serverTime == 123)
    }

    @Test
    func testDiscoveryFallsBackToDefaultPortWithoutEndpoint() throws {
        let handler = LocalDiscoveryHandler(
            protocolVersion: 7,
            serviceType: "_test._tcp",
            defaultPort: 1111
        )

        let result = try handler.handleDiscovery(
            endpoint: nil,
            macDeviceId: "mac-test",
            macDisplayName: "Test Mac",
            now: 123
        )
        let response = try decodeDiscovery(from: result)

        #expect(response.port == 1111)
    }
}

private func decodeDiscovery(from response: HTTPResponse) throws -> DiscoveryResponse {
    try JSONDecoder().decode(DiscoveryResponse.self, from: response.body)
}
