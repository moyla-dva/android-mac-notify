package com.vainve.androidmacnotify.ui.transfer

import com.vainve.androidmacnotify.ui.transfer.SharedFileDeliveryUiFormatting.batchMessage
import com.vainve.androidmacnotify.ui.transfer.SharedFileDeliveryUiFormatting.queueProgressPercent

internal data class SharedFileDeliveryActivePresentation(
    val stage: SharedFileDeliveryStage,
    val message: String,
    val progressPercent: Int,
    val sharedFileStatus: String,
    val canCancel: Boolean,
)

internal object SharedFileDeliveryActivePresenter {
    fun sending(
        totalCount: Int,
        completedCount: Int,
        currentFileProgressPercent: Int,
        targetName: String?,
        isCancelled: Boolean,
    ): SharedFileDeliveryActivePresentation {
        val normalizedProgress = currentFileProgressPercent.coerceIn(0, 100)
        val progressPercent = if (totalCount == 1) {
            normalizedProgress
        } else {
            queueProgressPercent(totalCount, completedCount, normalizedProgress)
        }

        return SharedFileDeliveryActivePresentation(
            stage = if (isCancelled) {
                SharedFileDeliveryStage.Cancelling
            } else {
                SharedFileDeliveryStage.Sending
            },
            message = if (isCancelled) {
                "正在取消投递..."
            } else {
                batchMessage(
                    totalCount = totalCount,
                    single = "正在发送到 ${targetName ?: "Mac"}... $normalizedProgress%",
                    multiple = "正在投递 $totalCount 个文件..."
                )
            },
            progressPercent = progressPercent,
            sharedFileStatus = if (totalCount == 1) {
                "正在发送 $normalizedProgress%..."
            } else {
                "正在投递 $totalCount 个文件..."
            },
            canCancel = !isCancelled,
        )
    }
}
