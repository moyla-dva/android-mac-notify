package com.vainve.androidmacnotify.ui.transfer

import org.junit.Assert.assertEquals
import org.junit.Test

class BatchProgressSummaryTest {
    @Test
    fun activeBatchProgressUsesAggregatePercent() {
        val transfer = SharedFileTransferUi(
            fileName = "6 个文件",
            sizeLabel = "6 个文件",
            targetName = "Mac",
            stage = SharedFileDeliveryStage.Sending,
            message = "正在投递 6 个文件...",
            progressPercent = 50,
            batchTotalCount = 6,
            batchCompletedCount = 2,
            batchCurrentIndex = 2,
        )

        assertEquals(0.5f, batchProgressFraction(transfer), 0.0001f)
        assertEquals("第 3 / 6 个 · 已完成 2 个", batchProgressLabel(transfer))
    }

    @Test
    fun terminalBatchProgressUsesCompletedCount() {
        val transfer = SharedFileTransferUi(
            fileName = "6 个文件",
            sizeLabel = "6 个文件",
            targetName = "Mac",
            stage = SharedFileDeliveryStage.Failed,
            message = "网络中断",
            progressPercent = 80,
            batchTotalCount = 6,
            batchCompletedCount = 3,
            batchCurrentIndex = 3,
        )

        assertEquals(0.5f, batchProgressFraction(transfer), 0.0001f)
        assertEquals("中断 · 已完成 3 / 6 个", batchProgressLabel(transfer))
    }

    @Test
    fun activeBatchProgressClampsInvalidPercent() {
        val transfer = SharedFileTransferUi(
            fileName = "2 个文件",
            sizeLabel = "2 个文件",
            targetName = "Mac",
            stage = SharedFileDeliveryStage.Sending,
            message = "正在投递 2 个文件...",
            progressPercent = 150,
            batchTotalCount = 2,
            batchCompletedCount = 1,
            batchCurrentIndex = 1,
        )

        assertEquals(1f, batchProgressFraction(transfer), 0.0001f)
    }
}
