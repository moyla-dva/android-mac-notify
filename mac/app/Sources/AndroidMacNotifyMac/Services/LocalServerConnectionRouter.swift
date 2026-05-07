import Foundation
import Network

struct LocalServerConnectionRouter: Sendable {
    private let responder: LocalHTTPConnectionResponder

    init(responder: LocalHTTPConnectionResponder = LocalHTTPConnectionResponder()) {
        self.responder = responder
    }

    func handle(
        connection: NWConnection,
        server: isolated LocalServer
    ) async {
        responder.start(connection)

        do {
            let response: HTTPResponse
            switch try await responder.receiveRequest(on: connection) {
            case let .buffered(request):
                response = try await server.route(request: request)
            case let .streamedShareFile(head):
                response = try await server.handleStreamedShareFile(head, on: connection)
            }
            await responder.send(response, on: connection)
        } catch {
            await responder.sendErrorResponse(for: error, on: connection)
        }

        responder.cancel(connection)
    }
}
