import Foundation
import Testing
@testable import AndroidMacNotifyMac

struct LocalHTTPConnectionResponderTests {
    @Test
    func testResponseForExplicitHTTPRequestErrorPassesThroughResponse() throws {
        let responder = LocalHTTPConnectionResponder()
        let explicitResponse = LocalHTTPErrorResponses.receiverPaused()

        let response = try #require(
            responder.response(for: LocalHTTPRequestError.response(explicitResponse))
        )
        let envelope = try decodeResponderErrorEnvelope(from: response)

        #expect(response.statusCode == 409)
        #expect(envelope.error.code == "MAC_RECEIVER_PAUSED")
    }

    @Test
    func testResponseForPayloadTooLargeUses413() throws {
        let responder = LocalHTTPConnectionResponder()

        let response = try #require(
            responder.response(for: LocalServerError.payloadTooLarge)
        )
        let envelope = try decodeResponderErrorEnvelope(from: response)

        #expect(response.statusCode == 413)
        #expect(response.reasonPhrase == "Payload Too Large")
        #expect(envelope.error.code == "PAYLOAD_TOO_LARGE")
        #expect(envelope.error.retryable == false)
    }

    @Test
    func testResponseForGenericErrorUsesInvalidRequest() throws {
        let responder = LocalHTTPConnectionResponder()

        let response = try #require(
            responder.response(for: TestResponderError.badInput)
        )
        let envelope = try decodeResponderErrorEnvelope(from: response)

        #expect(response.statusCode == 400)
        #expect(response.reasonPhrase == "Bad Request")
        #expect(envelope.error.code == "INVALID_REQUEST")
    }
}

private enum TestResponderError: LocalizedError {
    case badInput

    var errorDescription: String? {
        "Bad input"
    }
}

private func decodeResponderErrorEnvelope(from response: HTTPResponse) throws -> ErrorEnvelope {
    try JSONDecoder().decode(ErrorEnvelope.self, from: response.body)
}
