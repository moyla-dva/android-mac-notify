import Foundation
import Testing
@testable import AndroidMacNotifyMac

struct SharedFileActionFactoryTests {
    @Test
    func testSharedFileReceiptBuildsRecentActivityActions() {
        let receipt = SharedFileReceipt(
            shareId: "share-test",
            deviceId: "android-test",
            fileName: "photo.jpg",
            savedPath: "/Users/test/Downloads/Android Mac Notify/photo.jpg",
            size: 1_024,
            receivedAt: 1_777_902_000_000
        )

        let summary = SharedFileActionFactory.summary(from: receipt)

        #expect(summary.eventId == "shared_file_share-test")
        #expect(summary.title == "photo.jpg")
        #expect(summary.text.contains(receipt.savedPath))
        #expect(summary.ruleDecision.reasonCodes.contains("shared_file_received"))
        #expect(summary.ruleDecision.reasonCodes.contains("file_saved_to_mac_directory"))
        #expect(summary.ruleDecision.primarySurface == .history)
        #expect(summary.ruleDecision.secondarySurfaces == [])
        #expect(summary.routesToHistory)
        #expect(!summary.routesToActionInbox)
        #expect(summary.visibleActionCandidates.map(\.kind) == [.openFile, .revealFile, .copyFilePath])
        #expect(summary.routingExplanation?.text == "文件已保存，可直接在 Mac 打开或定位")
        #expect(NotificationHistoryPolicy.shouldPersist(summary, now: receipt.receivedAt))
    }

    @Test
    func testSharedFileReceiptMarksAutomaticRename() {
        let receipt = SharedFileReceipt(
            shareId: "share-test",
            deviceId: "android-test",
            originalFileName: "photo.jpg",
            fileName: "photo 2.jpg",
            savedPath: "/Users/test/Downloads/Android Mac Notify/photo 2.jpg",
            size: 1_024,
            receivedAt: 1_777_902_000_000
        )

        let summary = SharedFileActionFactory.summary(from: receipt)

        #expect(summary.title == "photo 2.jpg")
        #expect(summary.sharedFileWasSavedWithNewName)
        #expect(summary.ruleDecision.reasonCodes.contains("shared_file_saved_with_new_name"))
    }

    @Test
    func testSharedFileDeliveryGroupsMergeNearbyFilesFromSameDevice() {
        let first = summary(
            shareId: "share-1",
            deviceId: "android-test",
            fileName: "first.jpg",
            receivedAt: 10_000
        )
        let second = summary(
            shareId: "share-2",
            deviceId: "android-test",
            fileName: "second.jpg",
            receivedAt: 6_500
        )
        let later = summary(
            shareId: "share-3",
            deviceId: "android-test",
            fileName: "later.jpg",
            receivedAt: 1_000
        )

        let groups = SharedFileDeliveryGroup.groups(
            from: [later, second, first],
            mergeWindowMillis: 8_000
        )

        #expect(groups.count == 2)
        #expect(groups[0].fileCount == 2)
        #expect(groups[0].summaries.map(\.title) == ["first.jpg", "second.jpg"])
        #expect(groups[1].fileCount == 1)
        #expect(groups[1].latestSummary.title == "later.jpg")
    }

    @Test
    func testSharedFileDeliveryGroupsPreferExplicitBatchMetadata() {
        let first = summary(
            shareId: "share-1",
            batchId: "batch-1",
            batchIndex: 0,
            batchTotal: 2,
            deviceId: "android-test",
            fileName: "first.jpg",
            receivedAt: 30_000
        )
        let second = summary(
            shareId: "share-2",
            batchId: "batch-1",
            batchIndex: 1,
            batchTotal: 2,
            deviceId: "android-test",
            fileName: "second.jpg",
            receivedAt: 10_000
        )

        let groups = SharedFileDeliveryGroup.groups(
            from: [second, first],
            mergeWindowMillis: 8_000
        )

        #expect(groups.count == 1)
        #expect(groups[0].fileCount == 2)
        #expect(groups[0].batchId == "batch-1")
        #expect(groups[0].summaries.map(\.title) == ["first.jpg", "second.jpg"])
        #expect(groups[0].savedFilePaths == [
            "/Users/test/Downloads/Android Mac Notify/first.jpg",
            "/Users/test/Downloads/Android Mac Notify/second.jpg",
        ])
    }

    @Test
    func testSharedFileDeliveryGroupsDoNotMergeDifferentDevices() {
        let first = summary(
            shareId: "share-1",
            deviceId: "android-a",
            fileName: "a.jpg",
            receivedAt: 10_000
        )
        let second = summary(
            shareId: "share-2",
            deviceId: "android-b",
            fileName: "b.jpg",
            receivedAt: 9_500
        )

        let groups = SharedFileDeliveryGroup.groups(
            from: [second, first],
            mergeWindowMillis: 8_000
        )

        #expect(groups.count == 2)
        #expect(groups.map(\.fileCount) == [1, 1])
    }

    @Test
    func testSharedFileDeliveryGroupsHideActiveReceivingBatch() {
        let first = summary(
            shareId: "share-1",
            batchId: "batch-1",
            batchIndex: 0,
            batchTotal: 2,
            deviceId: "android-test",
            fileName: "first.jpg",
            receivedAt: 30_000
        )
        let other = summary(
            shareId: "share-other",
            batchId: "batch-2",
            batchIndex: 0,
            batchTotal: 1,
            deviceId: "android-test",
            fileName: "other.jpg",
            receivedAt: 20_000
        )
        let activeStatus = SharedFileReceiveStatus(
            transferId: "share-2",
            batchId: "batch-1",
            batchIndex: 1,
            batchTotal: 2,
            fileName: "second.jpg",
            receivedBytes: 512,
            totalBytes: 1_024,
            speedBytesPerSecond: nil,
            remainingSeconds: nil,
            stage: .receiving,
            message: nil,
            updatedAt: 31_000
        )

        let groups = SharedFileDeliveryGroup.visibleGroups(
            from: [first, other],
            activeReceiveStatus: activeStatus
        )

        #expect(groups.count == 1)
        #expect(groups[0].batchId == "batch-2")
    }

    @Test
    func testSharedFileDeliveryGroupsShowFailedActiveBatch() {
        let first = summary(
            shareId: "share-1",
            batchId: "batch-1",
            batchIndex: 0,
            batchTotal: 2,
            deviceId: "android-test",
            fileName: "first.jpg",
            receivedAt: 30_000
        )
        let failedStatus = SharedFileReceiveStatus(
            transferId: "share-2",
            batchId: "batch-1",
            batchIndex: 1,
            batchTotal: 2,
            fileName: "second.jpg",
            receivedBytes: 512,
            totalBytes: 1_024,
            speedBytesPerSecond: nil,
            remainingSeconds: nil,
            stage: .failed,
            message: "接收中断",
            updatedAt: 31_000
        )

        let groups = SharedFileDeliveryGroup.visibleGroups(
            from: [first],
            activeReceiveStatus: failedStatus
        )

        #expect(groups.count == 1)
        #expect(groups[0].batchId == "batch-1")
    }

    private func summary(
        shareId: String,
        batchId: String? = nil,
        batchIndex: Int? = nil,
        batchTotal: Int? = nil,
        deviceId: String,
        fileName: String,
        receivedAt: Int64
    ) -> LocalNotificationSummary {
        SharedFileActionFactory.summary(
            from: SharedFileReceipt(
                shareId: shareId,
                batchId: batchId,
                batchIndex: batchIndex,
                batchTotal: batchTotal,
                deviceId: deviceId,
                fileName: fileName,
                savedPath: "/Users/test/Downloads/Android Mac Notify/\(fileName)",
                size: 1_024,
                receivedAt: receivedAt
            )
        )
    }
}
