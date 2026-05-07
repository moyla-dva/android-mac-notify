import Foundation
import Network

struct LocalShareRouteResult: Sendable {
    let response: HTTPResponse
    let shouldPersist: Bool
    let event: LocalServerEvent?
}

enum LocalStreamedSharePreparation: Sendable {
    case ready(StreamedShareFileMetadata)
    case completed(LocalShareRouteResult)
}

struct LocalShareHandler: Sendable {
    private let deviceAuthenticator: LocalDeviceAuthenticator
    private let receiverGate: LocalRelayReceiverGate
    private let uploadDecoder: LocalShareFileUploadDecoder
    private let fileReceiver: LocalShareFileReceiver

    init(
        deviceAuthenticator: LocalDeviceAuthenticator = LocalDeviceAuthenticator(),
        receiverGate: LocalRelayReceiverGate = LocalRelayReceiverGate(),
        uploadDecoder: LocalShareFileUploadDecoder = LocalShareFileUploadDecoder(),
        fileReceiver: LocalShareFileReceiver = LocalShareFileReceiver()
    ) {
        self.deviceAuthenticator = deviceAuthenticator
        self.receiverGate = receiverGate
        self.uploadDecoder = uploadDecoder
        self.fileReceiver = fileReceiver
    }

    func handleText(
        headers: [String: String],
        payload: ShareTextRequest,
        registry: inout LocalDeviceRegistry,
        receiverState: RelayState,
        now: Int64
    ) throws -> LocalShareRouteResult {
        if let pausedResponse = try prepareInboundShare(
            headers: headers,
            deviceId: payload.deviceId,
            registry: &registry,
            receiverState: receiverState,
            at: now
        ) {
            return LocalShareRouteResult(response: pausedResponse, shouldPersist: true, event: nil)
        }

        return try LocalShareRouteResult(
            response: .json(
                ShareTextAcceptedResponse(accepted: true, shareId: payload.shareId),
                statusCode: 202,
                reasonPhrase: "Accepted"
            ),
            shouldPersist: false,
            event: .sharedText(deviceId: payload.deviceId, text: payload.text, sharedAt: payload.sharedAt)
        )
    }

    func prepareStreamedFile(
        head: HTTPRequestHead,
        registry: inout LocalDeviceRegistry,
        receiverState: RelayState,
        now: Int64
    ) throws -> LocalStreamedSharePreparation {
        let metadata = try uploadDecoder.decodeStreamedMetadata(from: head)
        if let pausedResponse = try prepareInboundShare(
            headers: head.headers,
            deviceId: metadata.deviceId,
            registry: &registry,
            receiverState: receiverState,
            at: now
        ) {
            return .completed(LocalShareRouteResult(response: pausedResponse, shouldPersist: true, event: nil))
        }
        return .ready(metadata)
    }

    func receiveStreamedFile(
        metadata: StreamedShareFileMetadata,
        head: HTTPRequestHead,
        connection: NWConnection,
        directoryURL: URL?,
        progressEventSink: (@Sendable (LocalServerEvent) -> Void)?
    ) async throws -> LocalShareRouteResult {
        let receiveResult = try await fileReceiver.receiveStreamedUpload(
            metadata: metadata,
            head: head,
            connection: connection,
            directoryURL: directoryURL,
            progressEventSink: progressEventSink
        )
        return LocalShareRouteResult(
            response: receiveResult.response,
            shouldPersist: receiveResult.receipt != nil,
            event: receiveResult.receipt.map(LocalServerEvent.sharedFile)
        )
    }

    private func prepareInboundShare(
        headers: [String: String],
        deviceId: String,
        registry: inout LocalDeviceRegistry,
        receiverState: RelayState,
        at timestamp: Int64
    ) throws -> HTTPResponse? {
        _ = try deviceAuthenticator.requireAuthenticatedDeviceId(
            headers: headers,
            suppliedDeviceId: deviceId,
            registry: registry
        )
        return receiverGate.prepareInboundRelay(
            deviceId: deviceId,
            registry: &registry,
            receiverState: receiverState,
            at: timestamp
        )
    }
}
