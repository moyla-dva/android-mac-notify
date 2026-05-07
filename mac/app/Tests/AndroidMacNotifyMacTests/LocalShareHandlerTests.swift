import Foundation
import Testing
@testable import AndroidMacNotifyMac

struct LocalShareHandlerTests {
    @Test
    func testTextShareUpdatesLastSeenAndEmitsSharedTextWithoutPersistence() throws {
        let handler = LocalShareHandler()
        var registry = shareRegistry()

        let result = try handler.handleText(
            headers: shareHeaders(),
            payload: ShareTextRequest(deviceId: "android-test", shareId: "share-text", text: "hello", sharedAt: 100),
            registry: &registry,
            receiverState: .active,
            now: 500
        )
        let response = try decodeShareResponse(ShareTextAcceptedResponse.self, from: result.response)

        #expect(response.accepted)
        #expect(response.shareId == "share-text")
        #expect(!result.shouldPersist)
        #expect(registry.device(withId: "android-test")?.lastSeenAt == 500)
        #expect(result.event?.sharedTextValue == "hello")
    }

    @Test
    func testTextSharePausedUpdatesLastSeenAndRequestsPersistence() throws {
        let handler = LocalShareHandler()
        var registry = shareRegistry()

        let result = try handler.handleText(
            headers: shareHeaders(),
            payload: ShareTextRequest(deviceId: "android-test", shareId: "share-text", text: "hello", sharedAt: 100),
            registry: &registry,
            receiverState: .paused,
            now: 500
        )

        #expect(result.response.statusCode == 409)
        #expect(result.shouldPersist)
        #expect(result.event == nil)
        #expect(registry.device(withId: "android-test")?.lastSeenAt == 500)
    }

}

private func shareRegistry() -> LocalDeviceRegistry {
    var registry = LocalDeviceRegistry()
    _ = registry.register(
        DeviceIdentity(deviceId: "android-test", platform: "android", displayName: "Phone"),
        at: 100,
        tokenFactory: { "token-1" }
    )
    return registry
}

private func shareHeaders() -> [String: String] {
    ["authorization": "Bearer token-1"]
}

private func decodeShareResponse<Value: Decodable>(_ type: Value.Type, from response: HTTPResponse) throws -> Value {
    try JSONDecoder().decode(Value.self, from: response.body)
}

private extension LocalServerEvent {
    var sharedTextValue: String? {
        if case let .sharedText(_, text, _) = self {
            return text
        }
        return nil
    }

}
