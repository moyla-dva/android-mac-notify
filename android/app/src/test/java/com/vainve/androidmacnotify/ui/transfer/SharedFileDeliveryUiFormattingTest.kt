package com.vainve.androidmacnotify.ui.transfer

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SharedFileDeliveryUiFormattingTest {
    @Test
    fun batchMessageKeepsSingleTextForSingleFile() {
        assertEquals(
            "正在准备文件...",
            SharedFileDeliveryUiFormatting.batchMessage(
                totalCount = 1,
                single = "正在准备文件...",
                multiple = "正在投递 3 个文件...",
            ),
        )
    }

    @Test
    fun batchMessageUsesMultipleTextForBatch() {
        assertEquals(
            "正在投递 3 个文件...",
            SharedFileDeliveryUiFormatting.batchMessage(
                totalCount = 3,
                single = "正在准备文件...",
                multiple = "正在投递 3 个文件...",
            ),
        )
    }

    @Test
    fun batchFileNameAndSizePreserveSingleFileDetails() {
        assertEquals("photo.jpg", SharedFileDeliveryUiFormatting.batchFileName("photo.jpg", 1))
        assertEquals("2 MB", SharedFileDeliveryUiFormatting.batchSizeLabel("2 MB", 1))
        assertNull(SharedFileDeliveryUiFormatting.batchSizeLabel(null, 1))
    }

    @Test
    fun batchFileNameAndSizeSummarizeMultipleFiles() {
        assertEquals("4 个文件", SharedFileDeliveryUiFormatting.batchFileName("photo.jpg", 4))
        assertEquals("4 个文件", SharedFileDeliveryUiFormatting.batchSizeLabel("2 MB", 4))
    }

    @Test
    fun queueProgressPercentCombinesCompletedFilesAndCurrentFileProgress() {
        assertEquals(
            62,
            SharedFileDeliveryUiFormatting.queueProgressPercent(
                totalCount = 4,
                completedCount = 2,
                currentFileProgressPercent = 50,
            ),
        )
    }

    @Test
    fun queueProgressPercentClampsInvalidInputs() {
        assertEquals(0, SharedFileDeliveryUiFormatting.queueProgressPercent(0, 2, 50))
        assertEquals(0, SharedFileDeliveryUiFormatting.queueProgressPercent(3, -1, -50))
        assertEquals(100, SharedFileDeliveryUiFormatting.queueProgressPercent(3, 5, 150))
    }
}
