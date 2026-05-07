import Testing
@testable import AndroidMacNotifyMac

struct SharedFileReceiveStatusTests {
    @Test
    func testBatchPositionTextUsesOneBasedDisplayIndex() {
        let status = SharedFileReceiveStatus(
            transferId: "share-2",
            batchId: "batch-1",
            batchIndex: 1,
            batchTotal: 6,
            fileName: "photo.jpg",
            receivedBytes: 10,
            totalBytes: 100,
            speedBytesPerSecond: nil,
            remainingSeconds: nil,
            stage: .receiving,
            message: nil,
            updatedAt: 1
        )

        #expect(status.batchPositionText == "第 2 / 6 个")
    }

    @Test
    func testBatchPositionTextIgnoresSingleOrInvalidBatchMetadata() {
        let singleFile = SharedFileReceiveStatus(
            transferId: "share-single",
            batchId: nil,
            batchIndex: nil,
            batchTotal: nil,
            fileName: "note.txt",
            receivedBytes: 10,
            totalBytes: 100,
            speedBytesPerSecond: nil,
            remainingSeconds: nil,
            stage: .receiving,
            message: nil,
            updatedAt: 1
        )
        let invalidIndex = SharedFileReceiveStatus(
            transferId: "share-invalid",
            batchId: "batch-1",
            batchIndex: 6,
            batchTotal: 6,
            fileName: "photo.jpg",
            receivedBytes: 10,
            totalBytes: 100,
            speedBytesPerSecond: nil,
            remainingSeconds: nil,
            stage: .receiving,
            message: nil,
            updatedAt: 1
        )

        #expect(singleFile.batchPositionText == nil)
        #expect(invalidIndex.batchPositionText == nil)
    }
}
