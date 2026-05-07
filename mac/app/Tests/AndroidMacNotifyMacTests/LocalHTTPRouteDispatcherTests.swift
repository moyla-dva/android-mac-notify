import Foundation
import Testing
@testable import AndroidMacNotifyMac

struct LocalHTTPRouteDispatcherTests {
    @Test
    func testRoutesKnownAPIEndpoints() {
        let dispatcher = LocalHTTPRouteDispatcher()

        #expect(dispatcher.route(method: "POST", path: "/api/v1/pair/request") == .pairApprovalRequest)
        #expect(dispatcher.route(method: "GET", path: "/api/v1/pair/request/status") == .pairApprovalStatus)
        #expect(dispatcher.route(method: "POST", path: "/api/v1/pair/register") == .pairRegister)
        #expect(dispatcher.route(method: "POST", path: "/api/v1/events/notification") == .notificationEvent)
        #expect(dispatcher.route(method: "POST", path: "/api/v1/session/heartbeat") == .heartbeat)
        #expect(dispatcher.route(method: "POST", path: "/api/v1/session/relay-state") == .relayState)
        #expect(dispatcher.route(method: "POST", path: "/api/v1/session/forget") == .sessionForget)
        #expect(dispatcher.route(method: "GET", path: "/api/v1/session/status") == .sessionStatus)
        #expect(dispatcher.route(method: "GET", path: "/api/v1/discovery") == .discovery)
        #expect(dispatcher.route(method: "POST", path: "/api/v1/share/text") == .shareText)
        #expect(dispatcher.route(method: "POST", path: "/api/v1/share/file") == .shareFile)
    }

    @Test
    func testUnknownOrWrongMethodRoutesToNotFound() {
        let dispatcher = LocalHTTPRouteDispatcher()

        #expect(dispatcher.route(method: "GET", path: "/api/v1/share/file") == .notFound)
        #expect(dispatcher.route(method: "POST", path: "/api/v1/unknown") == .notFound)
    }

    @Test
    func testStreamedShareFileDetectionRequiresRouteAndHeader() {
        let dispatcher = LocalHTTPRouteDispatcher()

        #expect(dispatcher.isStreamedShareFileRequest(head(method: "POST", path: "/api/v1/share/file", uploadMode: "stream")))
        #expect(dispatcher.isStreamedShareFileRequest(head(method: "POST", path: "/api/v1/share/file", uploadMode: "STREAM")))
        #expect(!dispatcher.isStreamedShareFileRequest(head(method: "POST", path: "/api/v1/share/file", uploadMode: "raw")))
        #expect(!dispatcher.isStreamedShareFileRequest(head(method: "POST", path: "/api/v1/share/file", uploadMode: nil)))
        #expect(!dispatcher.isStreamedShareFileRequest(head(method: "POST", path: "/api/v1/share/text", uploadMode: "stream")))
    }

    private func head(method: String, path: String, uploadMode: String?) -> HTTPRequestHead {
        var headers: [String: String] = [:]
        if let uploadMode {
            headers["x-amn-upload-mode"] = uploadMode
        }

        return HTTPRequestHead(
            method: method,
            target: path,
            path: path,
            queryItems: [:],
            headers: headers,
            contentLength: 0,
            initialBody: Data()
        )
    }
}
