import Foundation
import Network

enum LocalHTTPConnectionRequest: Sendable {
    case buffered(HTTPRequest)
    case streamedShareFile(HTTPRequestHead)
}

struct LocalHTTPConnectionResponder: Sendable {
    private let connectionHandler: LocalHTTPConnectionHandler
    private let routeDispatcher: LocalHTTPRouteDispatcher

    init(
        connectionHandler: LocalHTTPConnectionHandler = LocalHTTPConnectionHandler(),
        routeDispatcher: LocalHTTPRouteDispatcher = LocalHTTPRouteDispatcher()
    ) {
        self.connectionHandler = connectionHandler
        self.routeDispatcher = routeDispatcher
    }

    func start(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
    }

    func receiveRequest(on connection: NWConnection) async throws -> LocalHTTPConnectionRequest {
        let head = try await connectionHandler.receiveRequestHead(on: connection)
        if routeDispatcher.isStreamedShareFileRequest(head) {
            return .streamedShareFile(head)
        }

        let request = try await connectionHandler.receiveBufferedRequest(head, on: connection)
        return .buffered(request)
    }

    func send(_ response: HTTPResponse, on connection: NWConnection) async {
        await connectionHandler.send(response, on: connection)
    }

    func sendErrorResponse(for error: Error, on connection: NWConnection) async {
        guard let response = response(for: error) else {
            return
        }
        await send(response, on: connection)
    }

    func cancel(_ connection: NWConnection) {
        connection.cancel()
    }

    func response(for error: Error) -> HTTPResponse? {
        if let requestError = error as? LocalHTTPRequestError,
           case let .response(response) = requestError {
            return response
        }

        if let serverError = error as? LocalServerError {
            switch serverError {
            case .payloadTooLarge:
                return LocalHTTPErrorResponses.payloadTooLarge()
            case .malformedRequest, .invalidPort, .failedToStart:
                return LocalHTTPErrorResponses.invalidRequest(message: serverError.localizedDescription)
            }
        }

        return LocalHTTPErrorResponses.invalidRequest(message: error.localizedDescription)
    }
}
