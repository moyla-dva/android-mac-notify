package com.vainve.androidmacnotify.ui.transfer

import com.vainve.androidmacnotify.data.MacReachabilityStatus
import com.vainve.androidmacnotify.network.RelayApiException
import java.io.IOException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SharedFileDeliveryFailurePolicyTest {
    @Test
    fun relayAuthFailureIsNotRetryableAndMarksRegistrationFailed() {
        val failure = SharedFileDeliveryFailurePolicy.forRelayFailure(
            error = relayError(statusCode = 401, code = "INVALID_DEVICE_TOKEN", retryable = false),
            cancelToken = SharedFileTransferCancelToken(),
        )

        assertEquals(SharedFileDeliveryStage.Failed, failure.stage)
        assertFalse(failure.canRetry)
        assertTrue(failure.shouldStopBatch)
        assertEquals(MacReachabilityStatus.AuthFailed, failure.reachabilityUpdate?.status)
        assertEquals("旧配对已失效，请重新连接 Mac", failure.reachabilityUpdate?.message)
    }

    @Test
    fun macReceiverPausedKeepsRetryAvailableAndUpdatesReachability() {
        val failure = SharedFileDeliveryFailurePolicy.forRelayFailure(
            error = relayError(statusCode = 409, code = "MAC_RECEIVER_PAUSED", retryable = true),
            cancelToken = SharedFileTransferCancelToken(),
        )

        assertEquals(SharedFileDeliveryStage.Failed, failure.stage)
        assertTrue(failure.canRetry)
        assertTrue(failure.shouldStopBatch)
        assertEquals(MacReachabilityStatus.MacPaused, failure.reachabilityUpdate?.status)
        assertEquals("Mac 已暂停接收，重新开始后会继续接力", failure.reachabilityUpdate?.message)
    }

    @Test
    fun cancelledRelayFailureDoesNotUpdateReachability() {
        val cancelToken = SharedFileTransferCancelToken().apply { cancel() }

        val failure = SharedFileDeliveryFailurePolicy.forRelayFailure(
            error = relayError(statusCode = 500, code = "SERVER_ERROR", retryable = true),
            cancelToken = cancelToken,
        )

        assertEquals(SharedFileDeliveryStage.Cancelled, failure.stage)
        assertTrue(failure.canRetry)
        assertTrue(failure.shouldStopBatch)
        assertNull(failure.reachabilityUpdate)
    }

    @Test
    fun securityExceptionDuringPayloadBuildRequiresReselection() {
        val failure = SharedFileDeliveryFailurePolicy.forPayloadBuildFailure(
            error = SecurityException("permission expired"),
            cancelToken = SharedFileTransferCancelToken(),
        )

        assertEquals(SharedFileDeliveryStage.Failed, failure.stage)
        assertFalse(failure.canRetry)
        assertFalse(failure.shouldStopBatch)
        assertEquals("原文件权限已失效，请重新从系统分享菜单或文件页选择文件。", failure.message)
    }

    @Test
    fun retryablePayloadBuildFailureKeepsRetryAvailable() {
        val failure = SharedFileDeliveryFailurePolicy.forPayloadBuildFailure(
            error = IOException("文件读取失败"),
            cancelToken = SharedFileTransferCancelToken(),
        )

        assertEquals(SharedFileDeliveryStage.Failed, failure.stage)
        assertTrue(failure.canRetry)
        assertFalse(failure.shouldStopBatch)
        assertEquals(1, failure.failedCount)
        assertEquals("文件读取失败", failure.message)
    }

    @Test
    fun cancelledPayloadBuildFailureKeepsRetryAvailableWithoutFailedCount() {
        val cancelToken = SharedFileTransferCancelToken().apply { cancel() }

        val failure = SharedFileDeliveryFailurePolicy.forPayloadBuildFailure(
            error = IOException("cancelled"),
            cancelToken = cancelToken,
        )

        assertEquals(SharedFileDeliveryStage.Cancelled, failure.stage)
        assertTrue(failure.canRetry)
        assertTrue(failure.shouldStopBatch)
        assertEquals(0, failure.failedCount)
        assertEquals("已取消投递，未完成文件会被清理", failure.message)
    }

    @Test
    fun macFileSaveFailureDoesNotMarkMacUnreachable() {
        val failure = SharedFileDeliveryFailurePolicy.forRelayFailure(
            error = relayError(statusCode = 507, code = "INSUFFICIENT_STORAGE", retryable = true),
            cancelToken = SharedFileTransferCancelToken(),
        )

        assertEquals(SharedFileDeliveryStage.Failed, failure.stage)
        assertTrue(failure.canRetry)
        assertTrue(failure.shouldStopBatch)
        assertEquals(MacReachabilityStatus.Reachable, failure.reachabilityUpdate?.status)
        assertNull(failure.reachabilityUpdate?.message)
    }

    @Test
    fun singleFileSaveFailureCanContinueBatch() {
        val failure = SharedFileDeliveryFailurePolicy.forRelayFailure(
            error = relayError(statusCode = 500, code = "FILE_SAVE_FAILED", retryable = true),
            cancelToken = SharedFileTransferCancelToken(),
        )

        assertEquals(SharedFileDeliveryStage.Failed, failure.stage)
        assertTrue(failure.canRetry)
        assertFalse(failure.shouldStopBatch)
        assertEquals(MacReachabilityStatus.Reachable, failure.reachabilityUpdate?.status)
    }

    private fun relayError(
        statusCode: Int,
        code: String,
        retryable: Boolean?,
    ): RelayApiException {
        return RelayApiException(
            statusCode = statusCode,
            code = code,
            serverMessage = null,
            retryable = retryable,
            operation = "File delivery",
            responseBody = "",
        )
    }
}
