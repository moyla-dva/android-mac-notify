package com.vainve.androidmacnotify.ui.transfer

import com.vainve.androidmacnotify.network.SharedFileRelayPayload
import com.vainve.androidmacnotify.network.SharedFileRelayResponse
import com.vainve.androidmacnotify.ui.PairingUiState
import com.vainve.androidmacnotify.ui.transfer.SharedFileDeliveryUiFormatting.batchFileName
import com.vainve.androidmacnotify.ui.transfer.SharedFileDeliveryUiFormatting.batchMessage
import com.vainve.androidmacnotify.ui.transfer.SharedFileDeliveryUiFormatting.batchSizeLabel
import com.vainve.androidmacnotify.ui.transfer.SharedFileDeliveryUiFormatting.queueProgressPercent

internal class SharedFileDeliveryUiUpdater(
    private val updateState: ((PairingUiState) -> PairingUiState) -> Unit,
    private val targetName: (PairingUiState) -> String?,
    private val formatFileSize: (Long) -> String,
) {
    fun showFileSelectionAccessFailure() {
        val message = "无法读取原文件权限，请重新从系统分享菜单或文件页选择文件。"
        updateState {
            it.copy(
                sharedFileTransfer = SharedFileTransferUi(
                    fileName = "原文件无法访问",
                    sizeLabel = null,
                    targetName = targetName(it),
                    stage = SharedFileDeliveryStage.Failed,
                    message = message,
                    progressPercent = null,
                    canRetry = false,
                    canCancel = false,
                ),
                sharedFileStatus = message,
                isSendingSharedFile = false,
            )
        }
    }

    fun showNoFilesFound() {
        val message = "没有找到可投递的文件"
        updateState {
            it.copy(
                sharedFileTransfer = SharedFileTransferUi(
                    fileName = "未知文件",
                    sizeLabel = null,
                    targetName = targetName(it),
                    stage = SharedFileDeliveryStage.Failed,
                    message = message,
                    progressPercent = null,
                    canRetry = false,
                    canCancel = false,
                ),
                sharedFileStatus = message,
                isSendingSharedFile = false,
            )
        }
    }

    fun showReadingConfig(selections: List<SharedFileSelection>) {
        val firstSelection = selections.first()
        updateState {
            it.copy(
                sharedFileTransfer = SharedFileTransferUi(
                    fileName = firstSelection.fileName,
                    sizeLabel = firstSelection.sizeLabel,
                    targetName = targetName(it),
                    stage = SharedFileDeliveryStage.ReadingConfig,
                    message = if (selections.size == 1) {
                        "正在读取连接配置..."
                    } else {
                        "准备投递 ${selections.size} 个文件..."
                    },
                    progressPercent = null,
                    batchTotalCount = selections.size,
                    batchCompletedCount = 0,
                    batchFailedCount = 0,
                    batchCurrentIndex = 0,
                    canRetry = false,
                    canCancel = false,
                ),
                sharedFileStatus = "正在读取连接配置...",
                isSendingSharedFile = false,
            )
        }
    }

    fun showCancelling() {
        updateState {
            it.copy(
                isSendingSharedFile = true,
                sharedFileTransfer = it.sharedFileTransfer?.copy(
                    targetName = targetName(it),
                    stage = SharedFileDeliveryStage.Cancelling,
                    message = "正在取消投递...",
                    canCancel = false,
                    canRetry = false,
                ),
                sharedFileStatus = "正在取消投递...",
            )
        }
    }

    fun showRetrying(retrySelections: List<SharedFileSelection>) {
        updateState {
            it.copy(
                sharedFileTransfer = it.sharedFileTransfer?.copy(
                    targetName = targetName(it),
                    stage = SharedFileDeliveryStage.ReadingConfig,
                    message = if (retrySelections.size == 1) {
                        "正在重新投递..."
                    } else {
                        "正在重新投递 ${retrySelections.size} 个文件..."
                    },
                    progressPercent = null,
                    sentBytes = null,
                    totalBytes = null,
                    speedBytesPerSecond = null,
                    remainingSeconds = null,
                    batchTotalCount = retrySelections.size,
                    batchCompletedCount = 0,
                    batchFailedCount = 0,
                    batchCurrentIndex = 0,
                    canRetry = false,
                    canCancel = false,
                ),
                sharedFileStatus = "正在重新投递...",
                isSendingSharedFile = false,
            )
        }
    }

    fun showFailureBeforeSending(
        selections: List<SharedFileSelection>,
        batchId: String,
        message: String,
        canRetry: Boolean,
    ) {
        val firstSelection = selections.first()
        updateState {
            it.copy(
                sharedFileTransfer = it.sharedFileTransfer?.copy(
                    fileName = batchFileName(firstSelection.fileName, selections.size),
                    sizeLabel = batchSizeLabel(firstSelection.sizeLabel, selections.size),
                    targetName = targetName(it),
                    transferId = batchId,
                    stage = SharedFileDeliveryStage.Failed,
                    message = message,
                    progressPercent = null,
                    sentBytes = null,
                    totalBytes = null,
                    speedBytesPerSecond = null,
                    remainingSeconds = null,
                    batchTotalCount = selections.size,
                    batchCompletedCount = 0,
                    batchFailedCount = 0,
                    batchCurrentIndex = 0,
                    canRetry = canRetry,
                    canCancel = false,
                ),
                sharedFileStatus = message,
                isSendingSharedFile = false,
            )
        }
    }

    fun updatePreparingState(
        selection: SharedFileSelection,
        transferId: String,
        totalCount: Int,
        completedCount: Int,
        currentIndex: Int,
    ) {
        updateState {
            it.copy(
                isSendingSharedFile = true,
                sharedFileTransfer = it.sharedFileTransfer?.copy(
                    fileName = batchFileName(selection.fileName, totalCount),
                    sizeLabel = batchSizeLabel(selection.sizeLabel, totalCount),
                    targetName = targetName(it),
                    transferId = transferId,
                    stage = if (totalCount == 1) {
                        SharedFileDeliveryStage.Preparing
                    } else {
                        SharedFileDeliveryStage.Sending
                    },
                    message = batchMessage(
                        totalCount = totalCount,
                        single = "正在准备文件...",
                        multiple = "正在投递 $totalCount 个文件..."
                    ),
                    progressPercent = if (totalCount == 1) null else queueProgressPercent(totalCount, completedCount, 0),
                    sentBytes = null,
                    totalBytes = selection.sizeBytes,
                    speedBytesPerSecond = null,
                    remainingSeconds = null,
                    batchTotalCount = totalCount,
                    batchCompletedCount = completedCount,
                    batchFailedCount = 0,
                    batchCurrentIndex = currentIndex,
                    canRetry = false,
                    canCancel = true,
                ),
                sharedFileStatus = if (totalCount == 1) {
                    "正在准备 ${selection.fileName}..."
                } else {
                    "正在投递 $totalCount 个文件..."
                },
            )
        }
    }

    fun updateSendingState(
        payload: SharedFileRelayPayload,
        transferId: String,
        totalCount: Int,
        completedCount: Int,
        currentIndex: Int,
        sentBytes: Long,
        progressPercent: Int,
        speedBytesPerSecond: Long?,
        remainingSeconds: Long?,
        cancelToken: SharedFileTransferCancelToken,
    ) {
        updateState {
            val wasCancelled = cancelToken.isCancelled
            val presentation = SharedFileDeliveryActivePresenter.sending(
                totalCount = totalCount,
                completedCount = completedCount,
                currentFileProgressPercent = progressPercent,
                targetName = targetName(it),
                isCancelled = wasCancelled,
            )
            it.copy(
                isSendingSharedFile = true,
                sharedFileTransfer = it.sharedFileTransfer?.copy(
                    fileName = batchFileName(payload.fileName, totalCount),
                    sizeLabel = batchSizeLabel(formatFileSize(payload.size), totalCount),
                    targetName = targetName(it),
                    transferId = transferId,
                    stage = presentation.stage,
                    message = presentation.message,
                    progressPercent = presentation.progressPercent,
                    sentBytes = sentBytes,
                    totalBytes = payload.size,
                    speedBytesPerSecond = speedBytesPerSecond,
                    remainingSeconds = remainingSeconds,
                    batchTotalCount = totalCount,
                    batchCompletedCount = completedCount,
                    batchFailedCount = 0,
                    batchCurrentIndex = currentIndex,
                    canRetry = false,
                    canCancel = presentation.canCancel,
                ),
                sharedFileStatus = presentation.sharedFileStatus,
            )
        }
    }

    fun updateProgressState(
        selection: SharedFileSelection,
        transferId: String,
        totalCount: Int,
        completedCount: Int,
        currentIndex: Int,
        sentBytes: Long,
        totalBytes: Long,
        speedBytesPerSecond: Long,
        remainingSeconds: Long?,
        progressPercent: Int,
        cancelToken: SharedFileTransferCancelToken,
    ) {
        updateState {
            val fileName = it.sharedFileTransfer?.fileName ?: selection.fileName
            val sizeLabel = it.sharedFileTransfer?.sizeLabel ?: selection.sizeLabel
            val presentation = SharedFileDeliveryActivePresenter.sending(
                totalCount = totalCount,
                completedCount = completedCount,
                currentFileProgressPercent = progressPercent,
                targetName = targetName(it),
                isCancelled = cancelToken.isCancelled,
            )
            it.copy(
                isSendingSharedFile = true,
                sharedFileTransfer = it.sharedFileTransfer?.copy(
                    fileName = batchFileName(fileName, totalCount),
                    sizeLabel = batchSizeLabel(sizeLabel, totalCount),
                    transferId = transferId,
                    stage = presentation.stage,
                    message = presentation.message,
                    progressPercent = presentation.progressPercent,
                    sentBytes = sentBytes,
                    totalBytes = totalBytes,
                    speedBytesPerSecond = speedBytesPerSecond,
                    remainingSeconds = remainingSeconds,
                    batchTotalCount = totalCount,
                    batchCompletedCount = completedCount,
                    batchFailedCount = 0,
                    batchCurrentIndex = currentIndex,
                    canRetry = false,
                    canCancel = presentation.canCancel,
                ),
                sharedFileStatus = presentation.sharedFileStatus,
            )
        }
    }

    fun updateFileCompletedState(
        payload: SharedFileRelayPayload,
        response: SharedFileRelayResponse,
        transferId: String,
        totalCount: Int,
        completedCount: Int,
        currentIndex: Int,
    ) {
        val savedFileName = response.fileName.ifBlank { payload.fileName }
        val wasRenamed = savedFileName != payload.fileName
        updateState {
            it.copy(
                sharedFileTransfer = it.sharedFileTransfer?.copy(
                    fileName = batchFileName(savedFileName, totalCount),
                    sizeLabel = batchSizeLabel(formatFileSize(response.size), totalCount),
                    targetName = targetName(it),
                    transferId = transferId,
                    stage = if (completedCount == totalCount) {
                        SharedFileDeliveryStage.Success
                    } else {
                        SharedFileDeliveryStage.Sending
                    },
                    message = if (completedCount == totalCount) {
                        if (totalCount == 1 && wasRenamed) {
                            "已发送到 ${targetName(it) ?: "Mac"}，Mac 已保存为 $savedFileName。"
                        } else {
                            "已发送到 ${targetName(it) ?: "Mac"}，可在 Mac 上打开或定位。"
                        }
                    } else {
                        "正在投递 $totalCount 个文件..."
                    },
                    progressPercent = if (completedCount == totalCount) {
                        100
                    } else {
                        queueProgressPercent(totalCount, completedCount, 0)
                    },
                    sentBytes = response.size,
                    totalBytes = response.size,
                    remainingSeconds = 0,
                    batchTotalCount = totalCount,
                    batchCompletedCount = completedCount,
                    batchFailedCount = 0,
                    batchCurrentIndex = currentIndex,
                    canRetry = false,
                    canCancel = completedCount < totalCount,
                ),
                sharedFileStatus = if (wasRenamed) {
                    "已发送 ${payload.fileName}，Mac 保存为 $savedFileName"
                } else {
                    "已发送 ${payload.fileName} 到 Mac"
                },
            )
        }
    }

    fun updateBatchSuccessState(
        batchId: String,
        selections: List<SharedFileSelection>,
        responses: List<SharedFileRelayResponse>,
        completedBytes: Long,
    ): SharedFileDeliverySuccessSummary {
        val successPresentation = SharedFileDeliverySuccessPresenter.build(
            selections = selections,
            responses = responses,
            formatFileSize = formatFileSize,
        )

        updateState {
            it.copy(
                isSendingSharedFile = false,
                sharedFileTransfer = it.sharedFileTransfer?.copy(
                    fileName = successPresentation.transferFileName,
                    sizeLabel = successPresentation.transferSizeLabel,
                    targetName = targetName(it),
                    transferId = batchId,
                    stage = SharedFileDeliveryStage.Success,
                    message = successPresentation.transferMessage(targetName(it)),
                    progressPercent = 100,
                    sentBytes = if (completedBytes > 0) completedBytes else null,
                    totalBytes = if (completedBytes > 0) completedBytes else null,
                    speedBytesPerSecond = null,
                    remainingSeconds = 0,
                    batchTotalCount = successPresentation.totalCount,
                    batchCompletedCount = successPresentation.totalCount,
                    batchFailedCount = 0,
                    batchCurrentIndex = (successPresentation.totalCount - 1).coerceAtLeast(0),
                    canRetry = false,
                    canCancel = false,
                ),
                sharedFileStatus = successPresentation.recordMessage,
            )
        }

        return successPresentation.toSummary()
    }

    fun updateBatchPartialFailureState(
        batchId: String,
        selections: List<SharedFileSelection>,
        completedCount: Int,
        failedCount: Int,
        message: String,
        canRetry: Boolean,
    ) {
        val firstSelection = selections.first()
        val totalCount = selections.size.coerceAtLeast(1)
        updateState {
            it.copy(
                isSendingSharedFile = false,
                sharedFileTransfer = it.sharedFileTransfer?.copy(
                    fileName = batchFileName(firstSelection.fileName, totalCount),
                    sizeLabel = batchSizeLabel(firstSelection.sizeLabel, totalCount),
                    targetName = targetName(it),
                    transferId = batchId,
                    stage = SharedFileDeliveryStage.Failed,
                    message = message,
                    progressPercent = queueProgressPercent(totalCount, completedCount, 0),
                    sentBytes = null,
                    totalBytes = null,
                    speedBytesPerSecond = null,
                    remainingSeconds = null,
                    batchTotalCount = totalCount,
                    batchCompletedCount = completedCount,
                    batchFailedCount = failedCount,
                    batchCurrentIndex = (totalCount - 1).coerceAtLeast(0),
                    canRetry = canRetry,
                    canCancel = false,
                ),
                sharedFileStatus = message,
            )
        }
    }

    fun updateTerminalFailureState(
        selection: SharedFileSelection,
        transferId: String,
        totalCount: Int,
        completedCount: Int,
        failedCount: Int,
        currentIndex: Int,
        stage: SharedFileDeliveryStage,
        message: String,
        canRetry: Boolean,
    ) {
        updateState {
            it.copy(
                isSendingSharedFile = false,
                sharedFileTransfer = it.sharedFileTransfer?.copy(
                    fileName = selection.fileName,
                    sizeLabel = selection.sizeLabel,
                    targetName = targetName(it),
                    transferId = transferId,
                    stage = stage,
                    message = if (totalCount == 1) {
                        message
                    } else {
                        "$message（已完成 $completedCount / $totalCount 个）"
                    },
                    remainingSeconds = null,
                    batchTotalCount = totalCount,
                    batchCompletedCount = completedCount,
                    batchFailedCount = failedCount,
                    batchCurrentIndex = currentIndex,
                    canRetry = canRetry,
                    canCancel = false,
                ),
                sharedFileStatus = message,
            )
        }
    }

}
