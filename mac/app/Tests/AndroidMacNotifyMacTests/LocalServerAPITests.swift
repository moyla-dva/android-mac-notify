import Darwin
import Foundation
import Testing
@testable import AndroidMacNotifyMac

struct LocalServerAPITests {
    @Test
    func testPairApprovalRequestCanBeApprovedAndUsedForHeartbeat() async throws {
        try await withRunningServer { harness in
            let device = testDevice()
            let start: PairApprovalStartResponse = try await harness.postJSON(
                "/api/v1/pair/request",
                body: PairApprovalRequestPayload(device: device)
            ).value
            let duplicateStart: PairApprovalStartResponse = try await harness.postJSON(
                "/api/v1/pair/request",
                body: PairApprovalRequestPayload(device: device)
            ).value

            #expect(start.status == .pending)
            #expect(duplicateStart.requestId == start.requestId)

            let approvedRequest = await harness.server.approvePairingRequest(start.requestId)

            #expect(approvedRequest?.status == .approved)

            let status: PairApprovalStatusResponse = try await harness.getJSON(
                "/api/v1/pair/request/status?requestId=\(start.requestId)&deviceId=\(device.deviceId)"
            ).value

            #expect(status.status == .approved)
            #expect(status.registration?.deviceToken.isEmpty == false)

            let heartbeat: HeartbeatResponse = try await harness.postJSON(
                "/api/v1/session/heartbeat",
                token: status.registration?.deviceToken,
                body: HeartbeatRequest(deviceId: device.deviceId, sentAt: 1, networkType: "wifi")
            ).value

            #expect(heartbeat.ok)
            #expect(heartbeat.sessionState == "connected")
        }
    }

    @Test
    func testRegisterHeartbeatRelayStateAndForgetSession() async throws {
        try await withRunningServer { harness in
            let device = testDevice()
            let registration: PairRegisterResponse = try await harness.postJSON(
                "/api/v1/pair/register",
                body: PairRegisterRequest(pairingToken: harness.snapshot.pairingToken, device: device)
            ).value

            #expect(registration.macDeviceId == harness.snapshot.macDeviceId)
            #expect(registration.macDisplayName == "Test Mac")
            #expect(registration.deviceToken.isEmpty == false)

            let heartbeat: HeartbeatResponse = try await harness.postJSON(
                "/api/v1/session/heartbeat",
                token: registration.deviceToken,
                body: HeartbeatRequest(deviceId: device.deviceId, sentAt: 1, networkType: "wifi")
            ).value

            #expect(heartbeat.ok)
            #expect(heartbeat.sessionState == "connected")

            let paused: RelayStateResponse = try await harness.postJSON(
                "/api/v1/session/relay-state",
                token: registration.deviceToken,
                body: RelayStateRequest(deviceId: device.deviceId, relayState: .paused, sentAt: 2)
            ).value

            #expect(paused.ok)
            #expect(paused.sessionState == "paused")

            let status: SessionStatusResponse = try await harness.getJSON(
                "/api/v1/session/status?deviceId=\(device.deviceId)",
                token: registration.deviceToken
            ).value

            #expect(status.deviceId == device.deviceId)
            #expect(status.sessionState == "paused")

            let forgotten: SessionForgetResponse = try await harness.postJSON(
                "/api/v1/session/forget",
                token: registration.deviceToken,
                body: SessionForgetRequest(deviceId: device.deviceId, sentAt: 3)
            ).value

            #expect(forgotten.ok)
            #expect(forgotten.sessionState == "unpaired")
        }
    }

    @Test
    func testNotificationEventDeduplicatesAndPersistsOnce() async throws {
        try await withRunningServer { harness in
            let device = testDevice()
            let registration = try await harness.register(device: device)
            let payload = NotificationEventPayload(
                eventId: "evt-localserver-dedupe",
                deviceId: device.deviceId,
                appPackage: "com.example.browser",
                appName: "Browser",
                title: "Continue browsing",
                text: "https://example.com/docs",
                postedAt: 10,
                notificationKey: "key-localserver-dedupe"
            )

            let first: NotificationAcceptedResponse = try await harness.postJSON(
                "/api/v1/events/notification",
                token: registration.deviceToken,
                body: payload
            ).value
            let second: NotificationAcceptedResponse = try await harness.postJSON(
                "/api/v1/events/notification",
                token: registration.deviceToken,
                body: payload
            ).value

            #expect(first.accepted)
            #expect(!first.deduplicated)
            #expect(second.accepted)
            #expect(second.deduplicated)

            let state = try await harness.loadStoredState()
            #expect(state.registeredDevices.count == 1)
            #expect(state.recentNotifications.map(\.eventId) == [payload.eventId])
            #expect(state.recentNotifications.first?.visibleActionCandidates.map(\.kind) == [.openLink])
        }
    }

    @Test
    func testStreamedFileUploadSavesFileAndReturnsReceipt() async throws {
        try await withRunningServer { harness in
            let device = testDevice()
            let registration = try await harness.register(device: device)
            let body = Data("hello streamed file\n".utf8)
            let response: ShareFileAcceptedResponse = try await harness.postStreamedFile(
                token: registration.deviceToken,
                deviceId: device.deviceId,
                shareId: "share-localserver-stream",
                fileName: "note.txt",
                mimeType: "text/plain",
                body: body
            ).value

            #expect(response.accepted)
            #expect(response.shareId == "share-localserver-stream")
            #expect(response.fileName == "note.txt")
            #expect(response.size == Int64(body.count))
            #expect(try Data(contentsOf: URL(fileURLWithPath: response.savedPath)) == body)
        }
    }

    @Test
    func testFileUploadWithoutStreamModeIsRejected() async throws {
        try await withRunningServer { harness in
            let device = testDevice()
            let registration = try await harness.register(device: device)
            let response: LocalServerHTTPResult<ErrorEnvelope> = try await harness.postNonStreamFile(
                token: registration.deviceToken,
                body: Data("legacy body".utf8)
            )

            #expect(response.statusCode == 400)
            #expect(response.value.error.code == "INVALID_REQUEST")
            #expect(response.value.error.message.contains("X-AMN-Upload-Mode: stream"))
        }
    }
}

private struct LocalServerHTTPResult<Value> {
    let statusCode: Int
    let value: Value
}

private struct LocalServerHarness {
    let server: LocalServer
    let snapshot: LocalServerSnapshot
    let rootURL: URL
    let stateURL: URL
    let sharedFileDirectoryURL: URL

    func register(device: DeviceIdentity = testDevice()) async throws -> PairRegisterResponse {
        try await postJSON(
            "/api/v1/pair/register",
            body: PairRegisterRequest(pairingToken: snapshot.pairingToken, device: device)
        ).value
    }

    func loadStoredState() async throws -> MacStateStore.StoredState {
        let data = try Data(contentsOf: stateURL)
        return try JSONDecoder().decode(MacStateStore.StoredState.self, from: data)
    }

    func postJSON<Body: Encodable, Value: Decodable>(
        _ path: String,
        token: String? = nil,
        body: Body
    ) async throws -> LocalServerHTTPResult<Value> {
        var request = URLRequest(url: url(path))
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(body)
        return try await send(request)
    }

    func getJSON<Value: Decodable>(
        _ path: String,
        token: String? = nil
    ) async throws -> LocalServerHTTPResult<Value> {
        var request = URLRequest(url: url(path))
        request.httpMethod = "GET"
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return try await send(request)
    }

    func postStreamedFile<Value: Decodable>(
        token: String,
        deviceId: String,
        shareId: String,
        fileName: String,
        mimeType: String,
        body: Data
    ) async throws -> LocalServerHTTPResult<Value> {
        var request = URLRequest(url: url("/api/v1/share/file"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("stream", forHTTPHeaderField: "X-AMN-Upload-Mode")
        request.setValue(deviceId, forHTTPHeaderField: "X-AMN-Device-Id")
        request.setValue(shareId, forHTTPHeaderField: "X-AMN-Share-Id")
        request.setValue(Data(fileName.utf8).base64EncodedString(), forHTTPHeaderField: "X-AMN-File-Name-B64")
        request.setValue(mimeType, forHTTPHeaderField: "X-AMN-Mime-Type")
        request.setValue("1000", forHTTPHeaderField: "X-AMN-Shared-At")
        request.httpBody = body
        return try await send(request)
    }

    func postNonStreamFile<Value: Decodable>(
        token: String,
        body: Data
    ) async throws -> LocalServerHTTPResult<Value> {
        var request = URLRequest(url: url("/api/v1/share/file"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return try await sendExpectingError(request)
    }

    private func send<Value: Decodable>(_ request: URLRequest) async throws -> LocalServerHTTPResult<Value> {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TestHTTPError.missingHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw TestHTTPError.unexpectedStatus(httpResponse.statusCode, String(data: data, encoding: .utf8).orEmpty)
        }
        return LocalServerHTTPResult(
            statusCode: httpResponse.statusCode,
            value: try JSONDecoder().decode(Value.self, from: data)
        )
    }

    private func sendExpectingError<Value: Decodable>(_ request: URLRequest) async throws -> LocalServerHTTPResult<Value> {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TestHTTPError.missingHTTPResponse
        }
        guard !(200..<300).contains(httpResponse.statusCode) else {
            throw TestHTTPError.unexpectedStatus(httpResponse.statusCode, String(data: data, encoding: .utf8).orEmpty)
        }
        return LocalServerHTTPResult(
            statusCode: httpResponse.statusCode,
            value: try JSONDecoder().decode(Value.self, from: data)
        )
    }

    private func url(_ path: String) -> URL {
        URL(string: "http://127.0.0.1:\(snapshot.endpoint.port)\(path)")!
    }
}

private enum TestHTTPError: Error {
    case missingHTTPResponse
    case unexpectedStatus(Int, String)
}

private func withRunningServer<T>(
    _ body: (LocalServerHarness) async throws -> T
) async throws -> T {
    let rootURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("AndroidMacNotifyLocalServerTests-\(UUID().uuidString)", isDirectory: true)
    let stateURL = rootURL.appendingPathComponent("state.json", isDirectory: false)
    let sharedFileDirectoryURL = rootURL.appendingPathComponent("files", isDirectory: true)
    try FileManager.default.createDirectory(at: sharedFileDirectoryURL, withIntermediateDirectories: true)

    let server = LocalServer(
        macDeviceId: "mac-test",
        macDisplayName: "Test Mac",
        stateStore: MacStateStore(fileURL: stateURL)
    )
    await server.setSharedFileDirectoryURL(sharedFileDirectoryURL)
    let snapshot = try await server.start(host: "127.0.0.1", port: try reserveFreePort())
    let harness = LocalServerHarness(
        server: server,
        snapshot: snapshot,
        rootURL: rootURL,
        stateURL: stateURL,
        sharedFileDirectoryURL: sharedFileDirectoryURL
    )

    do {
        let result = try await body(harness)
        await server.stop()
        try? FileManager.default.removeItem(at: rootURL)
        return result
    } catch {
        await server.stop()
        try? FileManager.default.removeItem(at: rootURL)
        throw error
    }
}

private func testDevice() -> DeviceIdentity {
    DeviceIdentity(deviceId: "android-test", platform: "android", displayName: "Android Test")
}

private func reserveFreePort() throws -> Int {
    let fileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
    guard fileDescriptor >= 0 else {
        throw POSIXError(.EADDRNOTAVAIL)
    }
    defer {
        close(fileDescriptor)
    }

    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = in_port_t(0).bigEndian
    address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

    let bindResult = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
            Darwin.bind(fileDescriptor, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard bindResult == 0 else {
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EADDRNOTAVAIL)
    }

    var boundAddress = sockaddr_in()
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    let nameResult = withUnsafeMutablePointer(to: &boundAddress) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
            getsockname(fileDescriptor, sockaddrPointer, &length)
        }
    }
    guard nameResult == 0 else {
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EADDRNOTAVAIL)
    }

    return Int(UInt16(bigEndian: boundAddress.sin_port))
}

private extension Optional where Wrapped == String {
    var orEmpty: String {
        self ?? ""
    }
}
