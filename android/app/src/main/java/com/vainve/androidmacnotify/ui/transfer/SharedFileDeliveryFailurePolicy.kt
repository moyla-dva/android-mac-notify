package com.vainve.androidmacnotify.ui.transfer

import com.vainve.androidmacnotify.data.MacReachabilityStatus
import com.vainve.androidmacnotify.network.isMacFileSaveFailure
import com.vainve.androidmacnotify.network.isMacReceiverPaused
import com.vainve.androidmacnotify.network.isPermanentRelayAuthFailure
import com.vainve.androidmacnotify.network.isRetryableRelayFailure
import com.vainve.androidmacnotify.network.RelayApiException
import com.vainve.androidmacnotify.network.toRelayStatusMessage

internal data class SharedFileDeliveryFailure(
    val stage: SharedFileDeliveryStage,
    val message: String,
    val canRetry: Boolean,
    val failedCount: Int,
    val shouldStopBatch: Boolean,
    val reachabilityUpdate: SharedFileMacReachabilityUpdate? = null,
)

internal data class SharedFileMacReachabilityUpdate(
    val status: MacReachabilityStatus,
    val message: String?,
)

internal object SharedFileDeliveryFailurePolicy {
    private const val cancelledMessage = "已取消投递，未完成文件会被清理"

    fun forRelayFailure(
        error: Throwable,
        cancelToken: SharedFileTransferCancelToken,
        fallbackMessage: String = "文件投递失败，请重试",
    ): SharedFileDeliveryFailure {
        if (cancelToken.isCancelled) {
            return SharedFileDeliveryFailure(
                stage = SharedFileDeliveryStage.Cancelled,
                message = cancelledMessage,
                canRetry = true,
                failedCount = 1,
                shouldStopBatch = true,
            )
        }

        val message = error.toRelayStatusMessage(fallbackMessage)
        val reachabilityUpdate = reachabilityUpdateFor(error, message)
        return SharedFileDeliveryFailure(
            stage = SharedFileDeliveryStage.Failed,
            message = message,
            canRetry = shouldRetryRelayFailure(error),
            failedCount = 1,
            shouldStopBatch = shouldStopBatchForRelayFailure(error, reachabilityUpdate),
            reachabilityUpdate = reachabilityUpdate,
        )
    }

    fun forPayloadBuildFailure(
        error: Throwable,
        cancelToken: SharedFileTransferCancelToken,
    ): SharedFileDeliveryFailure {
        if (cancelToken.isCancelled) {
            return SharedFileDeliveryFailure(
                stage = SharedFileDeliveryStage.Cancelled,
                message = cancelledMessage,
                canRetry = true,
                failedCount = 0,
                shouldStopBatch = true,
            )
        }

        val canRetry = error !is SecurityException
        val message = if (error is SecurityException) {
            "原文件权限已失效，请重新从系统分享菜单或文件页选择文件。"
        } else {
            error.message ?: "文件读取失败，请重试"
        }

        return SharedFileDeliveryFailure(
            stage = SharedFileDeliveryStage.Failed,
            message = message,
            canRetry = canRetry,
            failedCount = 1,
            shouldStopBatch = false,
        )
    }

    private fun shouldStopBatchForRelayFailure(
        error: Throwable,
        reachabilityUpdate: SharedFileMacReachabilityUpdate,
    ): Boolean {
        val relayError = error as? RelayApiException
        if (relayError?.code == "FILE_SAVE_FAILED" && reachabilityUpdate.status == MacReachabilityStatus.Reachable) {
            return false
        }
        return true
    }

    private fun shouldRetryRelayFailure(error: Throwable): Boolean {
        return !error.isPermanentRelayAuthFailure() &&
            error.isRetryableRelayFailure(defaultValue = true)
    }

    private fun reachabilityUpdateFor(
        error: Throwable,
        fallbackMessage: String,
    ): SharedFileMacReachabilityUpdate {
        if (error.isMacFileSaveFailure()) {
            return SharedFileMacReachabilityUpdate(MacReachabilityStatus.Reachable, null)
        }

        val status = when {
            error.isPermanentRelayAuthFailure() -> MacReachabilityStatus.AuthFailed
            error.isMacReceiverPaused() -> MacReachabilityStatus.MacPaused
            else -> MacReachabilityStatus.Unreachable
        }
        val message = when (status) {
            MacReachabilityStatus.AuthFailed -> "旧配对已失效，请重新连接 Mac"
            MacReachabilityStatus.MacPaused -> "Mac 已暂停接收，重新开始后会继续接力"
            else -> error.toRelayStatusMessage(fallbackMessage)
        }
        return SharedFileMacReachabilityUpdate(status, message)
    }
}
