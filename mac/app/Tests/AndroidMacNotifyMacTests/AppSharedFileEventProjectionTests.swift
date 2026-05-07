import Testing
@testable import AndroidMacNotifyMac

struct AppSharedFileEventProjectionTests {
    @Test
    func testTransferUpdatedKeepsIncomingStatus() {
        let status = receiveStatus(stage: .receiving)

        let projection = AppSharedFileEventProjector.transferUpdated(status: status)

        #expect(projection.sharedFileReceiveStatus == status)
    }

    @Test
    func testReceivedFileBuildsReceiptSummaryAndRecentEntry() {
        let receipt = sharedFileReceipt(fileName: "photo.jpg", receivedAt: 100)

        let projection = AppSharedFileEventProjector.received(
            receipt: receipt,
            currentNotificationsReceived: 2,
            recentNotifications: [],
            transientActionSummaries: [:],
            now: 100
        )

        #expect(projection.sharedFileReceiveStatus == nil)
        #expect(projection.notificationsReceived == 3)
        #expect(projection.lastNotificationSummary == projection.summary)
        #expect(projection.summary.isSharedFileReceipt)
        #expect(projection.summary.title == "photo.jpg")
        #expect(projection.recentNotifications == [projection.summary])
        #expect(projection.transientActionSummaries.isEmpty)
        #expect(projection.transientNotifications.isEmpty)
        #expect(projection.actionFeedbackMessage == "已保存文件 photo.jpg")
    }

    @Test
    func testReceivedFileReplacesDuplicateRecentEntry() {
        let oldReceipt = sharedFileReceipt(shareId: "share-1", fileName: "old.jpg", receivedAt: 100)
        let newReceipt = sharedFileReceipt(shareId: "share-1", fileName: "new.jpg", receivedAt: 200)
        let oldSummary = SharedFileActionFactory.summary(from: oldReceipt)

        let projection = AppSharedFileEventProjector.received(
            receipt: newReceipt,
            currentNotificationsReceived: 1,
            recentNotifications: [oldSummary],
            transientActionSummaries: [:],
            now: 200
        )

        #expect(projection.notificationsReceived == 2)
        #expect(projection.recentNotifications == [projection.summary])
        #expect(projection.summary.title == "new.jpg")
    }

    @Test
    func testSharedFilePromptPolicyPublishesSingleFile() {
        let receipt = sharedFileReceipt(fileName: "photo.jpg", receivedAt: 100)

        #expect(AppSharedFilePromptPolicy.shouldPublishActionPrompt(for: receipt))
    }

    @Test
    func testSharedFilePromptPolicyWaitsForFinalBatchItem() {
        let first = sharedFileReceipt(
            shareId: "share-1",
            batchId: "batch-1",
            batchIndex: 0,
            batchTotal: 2,
            fileName: "first.jpg",
            receivedAt: 100
        )
        let second = sharedFileReceipt(
            shareId: "share-2",
            batchId: "batch-1",
            batchIndex: 1,
            batchTotal: 2,
            fileName: "second.jpg",
            receivedAt: 200
        )

        #expect(!AppSharedFilePromptPolicy.shouldPublishActionPrompt(for: first))
        #expect(AppSharedFilePromptPolicy.shouldPublishActionPrompt(for: second))
    }

    private func receiveStatus(stage: SharedFileReceiveStage) -> SharedFileReceiveStatus {
        SharedFileReceiveStatus(
            transferId: "share-1",
            batchId: nil,
            batchIndex: nil,
            batchTotal: nil,
            fileName: "photo.jpg",
            receivedBytes: stage == .receiving ? 50 : 10,
            totalBytes: 100,
            speedBytesPerSecond: 1_024,
            remainingSeconds: 1,
            stage: stage,
            message: nil,
            updatedAt: 100
        )
    }

    private func sharedFileReceipt(
        shareId: String = "share-1",
        batchId: String? = nil,
        batchIndex: Int? = nil,
        batchTotal: Int? = nil,
        fileName: String,
        receivedAt: Int64
    ) -> SharedFileReceipt {
        SharedFileReceipt(
            shareId: shareId,
            batchId: batchId,
            batchIndex: batchIndex,
            batchTotal: batchTotal,
            deviceId: "android-test",
            fileName: fileName,
            savedPath: "/Users/test/Downloads/Android Mac Notify/\(fileName)",
            size: 1_024,
            receivedAt: receivedAt
        )
    }
}
