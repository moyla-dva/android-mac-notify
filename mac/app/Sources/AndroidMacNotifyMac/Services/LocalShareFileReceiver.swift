import Foundation
import Network

struct LocalShareFileReceiveResult: Sendable {
    let response: HTTPResponse
    let receipt: SharedFileReceipt?
}

struct LocalShareFileReceiver: Sendable {
    private struct StreamedShareFileFailure: LocalizedError, Sendable {
        let receivedBytes: Int64
        let message: String

        var errorDescription: String? {
            message
        }
    }

    private let httpConnectionHandler: LocalHTTPConnectionHandler

    init(httpConnectionHandler: LocalHTTPConnectionHandler = LocalHTTPConnectionHandler()) {
        self.httpConnectionHandler = httpConnectionHandler
    }

    func receiveStreamedUpload(
        metadata: StreamedShareFileMetadata,
        head: HTTPRequestHead,
        connection: NWConnection,
        directoryURL: URL?,
        progressEventSink: (@Sendable (LocalServerEvent) -> Void)?
    ) async throws -> LocalShareFileReceiveResult {
        let preparedSave: SharedFileStore.PreparedStreamedSave
        do {
            preparedSave = try SharedFileStore.prepareStreamedSave(
                fileName: metadata.fileName,
                expectedBytes: metadata.size,
                directoryURL: directoryURL
            )
        } catch {
            let errorCode = if case .insufficientDiskSpace = error as? SharedFileStore.StoreError {
                "INSUFFICIENT_STORAGE"
            } else {
                "FILE_SAVE_FAILED"
            }
            emitSharedFileTransferFailed(
                metadata: metadata,
                receivedBytes: 0,
                message: "文件保存目录不可用: \(error.localizedDescription)",
                progressEventSink: progressEventSink
            )
            return LocalShareFileReceiveResult(
                response: fileSaveFailedResponse(code: errorCode, message: error.localizedDescription),
                receipt: nil
            )
        }
        defer {
            try? FileManager.default.removeItem(at: preparedSave.temporaryURL)
        }

        let receivedBytes: Int64
        do {
            receivedBytes = try await receiveStreamedShareFileBody(
                metadata: metadata,
                head: head,
                connection: connection,
                destinationURL: preparedSave.temporaryURL,
                progressEventSink: progressEventSink
            )
        } catch {
            let streamFailure = error as? StreamedShareFileFailure
            emitSharedFileTransferFailed(
                metadata: metadata,
                receivedBytes: streamFailure?.receivedBytes ?? 0,
                message: streamFailure?.message ?? error.localizedDescription,
                progressEventSink: progressEventSink
            )
            throw error
        }

        guard receivedBytes == metadata.size else {
            emitSharedFileTransferFailed(
                metadata: metadata,
                receivedBytes: receivedBytes,
                message: "接收中断，请在手机端重试",
                progressEventSink: progressEventSink
            )
            throw ShareFileUploadError.invalidFilePayload
        }

        do {
            let receipt = try SharedFileStore.finishStreamedSave(
                preparedSave,
                shareId: metadata.shareId,
                batchId: metadata.batchId,
                batchIndex: metadata.batchIndex,
                batchTotal: metadata.batchTotal,
                deviceId: metadata.deviceId,
                receivedAt: Self.nowMillis()
            )
            return try acceptedResult(for: receipt)
        } catch {
            emitSharedFileTransferFailed(
                metadata: metadata,
                receivedBytes: receivedBytes,
                message: "文件保存失败: \(error.localizedDescription)",
                progressEventSink: progressEventSink
            )
            return LocalShareFileReceiveResult(
                response: fileSaveFailedResponse(message: error.localizedDescription),
                receipt: nil
            )
        }
    }

    private func receiveStreamedShareFileBody(
        metadata: StreamedShareFileMetadata,
        head: HTTPRequestHead,
        connection: NWConnection,
        destinationURL: URL,
        progressEventSink: (@Sendable (LocalServerEvent) -> Void)?
    ) async throws -> Int64 {
        let expectedBytes = Int64(head.contentLength)
        var receivedBytes: Int64 = 0
        let startedAt = Self.nowMillis()
        var lastProgressEmitAt = Int64(0)
        let fileHandle = try FileHandle(forWritingTo: destinationURL)

        do {
            try writeStreamedShareFileChunk(head.initialBody, to: fileHandle, receivedBytes: &receivedBytes, expectedBytes: expectedBytes)
            emitSharedFileTransferProgressIfNeeded(
                metadata: metadata,
                receivedBytes: receivedBytes,
                startedAt: startedAt,
                lastProgressEmitAt: &lastProgressEmitAt,
                force: true,
                progressEventSink: progressEventSink
            )

            while receivedBytes < expectedBytes {
                let chunk = try await httpConnectionHandler.receiveChunk(on: connection)
                if !chunk.data.isEmpty {
                    try writeStreamedShareFileChunk(chunk.data, to: fileHandle, receivedBytes: &receivedBytes, expectedBytes: expectedBytes)
                    emitSharedFileTransferProgressIfNeeded(
                        metadata: metadata,
                        receivedBytes: receivedBytes,
                        startedAt: startedAt,
                        lastProgressEmitAt: &lastProgressEmitAt,
                        force: receivedBytes >= expectedBytes,
                        progressEventSink: progressEventSink
                    )
                }

                if chunk.isComplete {
                    break
                }
            }

            try fileHandle.close()
            return receivedBytes
        } catch {
            try? fileHandle.close()
            throw StreamedShareFileFailure(
                receivedBytes: receivedBytes,
                message: "接收中断，请在手机端重试"
            )
        }
    }

    private func emitSharedFileTransferProgressIfNeeded(
        metadata: StreamedShareFileMetadata,
        receivedBytes: Int64,
        startedAt: Int64,
        lastProgressEmitAt: inout Int64,
        force: Bool = false,
        progressEventSink: (@Sendable (LocalServerEvent) -> Void)?
    ) {
        let now = Self.nowMillis()
        guard force || now - lastProgressEmitAt >= 500 else {
            return
        }

        lastProgressEmitAt = now
        emitSharedFileTransferProgress(
            metadata: metadata,
            receivedBytes: receivedBytes,
            startedAt: startedAt,
            message: nil,
            progressEventSink: progressEventSink
        )
    }

    private func emitSharedFileTransferProgress(
        metadata: StreamedShareFileMetadata,
        receivedBytes: Int64,
        startedAt: Int64,
        message: String?,
        progressEventSink: (@Sendable (LocalServerEvent) -> Void)?
    ) {
        let now = Self.nowMillis()
        let elapsedMillis = max(now - startedAt, 1)
        let speedBytesPerSecond = max((receivedBytes * 1_000) / elapsedMillis, 0)
        let remainingSeconds: Int64? = if speedBytesPerSecond > 0, metadata.size > receivedBytes {
            ((metadata.size - receivedBytes) + speedBytesPerSecond - 1) / speedBytesPerSecond
        } else {
            nil
        }

        progressEventSink?(
            .sharedFileTransferUpdated(
                SharedFileReceiveStatus(
                    transferId: metadata.shareId,
                    batchId: metadata.batchId,
                    batchIndex: metadata.batchIndex,
                    batchTotal: metadata.batchTotal,
                    fileName: metadata.fileName,
                    receivedBytes: min(receivedBytes, metadata.size),
                    totalBytes: metadata.size,
                    speedBytesPerSecond: speedBytesPerSecond > 0 ? speedBytesPerSecond : nil,
                    remainingSeconds: remainingSeconds,
                    stage: .receiving,
                    message: message,
                    updatedAt: now
                )
            )
        )
    }

    private func emitSharedFileTransferFailed(
        metadata: StreamedShareFileMetadata,
        receivedBytes: Int64,
        message: String,
        progressEventSink: (@Sendable (LocalServerEvent) -> Void)?
    ) {
        progressEventSink?(
            .sharedFileTransferUpdated(
                SharedFileReceiveStatus(
                    transferId: metadata.shareId,
                    batchId: metadata.batchId,
                    batchIndex: metadata.batchIndex,
                    batchTotal: metadata.batchTotal,
                    fileName: metadata.fileName,
                    receivedBytes: min(max(receivedBytes, 0), metadata.size),
                    totalBytes: metadata.size,
                    speedBytesPerSecond: nil,
                    remainingSeconds: nil,
                    stage: .failed,
                    message: message,
                    updatedAt: Self.nowMillis()
                )
            )
        )
    }

    private func writeStreamedShareFileChunk(
        _ data: Data,
        to fileHandle: FileHandle,
        receivedBytes: inout Int64,
        expectedBytes: Int64
    ) throws {
        guard !data.isEmpty, receivedBytes < expectedBytes else {
            return
        }

        let remainingBytes = expectedBytes - receivedBytes
        let writeCount = min(Int64(data.count), remainingBytes)
        guard writeCount <= Int64(Int.max) else {
            throw LocalServerError.malformedRequest
        }

        let writeData = Data(data.prefix(Int(writeCount)))
        try fileHandle.write(contentsOf: writeData)
        receivedBytes += writeCount
    }

    private func acceptedResult(for receipt: SharedFileReceipt) throws -> LocalShareFileReceiveResult {
        LocalShareFileReceiveResult(
            response: try .json(
                ShareFileAcceptedResponse(
                    accepted: true,
                    shareId: receipt.shareId,
                    fileName: receipt.fileName,
                    savedPath: receipt.savedPath,
                    size: receipt.size
                ),
                statusCode: 202,
                reasonPhrase: "Accepted"
            ),
            receipt: receipt
        )
    }

    private func fileSaveFailedResponse(
        code: String = "FILE_SAVE_FAILED",
        message: String
    ) -> HTTPResponse {
        .error(
            statusCode: 500,
            reasonPhrase: "Internal Server Error",
            code: code,
            message: message,
            retryable: true
        )
    }

    private static func nowMillis() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}
