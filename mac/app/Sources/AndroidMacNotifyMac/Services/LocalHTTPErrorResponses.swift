import Foundation

enum LocalHTTPRequestError: Error {
    case response(HTTPResponse)
}

struct LocalHTTPErrorResponses: Sendable {
    static func invalidDeviceToken() -> HTTPResponse {
        .error(
            statusCode: 401,
            reasonPhrase: "Unauthorized",
            code: "INVALID_DEVICE_TOKEN",
            message: "Device token is invalid.",
            retryable: false
        )
    }

    static func deviceTokenDeviceMismatch(
        message: String = "Device token does not match the supplied device ID."
    ) -> HTTPResponse {
        .error(
            statusCode: 403,
            reasonPhrase: "Forbidden",
            code: "DEVICE_TOKEN_DEVICE_MISMATCH",
            message: message,
            retryable: false
        )
    }

    static func deviceNotRegistered() -> HTTPResponse {
        .error(
            statusCode: 404,
            reasonPhrase: "Not Found",
            code: "DEVICE_NOT_REGISTERED",
            message: "Device is not registered.",
            retryable: false
        )
    }

    static func receiverPaused() -> HTTPResponse {
        .error(
            statusCode: 409,
            reasonPhrase: "Conflict",
            code: "MAC_RECEIVER_PAUSED",
            message: "Mac 接力已暂停，重新开始后会继续接收。",
            retryable: true
        )
    }

    static func invalidFilePayload() -> HTTPResponse {
        .error(
            statusCode: 400,
            reasonPhrase: "Bad Request",
            code: "INVALID_FILE_PAYLOAD",
            message: "File payload could not be decoded.",
            retryable: false
        )
    }

    static func payloadTooLarge() -> HTTPResponse {
        .error(
            statusCode: 413,
            reasonPhrase: "Payload Too Large",
            code: "PAYLOAD_TOO_LARGE",
            message: "Request payload is too large.",
            retryable: false
        )
    }

    static func invalidRequest(message: String) -> HTTPResponse {
        .error(
            statusCode: 400,
            reasonPhrase: "Bad Request",
            code: "INVALID_REQUEST",
            message: message,
            retryable: false
        )
    }
}
