package com.vainve.androidmacnotify.ui.transfer

internal object SharedFileDeliveryUiFormatting {
    fun batchMessage(
        totalCount: Int,
        single: String,
        multiple: String,
    ): String = if (totalCount == 1) single else multiple

    fun batchFileName(fileName: String, totalCount: Int): String {
        return if (totalCount == 1) fileName else "$totalCount 个文件"
    }

    fun batchSizeLabel(sizeLabel: String?, totalCount: Int): String? {
        return if (totalCount == 1) sizeLabel else "$totalCount 个文件"
    }

    fun queueProgressPercent(
        totalCount: Int,
        completedCount: Int,
        currentFileProgressPercent: Int,
    ): Int {
        if (totalCount <= 0) return 0
        val completed = completedCount.coerceIn(0, totalCount)
        val current = currentFileProgressPercent.coerceIn(0, 100).toFloat() / 100f
        return (((completed.toFloat() + current) / totalCount.toFloat()) * 100f)
            .toInt()
            .coerceIn(0, 100)
    }
}
