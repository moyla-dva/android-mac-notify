import Foundation

struct StreamedShareFileMetadata: Sendable {
    let deviceId: String
    let shareId: String
    let batchId: String?
    let batchIndex: Int?
    let batchTotal: Int?
    let fileName: String
    let mimeType: String?
    let size: Int64
    let sharedAt: Int64
}

enum ShareFileUploadError: LocalizedError {
    case missingField(String)
    case invalidField(String)
    case invalidFilePayload

    var errorDescription: String? {
        switch self {
        case let .missingField(name):
            return "File upload field '\(name)' is missing."
        case let .invalidField(name):
            return "File upload field '\(name)' is invalid."
        case .invalidFilePayload:
            return "File payload could not be decoded."
        }
    }
}

struct LocalShareFileUploadDecoder: Sendable {
    func decodeStreamedMetadata(from head: HTTPRequestHead) throws -> StreamedShareFileMetadata {
        guard let deviceId = head.headers["x-amn-device-id"], !deviceId.isEmpty else {
            throw ShareFileUploadError.missingField("x-amn-device-id")
        }
        guard let shareId = head.headers["x-amn-share-id"], !shareId.isEmpty else {
            throw ShareFileUploadError.missingField("x-amn-share-id")
        }
        guard let encodedFileName = head.headers["x-amn-file-name-b64"],
              let fileNameData = Data(base64Encoded: encodedFileName),
              let fileName = String(data: fileNameData, encoding: .utf8),
              !fileName.isEmpty
        else {
            throw ShareFileUploadError.invalidField("x-amn-file-name-b64")
        }
        guard let rawSharedAt = head.headers["x-amn-shared-at"],
              let sharedAt = Int64(rawSharedAt)
        else {
            throw ShareFileUploadError.invalidField("x-amn-shared-at")
        }

        let batchId = head.headers["x-amn-batch-id"].flatMap { $0.isEmpty ? nil : $0 }
        let batchIndex = try decodeOptionalIntHeader("x-amn-batch-index", from: head.headers)
        let batchTotal = try decodeOptionalIntHeader("x-amn-batch-total", from: head.headers)
        if batchId != nil || batchIndex != nil || batchTotal != nil {
            guard let batchId, !batchId.isEmpty, let batchIndex, let batchTotal else {
                throw ShareFileUploadError.invalidField("x-amn-batch-*")
            }
            guard batchIndex >= 0, batchTotal > 0, batchIndex < batchTotal else {
                throw ShareFileUploadError.invalidField("x-amn-batch-index")
            }
        }

        return StreamedShareFileMetadata(
            deviceId: deviceId,
            shareId: shareId,
            batchId: batchId,
            batchIndex: batchIndex,
            batchTotal: batchTotal,
            fileName: fileName,
            mimeType: head.headers["x-amn-mime-type"].flatMap { $0.isEmpty ? nil : $0 },
            size: Int64(head.contentLength),
            sharedAt: sharedAt
        )
    }

    private func decodeOptionalIntHeader(
        _ name: String,
        from headers: [String: String]
    ) throws -> Int? {
        guard let rawValue = headers[name], !rawValue.isEmpty else {
            return nil
        }
        guard let value = Int(rawValue) else {
            throw ShareFileUploadError.invalidField(name)
        }
        return value
    }
}
