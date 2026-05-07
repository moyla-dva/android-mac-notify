package com.vainve.androidmacnotify.ui.transfer

import org.junit.Assert.assertEquals
import org.junit.Test

class SharedFileTransferProgressReporterTest {
    @Test
    fun progressReporterThrottlesSamePercentButAlwaysEmitsFinalProgress() {
        var nowMillis = 1_000L
        val snapshots = mutableListOf<SharedFileTransferProgressSnapshot>()
        val reporter = SharedFileTransferProgressReporter(
            minUpdateIntervalMillis = 500L,
            nowMillis = { nowMillis },
            onProgress = snapshots::add,
        )

        reporter.report(sentBytes = 10, totalBytes = 100)
        reporter.report(sentBytes = 10, totalBytes = 100)
        nowMillis += 501L
        reporter.report(sentBytes = 10, totalBytes = 100)
        reporter.report(sentBytes = 100, totalBytes = 100)

        assertEquals(listOf(10, 10, 100), snapshots.map { it.progressPercent })
        assertEquals(null, snapshots.last().remainingSeconds)
    }

    @Test
    fun progressReporterCalculatesSpeedAndRemainingSeconds() {
        var nowMillis = 1_000L
        val snapshots = mutableListOf<SharedFileTransferProgressSnapshot>()
        val reporter = SharedFileTransferProgressReporter(
            nowMillis = { nowMillis },
            onProgress = snapshots::add,
        )

        nowMillis += 1_000L
        reporter.report(sentBytes = 250, totalBytes = 1_000)

        assertEquals(250L, snapshots.single().speedBytesPerSecond)
        assertEquals(3L, snapshots.single().remainingSeconds)
        assertEquals(25, snapshots.single().progressPercent)
    }
}
