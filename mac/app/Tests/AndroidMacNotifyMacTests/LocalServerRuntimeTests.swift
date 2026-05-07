import Foundation
import Testing
@testable import AndroidMacNotifyMac

struct LocalServerRuntimeTests {
    private struct TestPayload: Codable, Equatable {
        let value: String
    }

    @Test
    func testGenerateMacDeviceIdUsesStablePrefixAndHexSuffix() {
        let deviceId = LocalServerRuntime.generateMacDeviceId()

        #expect(deviceId.hasPrefix("mac-"))
        #expect(deviceId.dropFirst(4).count == 32)
        #expect(deviceId.dropFirst(4).allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    @Test
    func testGenerateTokenUsesPrefixAndHexSuffix() {
        let token = LocalServerRuntime().generateToken(prefix: "pair")

        #expect(token.hasPrefix("pair_"))
        #expect(token.dropFirst(5).count == 32)
        #expect(token.dropFirst(5).allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    @Test
    func testDecodeBodyUsesJSONDecoder() throws {
        let data = try JSONEncoder().encode(TestPayload(value: "ok"))

        let decoded = try LocalServerRuntime().decodeBody(TestPayload.self, from: data)

        #expect(decoded == TestPayload(value: "ok"))
    }
}
