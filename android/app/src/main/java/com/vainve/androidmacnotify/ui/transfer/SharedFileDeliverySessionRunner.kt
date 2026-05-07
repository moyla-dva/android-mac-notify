package com.vainve.androidmacnotify.ui.transfer

import com.vainve.androidmacnotify.data.MacReachabilityStatus
import com.vainve.androidmacnotify.data.SharedFileDeliveryRecordStatus
import com.vainve.androidmacnotify.network.SharedFileRelayResponse
import com.vainve.androidmacnotify.ui.PairingUiState

internal data class SharedFileDeliverySessionResult(
    val retrySelections: List<SharedFileSelection>,
)

internal class SharedFileDeliverySessionRunner(
    private val transferClient: SharedFileDeliveryTransferClient,
    private val readState: () -> PairingUiState,
    private val updateState: ((PairingUiState) -> PairingUiState) -> Unit,
    private val uiUpdater: SharedFileDeliveryUiUpdater,
    private val deliveryRecorder: SharedFileDeliveryRecorder,
    private val onMacReachabilityChanged: (MacReachabilityStatus, String?) -> Unit,
) {
    private val itemSender = SharedFileDeliveryItemSender(
        transferClient = transferClient,
        uiUpdater = uiUpdater,
        onMacReachabilityChanged = onMacReachabilityChanged,
    )

    suspend fun run(
        selections: List<SharedFileSelection>,
        batchId: String,
        cancelToken: SharedFileTransferCancelToken,
    ): SharedFileDeliverySessionResult {
        val snapshot = readState()
        val target = when (val preflight = SharedFileDeliveryPreflight.check(snapshot)) {
            is SharedFileDeliveryPreflightResult.Ready -> preflight.target
            is SharedFileDeliveryPreflightResult.Failed -> {
                failBeforeSending(
                    selections = selections,
                    batchId = batchId,
                    message = preflight.message,
                    canRetry = preflight.canRetry,
                )
                return SharedFileDeliverySessionResult(
                    retrySelections = selections.takeIf { preflight.canRetry }.orEmpty(),
                )
            }
        }

        updateState {
            it.copy(isSendingSharedFile = true)
        }

        val totalCount = selections.size
        var completedCount = 0
        var completedBytes = 0L
        val completedResponses = mutableListOf<SharedFileRelayResponse>()
        val failedRetrySelections = mutableListOf<SharedFileSelection>()
        var failedCount = 0
        var lastFailure: SharedFileDeliveryItemResult.Failed? = null

        selections.forEachIndexed { index, selection ->
            val retryFromCurrent = remainingItemsForRetry(
                items = selections,
                currentIndex = index,
                includeCurrent = true,
            )
            val transferId = if (totalCount == 1) batchId else transferClient.createTransferId()
            when (
                val itemResult = itemSender.send(
                    SharedFileDeliveryItemRequest(
                        selection = selection,
                        transferId = transferId,
                        batchId = batchId,
                        allSelections = selections,
                        target = target,
                        cancelToken = cancelToken,
                        totalCount = totalCount,
                        completedCount = completedCount,
                        currentIndex = index,
                        retryFrom = retryFromCurrent,
                    )
                )
            ) {
                is SharedFileDeliveryItemResult.Failed -> {
                    if (totalCount == 1 || itemResult.shouldStopBatch) {
                        deliveryRecorder.record(
                            recordId = batchId,
                            selections = selections,
                            completedCount = completedCount,
                            status = if (itemResult.stage == SharedFileDeliveryStage.Cancelled) {
                                SharedFileDeliveryRecordStatus.Cancelled
                            } else {
                                SharedFileDeliveryRecordStatus.Failed
                            },
                            message = itemResult.message,
                            canRetry = itemResult.canRetry,
                            retrySelections = itemResult.retrySelections,
                        )
                        return SharedFileDeliverySessionResult(itemResult.retrySelections)
                    }

                    failedCount += itemResult.failedCount.coerceAtLeast(1)
                    lastFailure = itemResult
                    if (itemResult.canRetry) {
                        failedRetrySelections += selection
                    }
                }
                is SharedFileDeliveryItemResult.Success -> {
                    onMacReachabilityChanged(MacReachabilityStatus.Reachable, null)
                    completedCount += 1
                    completedBytes += itemResult.response.size
                    completedResponses += itemResult.response
                    uiUpdater.updateFileCompletedState(
                        payload = itemResult.payload,
                        response = itemResult.response,
                        transferId = transferId,
                        totalCount = totalCount,
                        completedCount = completedCount,
                        currentIndex = index,
                    )
                }
            }

            if (cancelToken.isCancelled) {
                val retryAfterCompletedCurrent = remainingItemsForRetry(
                    items = selections,
                    currentIndex = index,
                    includeCurrent = false,
                )
                uiUpdater.updateTerminalFailureState(
                    selection = selection,
                    transferId = transferId,
                    totalCount = totalCount,
                    completedCount = completedCount,
                    failedCount = 0,
                    currentIndex = index,
                    stage = SharedFileDeliveryStage.Cancelled,
                    message = cancelledMessage,
                    canRetry = true,
                )
                deliveryRecorder.record(
                    recordId = batchId,
                    selections = selections,
                    completedCount = completedCount,
                    status = SharedFileDeliveryRecordStatus.Cancelled,
                    message = cancelledMessage,
                    canRetry = true,
                    retrySelections = retryAfterCompletedCurrent,
                )
                return SharedFileDeliverySessionResult(
                    retrySelections = retryAfterCompletedCurrent,
                )
            }
        }

        if (failedCount > 0) {
            val partialFailureMessage = partialFailureMessage(
                completedCount = completedCount,
                totalCount = totalCount,
                failedCount = failedCount,
                fallbackMessage = lastFailure?.message,
            )
            uiUpdater.updateBatchPartialFailureState(
                batchId = batchId,
                selections = selections,
                completedCount = completedCount,
                failedCount = failedCount,
                message = partialFailureMessage,
                canRetry = failedRetrySelections.isNotEmpty(),
            )
            deliveryRecorder.record(
                recordId = batchId,
                selections = selections,
                completedCount = completedCount,
                totalBytes = completedBytes.takeIf { it > 0L },
                status = SharedFileDeliveryRecordStatus.Failed,
                message = partialFailureMessage,
                canRetry = failedRetrySelections.isNotEmpty(),
                retrySelections = failedRetrySelections,
            )
            return SharedFileDeliverySessionResult(
                retrySelections = failedRetrySelections,
            )
        }

        val successSummary = uiUpdater.updateBatchSuccessState(
            batchId = batchId,
            selections = selections,
            responses = completedResponses,
            completedBytes = completedBytes,
        )
        deliveryRecorder.record(
            recordId = batchId,
            selections = selections,
            completedCount = totalCount,
            totalBytes = completedBytes.takeIf { it > 0L },
            status = SharedFileDeliveryRecordStatus.Success,
            message = successSummary.message,
            displayFileName = successSummary.displayFileName,
        )

        return SharedFileDeliverySessionResult(retrySelections = emptyList())
    }

    private fun failBeforeSending(
        selections: List<SharedFileSelection>,
        batchId: String,
        message: String,
        canRetry: Boolean,
    ) {
        uiUpdater.showFailureBeforeSending(
            selections = selections,
            batchId = batchId,
            message = message,
            canRetry = canRetry,
        )
        deliveryRecorder.record(
            recordId = batchId,
            selections = selections,
            completedCount = 0,
            status = SharedFileDeliveryRecordStatus.Failed,
            message = message,
            canRetry = canRetry,
            retrySelections = selections.takeIf { canRetry }.orEmpty(),
        )
    }

    private companion object {
        const val cancelledMessage = "已取消投递，未完成文件会被清理"

        fun partialFailureMessage(
            completedCount: Int,
            totalCount: Int,
            failedCount: Int,
            fallbackMessage: String?,
        ): String {
            return if (completedCount > 0) {
                "已完成 $completedCount / $totalCount 个文件，$failedCount 个文件未投递。"
            } else {
                fallbackMessage ?: "部分文件投递失败，请重试。"
            }
        }
    }
}
