import Foundation

struct HTTPRequest: Sendable {
    let method: String
    let target: String
    let path: String
    let queryItems: [String: String]
    let headers: [String: String]
    let body: Data
}

struct HTTPRequestHead: Sendable {
    let method: String
    let target: String
    let path: String
    let queryItems: [String: String]
    let headers: [String: String]
    let contentLength: Int
    let initialBody: Data
}

struct HTTPResponse: Sendable {
    let statusCode: Int
    let reasonPhrase: String
    let headers: [String: String]
    let body: Data

    static func json<T: Encodable>(_ value: T, statusCode: Int, reasonPhrase: String) throws -> HTTPResponse {
        let encoder = JSONEncoder()
        let body = try encoder.encode(value)
        return HTTPResponse(
            statusCode: statusCode,
            reasonPhrase: reasonPhrase,
            headers: [
                "Content-Type": "application/json",
                "Content-Length": "\(body.count)",
                "Connection": "close",
            ],
            body: body
        )
    }

    static func error(
        statusCode: Int,
        reasonPhrase: String,
        code: String,
        message: String,
        retryable: Bool? = nil
    ) -> HTTPResponse {
        let errorBody = ErrorEnvelope(error: APIErrorDetail(code: code, message: message, retryable: retryable))
        let body = (try? JSONEncoder().encode(errorBody)) ?? Data()
        return HTTPResponse(
            statusCode: statusCode,
            reasonPhrase: reasonPhrase,
            headers: [
                "Content-Type": "application/json",
                "Content-Length": "\(body.count)",
                "Connection": "close",
            ],
            body: body
        )
    }

    static func notFound() -> HTTPResponse {
        error(
            statusCode: 404,
            reasonPhrase: "Not Found",
            code: "NOT_FOUND",
            message: "Endpoint not found.",
            retryable: false
        )
    }
}
