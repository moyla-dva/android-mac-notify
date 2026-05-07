package com.vainve.androidmacnotify.ui.transfer

import com.vainve.androidmacnotify.network.SharedFileRelayResponse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SharedFileDeliverySuccessPresentationTest {
    @Test
    fun singleFileSuccessUsesSavedNameAndSize() {
        val presentation = SharedFileDeliverySuccessPresenter.buildFromSources(
            sources = listOf(source(fileName = "photo.jpg", sizeLabel = "1 KB")),
            responses = listOf(response(fileName = "photo.jpg", size = 2048)),
            formatFileSize = { "$it B" },
        )

        assertEquals("photo.jpg", presentation.transferFileName)
        assertEquals("2048 B", presentation.transferSizeLabel)
        assertEquals("已发送 photo.jpg 到 Mac", presentation.recordMessage)
        assertEquals("已发送到 MacBook，可在 Mac 上打开或定位。", presentation.transferMessage("MacBook"))
        assertEquals("photo.jpg", presentation.displayFileName)
    }

    @Test
    fun singleFileRenamedSuccessExplainsMacSavedName() {
        val presentation = SharedFileDeliverySuccessPresenter.buildFromSources(
            sources = listOf(source(fileName = "photo.jpg")),
            responses = listOf(response(fileName = "photo 1.jpg")),
            formatFileSize = { "$it B" },
        )

        assertEquals("photo 1.jpg", presentation.transferFileName)
        assertEquals("Mac 已保存为 photo 1.jpg", presentation.recordMessage)
        assertEquals("已发送到 Mac，Mac 已保存为 photo 1.jpg。", presentation.transferMessage(null))
        assertEquals("photo 1.jpg", presentation.toSummary().displayFileName)
    }

    @Test
    fun batchSuccessSummarizesFileCount() {
        val presentation = SharedFileDeliverySuccessPresenter.buildFromSources(
            sources = listOf(
                source(fileName = "a.jpg"),
                source(fileName = "b.jpg"),
                source(fileName = "c.jpg"),
            ),
            responses = listOf(
                response(fileName = "a.jpg"),
                response(fileName = "b 1.jpg"),
                response(fileName = "c.jpg"),
            ),
            formatFileSize = { "$it B" },
        )

        assertEquals("3 个文件", presentation.transferFileName)
        assertEquals("3 个文件", presentation.transferSizeLabel)
        assertEquals("已发送 3 个文件到 Mac，其中 1 个已自动改名", presentation.recordMessage)
        assertEquals("已发送 3 个文件到 MacBook，其中 1 个已自动改名。", presentation.transferMessage("MacBook"))
        assertNull(presentation.displayFileName)
    }

    private fun source(
        fileName: String,
        sizeLabel: String? = null,
    ): SharedFileDeliverySuccessSource {
        return SharedFileDeliverySuccessSource(
            fileName = fileName,
            sizeLabel = sizeLabel,
        )
    }

    private fun response(
        fileName: String,
        size: Long = 1024,
    ): SharedFileRelayResponse {
        return SharedFileRelayResponse(
            accepted = true,
            shareId = "share",
            fileName = fileName,
            savedPath = null,
            size = size,
        )
    }
}
