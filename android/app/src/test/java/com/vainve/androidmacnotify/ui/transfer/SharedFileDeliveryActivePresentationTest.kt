package com.vainve.androidmacnotify.ui.transfer

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SharedFileDeliveryActivePresentationTest {
    @Test
    fun singleFileSendingShowsTargetAndCurrentProgress() {
        val presentation = SharedFileDeliveryActivePresenter.sending(
            totalCount = 1,
            completedCount = 0,
            currentFileProgressPercent = 42,
            targetName = "MacBook",
            isCancelled = false,
        )

        assertEquals(SharedFileDeliveryStage.Sending, presentation.stage)
        assertEquals("正在发送到 MacBook... 42%", presentation.message)
        assertEquals(42, presentation.progressPercent)
        assertEquals("正在发送 42%...", presentation.sharedFileStatus)
        assertTrue(presentation.canCancel)
    }

    @Test
    fun batchSendingUsesQueueProgress() {
        val presentation = SharedFileDeliveryActivePresenter.sending(
            totalCount = 4,
            completedCount = 2,
            currentFileProgressPercent = 50,
            targetName = "MacBook",
            isCancelled = false,
        )

        assertEquals("正在投递 4 个文件...", presentation.message)
        assertEquals(62, presentation.progressPercent)
        assertEquals("正在投递 4 个文件...", presentation.sharedFileStatus)
    }

    @Test
    fun cancelledSendingSwitchesToCancellingState() {
        val presentation = SharedFileDeliveryActivePresenter.sending(
            totalCount = 1,
            completedCount = 0,
            currentFileProgressPercent = 200,
            targetName = null,
            isCancelled = true,
        )

        assertEquals(SharedFileDeliveryStage.Cancelling, presentation.stage)
        assertEquals("正在取消投递...", presentation.message)
        assertEquals(100, presentation.progressPercent)
        assertFalse(presentation.canCancel)
    }
}
