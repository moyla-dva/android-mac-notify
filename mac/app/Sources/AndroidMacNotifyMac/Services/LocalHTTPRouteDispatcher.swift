import Foundation

enum LocalHTTPRoute: Equatable, Sendable {
    case pairApprovalRequest
    case pairApprovalStatus
    case pairRegister
    case notificationEvent
    case heartbeat
    case relayState
    case sessionForget
    case sessionStatus
    case discovery
    case shareText
    case shareFile
    case notFound
}

struct LocalHTTPRouteDispatcher: Sendable {
    func route(for request: HTTPRequest) -> LocalHTTPRoute {
        route(method: request.method, path: request.path)
    }

    func route(for head: HTTPRequestHead) -> LocalHTTPRoute {
        route(method: head.method, path: head.path)
    }

    func route(method: String, path: String) -> LocalHTTPRoute {
        switch (method.uppercased(), path) {
        case ("POST", "/api/v1/pair/request"):
            return .pairApprovalRequest
        case ("GET", "/api/v1/pair/request/status"):
            return .pairApprovalStatus
        case ("POST", "/api/v1/pair/register"):
            return .pairRegister
        case ("POST", "/api/v1/events/notification"):
            return .notificationEvent
        case ("POST", "/api/v1/session/heartbeat"):
            return .heartbeat
        case ("POST", "/api/v1/session/relay-state"):
            return .relayState
        case ("POST", "/api/v1/session/forget"):
            return .sessionForget
        case ("GET", "/api/v1/session/status"):
            return .sessionStatus
        case ("GET", "/api/v1/discovery"):
            return .discovery
        case ("POST", "/api/v1/share/text"):
            return .shareText
        case ("POST", "/api/v1/share/file"):
            return .shareFile
        default:
            return .notFound
        }
    }

    func isStreamedShareFileRequest(_ head: HTTPRequestHead) -> Bool {
        route(for: head) == .shareFile &&
            head.headers["x-amn-upload-mode"]?.lowercased() == "stream"
    }
}
