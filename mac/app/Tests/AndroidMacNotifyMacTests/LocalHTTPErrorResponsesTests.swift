import Foundation
import Testing
@testable import AndroidMacNotifyMac

struct LocalHTTPErrorResponsesTests {
    @Test
    func testInvalidDeviceTokenResponseShape() throws {
        let response = LocalHTTPErrorResponses.invalidDeviceToken()
        let envelope = try decodeErrorEnvelope(from: response)

        #expect(response.statusCode == 401)
        #expect(response.reasonPhrase == "Unauthorized")
        #expect(envelope.error.code == "INVALID_DEVICE_TOKEN")
        #expect(envelope.error.retryable == false)
    }

    @Test
    func testDeviceMismatchCanUseCustomMessage() throws {
        let response = LocalHTTPErrorResponses.deviceTokenDeviceMismatch(
            message: "Device token does not match the requested device ID."
        )
        let envelope = try decodeErrorEnvelope(from: response)

        #expect(response.statusCode == 403)
        #expect(envelope.error.code == "DEVICE_TOKEN_DEVICE_MISMATCH")
        #expect(envelope.error.message == "Device token does not match the requested device ID.")
    }

    @Test
    func testReceiverPausedIsRetryableConflict() throws {
        let response = LocalHTTPErrorResponses.receiverPaused()
        let envelope = try decodeErrorEnvelope(from: response)

        #expect(response.statusCode == 409)
        #expect(envelope.error.code == "MAC_RECEIVER_PAUSED")
        #expect(envelope.error.retryable == true)
    }

    @Test
    func testPayloadTooLargeResponseShape() throws {
        let response = LocalHTTPErrorResponses.payloadTooLarge()
        let envelope = try decodeErrorEnvelope(from: response)

        #expect(response.statusCode == 413)
        #expect(response.reasonPhrase == "Payload Too Large")
        #expect(envelope.error.code == "PAYLOAD_TOO_LARGE")
        #expect(envelope.error.retryable == false)
    }

    @Test
    func testInvalidRequestResponseShape() throws {
        let response = LocalHTTPErrorResponses.invalidRequest(message: "Invalid test request.")
        let envelope = try decodeErrorEnvelope(from: response)

        #expect(response.statusCode == 400)
        #expect(response.reasonPhrase == "Bad Request")
        #expect(envelope.error.code == "INVALID_REQUEST")
        #expect(envelope.error.message == "Invalid test request.")
        #expect(envelope.error.retryable == false)
    }

    private func decodeErrorEnvelope(from response: HTTPResponse) throws -> ErrorEnvelope {
        try JSONDecoder().decode(ErrorEnvelope.self, from: response.body)
    }
}
