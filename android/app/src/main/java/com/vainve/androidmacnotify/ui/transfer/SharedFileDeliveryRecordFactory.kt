package com.vainve.androidmacnotify.ui.transfer

import com.vainve.androidmacnotify.data.SharedFileDeliveryRecord
import com.vainve.androidmacnotify.data.SharedFileDeliveryRecordStatus

internal fun buildSharedFileDeliveryRecord(
    recordId: String,
    selections: List<SharedFileSelection>,
    completedCount: Int,
    status: SharedFileDeliveryRecordStatus,
    message: String,
    targetName: String?,
    totalBytes: Long? = knownTotalBytes(selections),
    displayFileName: String? = null,
    canRetry: Boolean = false,
    retrySelections: List<SharedFileSelection> = emptyList(),
    finishedAt: Long = System.currentTimeMillis(),
): SharedFileDeliveryRecord? {
    if (selections.isEmpty()) return null
    val totalCount = selections.size
    val sourceSelections = when {
        status == SharedFileDeliveryRecordStatus.Success -> selections
        canRetry -> retrySelections.ifEmpty { selections }
        else -> emptyList()
    }

    return SharedFileDeliveryRecord(
        recordId = recordId,
        fileName = if (totalCount == 1) {
            displayFileName?.takeIf { it.isNotBlank() } ?: selections.first().fileName
        } else {
            "$totalCount 个文件"
        },
        fileCount = totalCount,
        completedCount = completedCount.coerceIn(0, totalCount),
        totalBytes = totalBytes,
        sourceUris = sourceSelections.map { it.uri.toString() },
        targetName = targetName,
        status = status,
        message = message,
        canRetry = canRetry,
        finishedAt = finishedAt,
    )
}

internal fun knownTotalBytes(selections: List<SharedFileSelection>): Long? {
    var total = 0L
    selections.forEach { selection ->
        val size = selection.sizeBytes ?: return null
        total += size
    }
    return total
}
