package com.vainve.androidmacnotify.ui.transfer

import android.util.Log
import com.vainve.androidmacnotify.data.MacReachabilityStatus
import com.vainve.androidmacnotify.network.SharedFileRelayPayload
import com.vainve.androidmacnotify.network.SharedFileRelayResponse
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

internal data class SharedFileDeliveryItemRequest(
    val selection: SharedFileSelection,
    val transferId: String,
    val batchId: String,
    val allSelections: List<SharedFileSelection>,
    val target: SharedFileDeliveryTarget,
    val cancelToken: SharedFileTransferCancelToken,
    val totalCount: Int,
    val completedCount: Int,
    val currentIndex: Int,
    val retryFrom: List<SharedFileSelection>,
)

internal sealed class SharedFileDeliveryItemResult {
    data class Success(
        val payload: SharedFileRelayPayload,
        val response: SharedFileRelayResponse,
    ) : SharedFileDeliveryItemResult()

    data class Failed(
        val retrySelections: List<SharedFileSelection>,
        val stage: SharedFileDeliveryStage,
        val message: String,
        val canRetry: Boolean,
        val failedCount: Int,
        val shouldStopBatch: Boolean,
    ) : SharedFileDeliveryItemResult()
}

internal class SharedFileDeliveryItemSender(
    private val transferClient: SharedFileDeliveryTransferClient,
    private val uiUpdater: SharedFileDeliveryUiUpdater,
    private val onMacReachabilityChanged: (MacReachabilityStatus, String?) -> Unit,
) {
    suspend fun send(request: SharedFileDeliveryItemRequest): SharedFileDeliveryItemResult {
        uiUpdater.updatePreparingState(
            selection = request.selection,
            transferId = request.transferId,
            totalCount = request.totalCount,
            completedCount = request.completedCount,
            currentIndex = request.currentIndex,
        )

        val payload = when (val payloadResult = buildPayload(request)) {
            is SharedFilePayloadBuildResult.Ready -> payloadResult.payload
            is SharedFilePayloadBuildResult.Failed -> {
                return SharedFileDeliveryItemResult.Failed(
                    retrySelections = payloadResult.retrySelections,
                    stage = payloadResult.stage,
                    message = payloadResult.message,
                    canRetry = payloadResult.canRetry,
                    failedCount = payloadResult.failedCount,
                    shouldStopBatch = payloadResult.shouldStopBatch,
                )
            }
        }

        uiUpdater.updateSendingState(
            payload = payload,
            transferId = request.transferId,
            totalCount = request.totalCount,
            completedCount = request.completedCount,
            currentIndex = request.currentIndex,
            sentBytes = 0,
            progressPercent = 0,
            speedBytesPerSecond = null,
            remainingSeconds = null,
            cancelToken = request.cancelToken,
        )

        val result = withContext(Dispatchers.IO) {
            transferClient.sendPayload(
                host = request.target.host,
                port = request.target.port,
                deviceToken = request.target.deviceToken,
                payload = payload,
            )
        }

        return result.fold(
            onSuccess = { response ->
                SharedFileDeliveryItemResult.Success(
                    payload = payload,
                    response = response,
                )
            },
            onFailure = { error ->
                Log.e("AndroidMacNotify", "File delivery failed", error)
                val failure = SharedFileDeliveryFailurePolicy.forRelayFailure(
                    error = error,
                    cancelToken = request.cancelToken,
                )
                failure.reachabilityUpdate?.let(::recordMacReachability)
                uiUpdater.updateTerminalFailureState(
                    selection = request.selection,
                    transferId = request.transferId,
                    totalCount = request.totalCount,
                    completedCount = request.completedCount,
                    failedCount = failure.failedCount,
                    currentIndex = request.currentIndex,
                    stage = failure.stage,
                    message = failure.message,
                    canRetry = failure.canRetry,
                )
                SharedFileDeliveryItemResult.Failed(
                    retrySelections = request.retryFrom.takeIf { failure.canRetry }.orEmpty(),
                    stage = failure.stage,
                    message = failure.message,
                    canRetry = failure.canRetry,
                    failedCount = failure.failedCount,
                    shouldStopBatch = failure.shouldStopBatch,
                )
            },
        )
    }

    private suspend fun buildPayload(
        request: SharedFileDeliveryItemRequest,
    ): SharedFilePayloadBuildResult {
        val progressReporter = SharedFileTransferProgressReporter { progress ->
            uiUpdater.updateProgressState(
                selection = request.selection,
                transferId = request.transferId,
                totalCount = request.totalCount,
                completedCount = request.completedCount,
                currentIndex = request.currentIndex,
                sentBytes = progress.sentBytes,
                totalBytes = progress.totalBytes,
                speedBytesPerSecond = progress.speedBytesPerSecond,
                remainingSeconds = progress.remainingSeconds,
                progressPercent = progress.progressPercent,
                cancelToken = request.cancelToken,
            )
        }

        val payloadResult = withContext(Dispatchers.IO) {
            runCatching {
                transferClient.buildPayload(
                    uri = request.selection.uri,
                    deviceId = request.target.deviceId,
                    shareId = request.transferId,
                    batchId = request.batchId.takeIf { request.totalCount > 1 },
                    batchIndex = request.currentIndex.takeIf { request.totalCount > 1 },
                    batchTotal = request.totalCount.takeIf { request.totalCount > 1 },
                    cancelToken = request.cancelToken,
                    onProgress = progressReporter::report,
                )
            }
        }

        return payloadResult.fold(
            onSuccess = { SharedFilePayloadBuildResult.Ready(it) },
            onFailure = { error ->
                Log.e("AndroidMacNotify", "Build shared file payload failed", error)
                val failure = SharedFileDeliveryFailurePolicy.forPayloadBuildFailure(
                    error = error,
                    cancelToken = request.cancelToken,
                )
                uiUpdater.updateTerminalFailureState(
                    selection = request.selection,
                    transferId = request.transferId,
                    totalCount = request.totalCount,
                    completedCount = request.completedCount,
                    failedCount = failure.failedCount,
                    currentIndex = request.currentIndex,
                    stage = failure.stage,
                    message = failure.message,
                    canRetry = failure.canRetry,
                )
                SharedFilePayloadBuildResult.Failed(
                    retrySelections = request.retryFrom.takeIf { failure.canRetry }.orEmpty(),
                    stage = failure.stage,
                    message = failure.message,
                    canRetry = failure.canRetry,
                    failedCount = failure.failedCount,
                    shouldStopBatch = failure.shouldStopBatch,
                )
            },
        )
    }

    private fun recordMacReachability(update: SharedFileMacReachabilityUpdate) {
        onMacReachabilityChanged(update.status, update.message)
    }

    private sealed class SharedFilePayloadBuildResult {
        data class Ready(val payload: SharedFileRelayPayload) : SharedFilePayloadBuildResult()
        data class Failed(
            val retrySelections: List<SharedFileSelection>,
            val stage: SharedFileDeliveryStage,
            val message: String,
            val canRetry: Boolean,
            val failedCount: Int,
            val shouldStopBatch: Boolean,
        ) : SharedFilePayloadBuildResult()
    }
}
