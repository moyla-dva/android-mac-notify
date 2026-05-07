package com.vainve.androidmacnotify.ui.transfer

import com.vainve.androidmacnotify.data.SharedFileDeliveryRecord
import com.vainve.androidmacnotify.data.SharedFileDeliveryRecordStatus

internal class SharedFileDeliveryRecorder(
    private val targetName: () -> String?,
    private val onRecordDelivery: (SharedFileDeliveryRecord) -> Unit,
) {
    fun record(
        recordId: String,
        selections: List<SharedFileSelection>,
        completedCount: Int,
        status: SharedFileDeliveryRecordStatus,
        message: String,
        totalBytes: Long? = knownTotalBytes(selections),
        displayFileName: String? = null,
        canRetry: Boolean = false,
        retrySelections: List<SharedFileSelection> = emptyList(),
    ) {
        val record = buildSharedFileDeliveryRecord(
            recordId = recordId,
            selections = selections,
            completedCount = completedCount,
            status = status,
            message = message,
            targetName = targetName(),
            totalBytes = totalBytes,
            displayFileName = displayFileName,
            canRetry = canRetry,
            retrySelections = retrySelections,
        ) ?: return
        onRecordDelivery(record)
    }
}
