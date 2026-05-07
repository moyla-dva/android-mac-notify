import Foundation

enum SharedFileStore {
    enum StoreError: LocalizedError {
        case emptyFileName
        case cannotCreateTemporaryFile
        case insufficientDiskSpace(requiredBytes: Int64, availableBytes: Int64?)

        var errorDescription: String? {
            switch self {
            case .emptyFileName:
                return "File name is empty."
            case .cannotCreateTemporaryFile:
                return "Cannot create temporary upload file."
            case let .insufficientDiskSpace(requiredBytes, availableBytes):
                let requiredText = ByteCountFormatter.string(fromByteCount: requiredBytes, countStyle: .file)
                guard let availableBytes else {
                    return "保存目录空间不足，需要 \(requiredText)"
                }
                let availableText = ByteCountFormatter.string(fromByteCount: availableBytes, countStyle: .file)
                return "保存目录空间不足，需要 \(requiredText)，当前可用 \(availableText)"
            }
        }
    }

    private static let temporaryUploadPrefix = ".AndroidMacNotify-"
    private static let temporaryUploadExtension = "upload"
    private static let staleTemporaryUploadAgeSeconds: TimeInterval = 6 * 60 * 60

    struct PreparedStreamedSave: Sendable {
        let temporaryURL: URL
        fileprivate let targetDirectoryURL: URL
        fileprivate let safeFileName: String
    }

    static func save(
        data: Data,
        fileName: String,
        shareId: String,
        batchId: String? = nil,
        batchIndex: Int? = nil,
        batchTotal: Int? = nil,
        deviceId: String,
        receivedAt: Int64,
        directoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> SharedFileReceipt {
        let safeFileName = sanitizedFileName(fileName)
        guard !safeFileName.isEmpty else {
            throw StoreError.emptyFileName
        }

        let targetDirectory = directoryURL ?? defaultDirectoryURL(fileManager: fileManager)
        try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

        let targetURL = uniqueFileURL(
            in: targetDirectory,
            fileName: safeFileName,
            fileManager: fileManager
        )
        try data.write(to: targetURL, options: .atomic)
        let savedFileName = targetURL.lastPathComponent

        return SharedFileReceipt(
            shareId: shareId,
            batchId: batchId,
            batchIndex: batchIndex,
            batchTotal: batchTotal,
            deviceId: deviceId,
            originalFileName: savedFileName == safeFileName ? nil : safeFileName,
            fileName: savedFileName,
            savedPath: targetURL.path,
            size: Int64(data.count),
            receivedAt: receivedAt
        )
    }

    static func save(
        fileURL: URL,
        fileName: String,
        shareId: String,
        batchId: String? = nil,
        batchIndex: Int? = nil,
        batchTotal: Int? = nil,
        deviceId: String,
        receivedAt: Int64,
        directoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> SharedFileReceipt {
        let safeFileName = sanitizedFileName(fileName)
        guard !safeFileName.isEmpty else {
            throw StoreError.emptyFileName
        }

        let targetDirectory = directoryURL ?? defaultDirectoryURL(fileManager: fileManager)
        try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

        let targetURL = uniqueFileURL(
            in: targetDirectory,
            fileName: safeFileName,
            fileManager: fileManager
        )
        try fileManager.moveItem(at: fileURL, to: targetURL)
        let savedFileName = targetURL.lastPathComponent

        let attributes = try fileManager.attributesOfItem(atPath: targetURL.path)
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0

        return SharedFileReceipt(
            shareId: shareId,
            batchId: batchId,
            batchIndex: batchIndex,
            batchTotal: batchTotal,
            deviceId: deviceId,
            originalFileName: savedFileName == safeFileName ? nil : safeFileName,
            fileName: savedFileName,
            savedPath: targetURL.path,
            size: size,
            receivedAt: receivedAt
        )
    }

    static func prepareStreamedSave(
        fileName: String,
        expectedBytes: Int64? = nil,
        directoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> PreparedStreamedSave {
        let safeFileName = sanitizedFileName(fileName)
        guard !safeFileName.isEmpty else {
            throw StoreError.emptyFileName
        }

        let targetDirectory = directoryURL ?? defaultDirectoryURL(fileManager: fileManager)
        try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        cleanupStaleTemporaryUploads(in: targetDirectory, fileManager: fileManager)
        try validateAvailableSpace(
            in: targetDirectory,
            expectedBytes: expectedBytes,
            fileManager: fileManager
        )

        let temporaryURL = targetDirectory.appendingPathComponent(
            "\(temporaryUploadPrefix)\(UUID().uuidString).\(temporaryUploadExtension)",
            isDirectory: false
        )
        guard fileManager.createFile(atPath: temporaryURL.path, contents: nil) else {
            throw StoreError.cannotCreateTemporaryFile
        }

        return PreparedStreamedSave(
            temporaryURL: temporaryURL,
            targetDirectoryURL: targetDirectory,
            safeFileName: safeFileName
        )
    }

    static func finishStreamedSave(
        _ preparedSave: PreparedStreamedSave,
        shareId: String,
        batchId: String? = nil,
        batchIndex: Int? = nil,
        batchTotal: Int? = nil,
        deviceId: String,
        receivedAt: Int64,
        fileManager: FileManager = .default
    ) throws -> SharedFileReceipt {
        let targetURL = uniqueFileURL(
            in: preparedSave.targetDirectoryURL,
            fileName: preparedSave.safeFileName,
            fileManager: fileManager
        )
        try fileManager.moveItem(at: preparedSave.temporaryURL, to: targetURL)
        let savedFileName = targetURL.lastPathComponent

        let attributes = try fileManager.attributesOfItem(atPath: targetURL.path)
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0

        return SharedFileReceipt(
            shareId: shareId,
            batchId: batchId,
            batchIndex: batchIndex,
            batchTotal: batchTotal,
            deviceId: deviceId,
            originalFileName: savedFileName == preparedSave.safeFileName ? nil : preparedSave.safeFileName,
            fileName: savedFileName,
            savedPath: targetURL.path,
            size: size,
            receivedAt: receivedAt
        )
    }

    static func sanitizedFileName(_ rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let invalidCharacters = CharacterSet(charactersIn: "/\\:\0")
            .union(.newlines)
            .union(.controlCharacters)

        let sanitizedScalars = trimmed.unicodeScalars.map { scalar in
            invalidCharacters.contains(scalar) ? "_" : String(scalar)
        }
        let sanitized = sanitizedScalars.joined()
            .replacingOccurrences(of: #"_+"#, with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))

        return sanitized.isEmpty ? "shared-file" : sanitized
    }

    static func defaultDirectoryURL(fileManager: FileManager = .default) -> URL {
        let downloadsURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads", isDirectory: true)
        return downloadsURL.appendingPathComponent("Android Mac Notify", isDirectory: true)
    }

    static func cleanupStaleTemporaryUploads(
        in directoryURL: URL,
        olderThan cutoffDate: Date = Date(timeIntervalSinceNow: -staleTemporaryUploadAgeSeconds),
        fileManager: FileManager = .default
    ) {
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsSubdirectoryDescendants]
        ) else {
            return
        }

        for fileURL in fileURLs where isTemporaryUploadURL(fileURL) {
            let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard resourceValues?.isRegularFile != false,
                  let modificationDate = resourceValues?.contentModificationDate,
                  modificationDate < cutoffDate
            else {
                continue
            }
            try? fileManager.removeItem(at: fileURL)
        }
    }

    private static func uniqueFileURL(
        in directoryURL: URL,
        fileName: String,
        fileManager: FileManager
    ) -> URL {
        let originalURL = directoryURL.appendingPathComponent(fileName, isDirectory: false)
        guard fileManager.fileExists(atPath: originalURL.path) else {
            return originalURL
        }

        let baseName = originalURL.deletingPathExtension().lastPathComponent
        let pathExtension = originalURL.pathExtension

        for index in 2 ... 999 {
            let candidateName: String
            if pathExtension.isEmpty {
                candidateName = "\(baseName) \(index)"
            } else {
                candidateName = "\(baseName) \(index).\(pathExtension)"
            }
            let candidateURL = directoryURL.appendingPathComponent(candidateName, isDirectory: false)
            if !fileManager.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
        }

        return directoryURL.appendingPathComponent("\(UUID().uuidString)-\(fileName)", isDirectory: false)
    }

    private static func validateAvailableSpace(
        in directoryURL: URL,
        expectedBytes: Int64?,
        fileManager: FileManager
    ) throws {
        guard let expectedBytes, expectedBytes > 0 else {
            return
        }
        let availableBytes = availableDiskSpace(in: directoryURL, fileManager: fileManager)
        guard let availableBytes else {
            return
        }
        if availableBytes < expectedBytes {
            throw StoreError.insufficientDiskSpace(requiredBytes: expectedBytes, availableBytes: availableBytes)
        }
    }

    private static func availableDiskSpace(in directoryURL: URL, fileManager: FileManager) -> Int64? {
        guard let attributes = try? fileManager.attributesOfFileSystem(forPath: directoryURL.path),
              let freeSize = attributes[.systemFreeSize] as? NSNumber
        else {
            return nil
        }
        return freeSize.int64Value
    }

    private static func isTemporaryUploadURL(_ fileURL: URL) -> Bool {
        fileURL.lastPathComponent.hasPrefix(temporaryUploadPrefix) &&
            fileURL.pathExtension == temporaryUploadExtension
    }
}
