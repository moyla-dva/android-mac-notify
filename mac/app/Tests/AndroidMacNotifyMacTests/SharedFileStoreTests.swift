import Foundation
import Testing
@testable import AndroidMacNotifyMac

struct SharedFileStoreTests {
    @Test
    func testSanitizedFileNameRemovesPathSeparators() {
        let sanitizedName = SharedFileStore.sanitizedFileName("../unsafe:name.txt")

        #expect(sanitizedName.contains("/") == false)
        #expect(sanitizedName.contains(":") == false)
        #expect(sanitizedName.hasSuffix("unsafe_name.txt"))
        #expect(SharedFileStore.sanitizedFileName("   ") == "shared-file")
    }

    @Test
    func testSaveUsesUniqueFileName() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AndroidMacNotifySharedFileStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let first = try SharedFileStore.save(
            data: Data("hello".utf8),
            fileName: "note.txt",
            shareId: "share-1",
            deviceId: "android-test",
            receivedAt: 1,
            directoryURL: directoryURL
        )
        let second = try SharedFileStore.save(
            data: Data("world".utf8),
            fileName: "note.txt",
            shareId: "share-2",
            deviceId: "android-test",
            receivedAt: 2,
            directoryURL: directoryURL
        )

        #expect(first.fileName == "note.txt")
        #expect(second.fileName == "note 2.txt")
        #expect(first.originalFileName == nil)
        #expect(second.originalFileName == "note.txt")
        #expect(FileManager.default.fileExists(atPath: first.savedPath))
        #expect(FileManager.default.fileExists(atPath: second.savedPath))
    }

    @Test
    func testSaveMovesStreamedTemporaryFile() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AndroidMacNotifySharedFileStoreTests-\(UUID().uuidString)", isDirectory: true)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AndroidMacNotifySharedFileStoreTests-\(UUID().uuidString).upload")
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
            try? FileManager.default.removeItem(at: tempURL)
        }

        try Data("streamed".utf8).write(to: tempURL)

        let receipt = try SharedFileStore.save(
            fileURL: tempURL,
            fileName: "large.bin",
            shareId: "share-stream",
            deviceId: "android-test",
            receivedAt: 3,
            directoryURL: directoryURL
        )

        #expect(receipt.fileName == "large.bin")
        #expect(receipt.size == 8)
        #expect(FileManager.default.fileExists(atPath: receipt.savedPath))
        #expect(FileManager.default.fileExists(atPath: tempURL.path) == false)
    }

    @Test
    func testPreparedStreamedSaveUsesTargetDirectoryTemporaryFile() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AndroidMacNotifySharedFileStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let preparedSave = try SharedFileStore.prepareStreamedSave(
            fileName: "large.bin",
            directoryURL: directoryURL
        )
        #expect(preparedSave.temporaryURL.deletingLastPathComponent().standardizedFileURL == directoryURL.standardizedFileURL)
        #expect(FileManager.default.fileExists(atPath: preparedSave.temporaryURL.path))

        try Data("streamed".utf8).write(to: preparedSave.temporaryURL)

        let receipt = try SharedFileStore.finishStreamedSave(
            preparedSave,
            shareId: "share-prepared",
            deviceId: "android-test",
            receivedAt: 4
        )

        #expect(receipt.fileName == "large.bin")
        #expect(receipt.size == 8)
        #expect(FileManager.default.fileExists(atPath: receipt.savedPath))
        #expect(FileManager.default.fileExists(atPath: preparedSave.temporaryURL.path) == false)
    }

    @Test
    func testPreparedStreamedSaveStillAvoidsDuplicateFinalNames() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AndroidMacNotifySharedFileStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        _ = try SharedFileStore.save(
            data: Data("existing".utf8),
            fileName: "large.bin",
            shareId: "share-existing",
            deviceId: "android-test",
            receivedAt: 4,
            directoryURL: directoryURL
        )
        let preparedSave = try SharedFileStore.prepareStreamedSave(
            fileName: "large.bin",
            directoryURL: directoryURL
        )
        try Data("streamed".utf8).write(to: preparedSave.temporaryURL)

        let receipt = try SharedFileStore.finishStreamedSave(
            preparedSave,
            shareId: "share-prepared",
            deviceId: "android-test",
            receivedAt: 5
        )

        #expect(receipt.fileName == "large 2.bin")
        #expect(receipt.originalFileName == "large.bin")
    }

    @Test
    func testPreparedStreamedSaveRejectsObviouslyInsufficientSpace() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AndroidMacNotifySharedFileStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        do {
            _ = try SharedFileStore.prepareStreamedSave(
                fileName: "huge.bin",
                expectedBytes: Int64.max,
                directoryURL: directoryURL
            )
            #expect(Bool(false))
        } catch let error as SharedFileStore.StoreError {
            if case let .insufficientDiskSpace(requiredBytes, availableBytes) = error {
                #expect(requiredBytes == Int64.max)
                #expect(availableBytes != nil)
            } else {
                #expect(Bool(false))
            }
        }
    }

    @Test
    func testPrepareStreamedSaveCleansOnlyStaleTemporaryUploads() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AndroidMacNotifySharedFileStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let staleURL = directoryURL.appendingPathComponent(".AndroidMacNotify-stale.upload")
        let freshURL = directoryURL.appendingPathComponent(".AndroidMacNotify-fresh.upload")
        let unrelatedURL = directoryURL.appendingPathComponent("AndroidMacNotify-stale.upload")
        try Data("stale".utf8).write(to: staleURL)
        try Data("fresh".utf8).write(to: freshURL)
        try Data("unrelated".utf8).write(to: unrelatedURL)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -24 * 60 * 60)],
            ofItemAtPath: staleURL.path
        )

        let preparedSave = try SharedFileStore.prepareStreamedSave(
            fileName: "large.bin",
            directoryURL: directoryURL
        )

        #expect(FileManager.default.fileExists(atPath: staleURL.path) == false)
        #expect(FileManager.default.fileExists(atPath: freshURL.path))
        #expect(FileManager.default.fileExists(atPath: unrelatedURL.path))
        #expect(FileManager.default.fileExists(atPath: preparedSave.temporaryURL.path))
    }
}
