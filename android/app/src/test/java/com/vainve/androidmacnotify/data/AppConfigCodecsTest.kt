package com.vainve.androidmacnotify.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class AppConfigCodecsTest {
    @Test
    fun successRecordRemovesResolvedFailureWithSameSourceUri() {
        val failed = record(
            recordId = "failed-batch",
            status = SharedFileDeliveryRecordStatus.Failed,
            sourceUris = listOf("content://files/a.txt", "content://files/b.txt"),
            finishedAt = 100,
        )
        val unrelatedFailure = record(
            recordId = "unrelated-failure",
            status = SharedFileDeliveryRecordStatus.Failed,
            sourceUris = listOf("content://files/other.txt"),
            finishedAt = 110,
        )
        val success = record(
            recordId = "retry-success",
            status = SharedFileDeliveryRecordStatus.Success,
            sourceUris = listOf("content://files/b.txt"),
            finishedAt = 200,
        )

        val next = AppConfigCodecs.nextSharedFileDeliveryRecords(
            current = listOf(failed, unrelatedFailure),
            record = success,
            maxSize = 10,
            maxSuccessSize = 4,
        )

        assertEquals(listOf("retry-success", "unrelated-failure"), next.map { it.recordId })
        assertFalse(next.any { it.recordId == "failed-batch" })
    }

    @Test
    fun successRecordsAreCappedButFailureRecordsStayVisibleForRetry() {
        val records = listOf(
            record("success-1", SharedFileDeliveryRecordStatus.Success, finishedAt = 100),
            record("success-2", SharedFileDeliveryRecordStatus.Success, finishedAt = 200),
            record("success-3", SharedFileDeliveryRecordStatus.Success, finishedAt = 300),
            record("failure-1", SharedFileDeliveryRecordStatus.Failed, finishedAt = 400),
            record("cancelled-1", SharedFileDeliveryRecordStatus.Cancelled, finishedAt = 500),
        )

        val trimmed = AppConfigCodecs.trimSharedFileDeliveryRecords(
            records = records,
            maxSize = 4,
            maxSuccessSize = 2,
        )

        assertEquals(
            listOf("cancelled-1", "failure-1", "success-3", "success-2"),
            trimmed.map { it.recordId },
        )
        assertTrue(trimmed.any { it.status == SharedFileDeliveryRecordStatus.Failed })
        assertEquals(2, trimmed.count { it.status == SharedFileDeliveryRecordStatus.Success })
    }

    @Test
    fun encodedSharedFileDeliveryRecordsRoundTripRetrySources() {
        val original = listOf(
            record(
                recordId = "failed-batch",
                status = SharedFileDeliveryRecordStatus.Failed,
                sourceUris = listOf("content://files/a.txt", "content://files/b.txt"),
                canRetry = true,
            )
        )

        val decoded = AppConfigCodecs.decodeSharedFileDeliveryRecords(
            AppConfigCodecs.encodeSharedFileDeliveryRecords(original)
        )

        assertEquals(original, decoded)
    }

    private fun record(
        recordId: String,
        status: SharedFileDeliveryRecordStatus,
        sourceUris: List<String> = listOf("content://files/$recordId.txt"),
        canRetry: Boolean = status != SharedFileDeliveryRecordStatus.Success,
        finishedAt: Long = 1_000,
    ): SharedFileDeliveryRecord {
        return SharedFileDeliveryRecord(
            recordId = recordId,
            fileName = "$recordId.txt",
            fileCount = sourceUris.size.coerceAtLeast(1),
            completedCount = if (status == SharedFileDeliveryRecordStatus.Success) sourceUris.size.coerceAtLeast(1) else 0,
            totalBytes = 1024,
            sourceUris = sourceUris,
            targetName = "MacBook",
            status = status,
            message = status.name,
            canRetry = canRetry,
            finishedAt = finishedAt,
        )
    }
}
