import Foundation
import Testing
@testable import AndroidMacNotifyMac

struct LocalShareFileUploadDecoderTests {
    @Test
    func testDecodesStreamedUploadMetadataWithBatchHeaders() throws {
        let decoder = LocalShareFileUploadDecoder()
        let head = HTTPRequestHead(
            method: "POST",
            target: "/api/v1/share/file",
            path: "/api/v1/share/file",
            queryItems: [:],
            headers: [
                "x-amn-device-id": "android-test",
                "x-amn-share-id": "share-stream",
                "x-amn-file-name-b64": Data("截图 1.png".utf8).base64EncodedString(),
                "x-amn-mime-type": "image/png",
                "x-amn-shared-at": "123",
                "x-amn-batch-id": "batch-1",
                "x-amn-batch-index": "1",
                "x-amn-batch-total": "3",
            ],
            contentLength: 2048,
            initialBody: Data()
        )

        let metadata = try decoder.decodeStreamedMetadata(from: head)

        #expect(metadata.deviceId == "android-test")
        #expect(metadata.shareId == "share-stream")
        #expect(metadata.fileName == "截图 1.png")
        #expect(metadata.mimeType == "image/png")
        #expect(metadata.size == 2048)
        #expect(metadata.batchId == "batch-1")
        #expect(metadata.batchIndex == 1)
        #expect(metadata.batchTotal == 3)
    }

    @Test
    func testRejectsPartialBatchMetadata() {
        let decoder = LocalShareFileUploadDecoder()
        let head = HTTPRequestHead(
            method: "POST",
            target: "/api/v1/share/file",
            path: "/api/v1/share/file",
            queryItems: [:],
            headers: [
                "x-amn-device-id": "android-test",
                "x-amn-share-id": "share-stream",
                "x-amn-file-name-b64": Data("note.txt".utf8).base64EncodedString(),
                "x-amn-shared-at": "123",
                "x-amn-batch-id": "batch-1",
            ],
            contentLength: 10,
            initialBody: Data()
        )

        do {
            _ = try decoder.decodeStreamedMetadata(from: head)
            #expect(Bool(false))
        } catch let error as ShareFileUploadError {
            if case .invalidField("x-amn-batch-*") = error {
                #expect(Bool(true))
            } else {
                #expect(Bool(false))
            }
        } catch {
            #expect(Bool(false))
        }
    }
}
