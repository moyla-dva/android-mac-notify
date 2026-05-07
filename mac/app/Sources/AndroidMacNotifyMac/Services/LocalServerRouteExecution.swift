import Foundation

struct LocalServerRouteExecution: Sendable {
    let response: HTTPResponse
    let finalization: LocalRouteFinalization

    init(
        response: HTTPResponse,
        finalization: LocalRouteFinalization = LocalRouteFinalization(shouldPersist: false)
    ) {
        self.response = response
        self.finalization = finalization
    }

    init(result: some LocalHTTPRouteResult) {
        response = result.response
        finalization = result.finalization
    }

    static func decoded<Payload: Decodable, Result: LocalHTTPRouteResult>(
        request: HTTPRequest,
        as type: Payload.Type,
        runtime: LocalServerRuntime,
        _ route: (Payload) throws -> Result
    ) throws -> LocalServerRouteExecution {
        let payload = try runtime.decodeBody(type, from: request.body)
        let result = try route(payload)
        return LocalServerRouteExecution(result: result)
    }
}
