package com.vainve.androidmacnotify.ui.transfer

import android.net.Uri

enum class SharedFileDeliveryStage {
    ReadingConfig,
    Preparing,
    Sending,
    Cancelling,
    Cancelled,
    Success,
    Failed,
}

data class SharedFileTransferUi(
    val fileName: String,
    val sizeLabel: String?,
    val targetName: String?,
    val stage: SharedFileDeliveryStage,
    val message: String,
    val progressPercent: Int? = null,
    val transferId: String? = null,
    val transferModeLabel: String = "直传",
    val sentBytes: Long? = null,
    val totalBytes: Long? = null,
    val speedBytesPerSecond: Long? = null,
    val remainingSeconds: Long? = null,
    val batchTotalCount: Int = 1,
    val batchCompletedCount: Int = 0,
    val batchFailedCount: Int = 0,
    val batchCurrentIndex: Int = 0,
    val canRetry: Boolean = false,
    val canCancel: Boolean = false,
)

data class SharedFileSelection(
    val uri: Uri,
    val fileName: String,
    val sizeLabel: String?,
    val sizeBytes: Long?,
)
