package com.vainve.androidmacnotify.ui.transfer

import com.vainve.androidmacnotify.data.MacReachabilityStatus
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class SharedFileDeliveryItemSenderTest {
    @Test
    fun successfulSendReturnsPayloadAndResponseWithoutRecordingTerminalState() = runBlocking {
        val harness = SharedFileDeliveryStateHarness()
        val client = FakeSharedFileDeliveryTransferClient()
        val sender = sender(client, harness)
        val selection = testSelection("note.txt")

        val result = sender.send(request(selection))

        assertTrue(result is SharedFileDeliveryItemResult.Success)
        assertEquals(FakeSendCall("192.168.1.2", 38471, "device-token"), client.sendCalls.single())
        assertEquals("正在发送 0%...", harness.state.sharedFileStatus)
        assertTrue(harness.records.isEmpty())
        assertTrue(harness.reachabilityUpdates.isEmpty())
    }

    @Test
    fun securityFailureDuringPayloadBuildRequiresReselectionAndNoRetry() = runBlocking {
        val harness = SharedFileDeliveryStateHarness()
        val client = FakeSharedFileDeliveryTransferClient().apply {
            buildFailure = SecurityException("permission expired")
        }
        val sender = sender(client, harness)
        val selection = testSelection("locked.txt")

        val result = sender.send(request(selection, retryFrom = listOf(selection)))

        assertTrue(result is SharedFileDeliveryItemResult.Failed)
        assertTrue((result as SharedFileDeliveryItemResult.Failed).retrySelections.isEmpty())
        assertEquals(SharedFileDeliveryStage.Failed, harness.state.sharedFileTransfer?.stage)
        assertEquals("原文件权限已失效，请重新从系统分享菜单或文件页选择文件。", harness.state.sharedFileStatus)
        assertTrue(harness.records.isEmpty())
    }

    @Test
    fun pausedMacFailureKeepsRetryAndUpdatesReachability() = runBlocking {
        val harness = SharedFileDeliveryStateHarness()
        val client = FakeSharedFileDeliveryTransferClient().apply {
            sendResults += Result.failure(
                relayError(
                    statusCode = 409,
                    code = "MAC_RECEIVER_PAUSED",
                    retryable = true,
                )
            )
        }
        val sender = sender(client, harness)
        val current = testSelection("second.txt")
        val retryFrom = listOf(current, testSelection("third.txt"))

        val result = sender.send(
            request(
                selection = current,
                totalCount = 3,
                completedCount = 1,
                currentIndex = 1,
                retryFrom = retryFrom,
            )
        )

        assertTrue(result is SharedFileDeliveryItemResult.Failed)
        assertEquals(retryFrom, (result as SharedFileDeliveryItemResult.Failed).retrySelections)
        assertEquals(MacReachabilityStatus.MacPaused, harness.reachabilityUpdates.single().first)
        assertTrue(harness.records.isEmpty())
    }

    private fun sender(
        client: FakeSharedFileDeliveryTransferClient,
        harness: SharedFileDeliveryStateHarness,
    ): SharedFileDeliveryItemSender {
        return SharedFileDeliveryItemSender(
            transferClient = client,
            uiUpdater = harness.uiUpdater,
            onMacReachabilityChanged = harness::updateReachability,
        )
    }

    private fun request(
        selection: SharedFileSelection,
        totalCount: Int = 1,
        completedCount: Int = 0,
        currentIndex: Int = 0,
        retryFrom: List<SharedFileSelection> = listOf(selection),
    ): SharedFileDeliveryItemRequest {
        return SharedFileDeliveryItemRequest(
            selection = selection,
            transferId = "share-item",
            batchId = "share-batch",
            allSelections = retryFrom,
            target = SharedFileDeliveryTarget(
                host = "192.168.1.2",
                port = 38471,
                deviceToken = "device-token",
                deviceId = "android-device",
            ),
            cancelToken = SharedFileTransferCancelToken(),
            totalCount = totalCount,
            completedCount = completedCount,
            currentIndex = currentIndex,
            retryFrom = retryFrom,
        )
    }
}
