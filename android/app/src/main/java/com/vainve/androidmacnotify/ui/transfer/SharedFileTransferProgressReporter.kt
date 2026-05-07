package com.vainve.androidmacnotify.ui.transfer

import android.os.SystemClock

internal data class SharedFileTransferProgressSnapshot(
    val sentBytes: Long,
    val totalBytes: Long,
    val speedBytesPerSecond: Long,
    val remainingSeconds: Long?,
    val progressPercent: Int,
)

internal class SharedFileTransferProgressReporter(
    private val minUpdateIntervalMillis: Long = 500L,
    private val nowMillis: () -> Long = { SystemClock.elapsedRealtime() },
    private val onProgress: (SharedFileTransferProgressSnapshot) -> Unit,
) {
    private val transferStartedAtMillis = nowMillis()
    private var lastProgressPercent = -1
    private var lastUiUpdateAtMillis = 0L

    fun report(sentBytes: Long, totalBytes: Long) {
        val now = nowMillis()
        val elapsedMillis = (now - transferStartedAtMillis).coerceAtLeast(1L)
        val speedBytesPerSecond = ((sentBytes * 1000L) / elapsedMillis).coerceAtLeast(0L)
        val remainingSeconds = when {
            speedBytesPerSecond <= 0L || totalBytes <= sentBytes -> null
            else -> ((totalBytes - sentBytes) + speedBytesPerSecond - 1L) / speedBytesPerSecond
        }
        val progressPercent = when {
            totalBytes <= 0L -> 0
            else -> ((sentBytes * 100L) / totalBytes).toInt().coerceIn(0, 100)
        }
        val shouldRefreshUi = progressPercent != lastProgressPercent ||
            now - lastUiUpdateAtMillis >= minUpdateIntervalMillis ||
            sentBytes >= totalBytes
        if (!shouldRefreshUi) {
            return
        }

        lastProgressPercent = progressPercent
        lastUiUpdateAtMillis = now
        onProgress(
            SharedFileTransferProgressSnapshot(
                sentBytes = sentBytes,
                totalBytes = totalBytes,
                speedBytesPerSecond = speedBytesPerSecond,
                remainingSeconds = remainingSeconds,
                progressPercent = progressPercent,
            )
        )
    }
}
