package com.vainve.androidmacnotify.ui.transfer

import com.vainve.androidmacnotify.data.MacReachabilityStatus
import com.vainve.androidmacnotify.data.SharedFileDeliveryRecordStatus
import com.vainve.androidmacnotify.ui.PairingUiState
import java.io.IOException
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class SharedFileDeliverySessionRunnerTest {
    @Test
    fun successfulBatchRecordsOneSuccessAndClearsRetrySelections() = runBlocking {
        val harness = SharedFileDeliveryStateHarness()
        val client = FakeSharedFileDeliveryTransferClient(
            generatedTransferIds = mutableListOf("share-first", "share-second"),
        )
        client.sendResults += Result.success(testResponse(fileName = "first.txt", shareId = "share-first", size = 100))
        client.sendResults += Result.success(testResponse(fileName = "second.txt", shareId = "share-second", size = 200))
        val runner = runner(client, harness)
        val selections = listOf(testSelection("first.txt", 100), testSelection("second.txt", 200))

        val result = runner.run(
            selections = selections,
            batchId = "share-batch",
            cancelToken = SharedFileTransferCancelToken(),
        )

        assertTrue(result.retrySelections.isEmpty())
        assertEquals(SharedFileDeliveryStage.Success, harness.state.sharedFileTransfer?.stage)
        assertEquals(SharedFileDeliveryRecordStatus.Success, harness.records.single().status)
        assertEquals(2, harness.records.single().completedCount)
        assertEquals(300L, harness.records.single().totalBytes)
        assertEquals(
            listOf(MacReachabilityStatus.Reachable, MacReachabilityStatus.Reachable),
            harness.reachabilityUpdates.map { it.first },
        )
    }

    @Test
    fun batchFailureAfterPartialSuccessRetriesFromFailedItem() = runBlocking {
        val harness = SharedFileDeliveryStateHarness()
        val client = FakeSharedFileDeliveryTransferClient(
            generatedTransferIds = mutableListOf("share-first", "share-second"),
        )
        client.sendResults += Result.success(testResponse(fileName = "first.txt", shareId = "share-first", size = 100))
        client.sendResults += Result.failure(IOException("network down"))
        val runner = runner(client, harness)
        val first = testSelection("first.txt", 100)
        val second = testSelection("second.txt", 200)
        val third = testSelection("third.txt", 300)

        val result = runner.run(
            selections = listOf(first, second, third),
            batchId = "share-batch",
            cancelToken = SharedFileTransferCancelToken(),
        )

        assertEquals(listOf(second, third), result.retrySelections)
        assertEquals(SharedFileDeliveryStage.Failed, harness.state.sharedFileTransfer?.stage)
        assertEquals(SharedFileDeliveryRecordStatus.Failed, harness.records.single().status)
        assertEquals(1, harness.records.single().completedCount)
        assertEquals(2, harness.records.single().sourceUris.size)
    }

    @Test
    fun singleFileSaveFailureContinuesBatchAndRetriesOnlyFailedItem() = runBlocking {
        val harness = SharedFileDeliveryStateHarness()
        val client = FakeSharedFileDeliveryTransferClient(
            generatedTransferIds = mutableListOf("share-first", "share-second", "share-third"),
        )
        client.sendResults += Result.success(testResponse(fileName = "first.txt", shareId = "share-first", size = 100))
        client.sendResults += Result.failure(relayError(statusCode = 500, code = "FILE_SAVE_FAILED", retryable = true))
        client.sendResults += Result.success(testResponse(fileName = "third.txt", shareId = "share-third", size = 300))
        val runner = runner(client, harness)
        val first = testSelection("first.txt", 100)
        val second = testSelection("second.txt", 200)
        val third = testSelection("third.txt", 300)

        val result = runner.run(
            selections = listOf(first, second, third),
            batchId = "share-batch",
            cancelToken = SharedFileTransferCancelToken(),
        )

        assertEquals(listOf(second), result.retrySelections)
        assertEquals(3, client.sendCalls.size)
        assertEquals(SharedFileDeliveryStage.Failed, harness.state.sharedFileTransfer?.stage)
        assertEquals(2, harness.state.sharedFileTransfer?.batchCompletedCount)
        assertEquals(1, harness.state.sharedFileTransfer?.batchFailedCount)
        assertEquals(SharedFileDeliveryRecordStatus.Failed, harness.records.single().status)
        assertEquals(2, harness.records.single().completedCount)
        assertEquals(listOf(second.uri.toString()), harness.records.single().sourceUris)
    }

    @Test
    fun preflightFailureRecordsFailureWithoutStartingSend() = runBlocking {
        val harness = SharedFileDeliveryStateHarness(
            initialState = PairingUiState(
                relayEnabled = false,
                sharedFileTransfer = testTransferUi(),
            )
        )
        val client = FakeSharedFileDeliveryTransferClient()
        val runner = runner(client, harness)
        val selection = testSelection("first.txt")

        val result = runner.run(
            selections = listOf(selection),
            batchId = "share-batch",
            cancelToken = SharedFileTransferCancelToken(),
        )

        assertEquals(listOf(selection), result.retrySelections)
        assertTrue(client.sendCalls.isEmpty())
        assertEquals(SharedFileDeliveryStage.Failed, harness.state.sharedFileTransfer?.stage)
        assertEquals(SharedFileDeliveryRecordStatus.Failed, harness.records.single().status)
        assertTrue(harness.records.single().canRetry)
    }

    private fun runner(
        client: FakeSharedFileDeliveryTransferClient,
        harness: SharedFileDeliveryStateHarness,
    ): SharedFileDeliverySessionRunner {
        return SharedFileDeliverySessionRunner(
            transferClient = client,
            readState = { harness.state },
            updateState = { reducer -> harness.state = reducer(harness.state) },
            uiUpdater = harness.uiUpdater,
            deliveryRecorder = harness.recorder,
            onMacReachabilityChanged = harness::updateReachability,
        )
    }
}
