import Testing
@testable import AndroidMacNotifyMac

struct SharedFileAppStateProjectionTests {
    @Test
    func testSharedFileReceiptsCarryDedicatedProjectionMarker() {
        let fileSummary = SharedFileActionFactory.summary(
            from: SharedFileReceipt(
                shareId: "share-projection",
                deviceId: "android-test",
                fileName: "photo.jpg",
                savedPath: "/Users/test/Downloads/Android Mac Notify/photo.jpg",
                size: 1_024,
                receivedAt: 1
            )
        )

        #expect(fileSummary.isSharedFileReceipt)
        #expect(SharedFileDeliveryGroup.groups(from: [fileSummary]).count == 1)
    }
}
