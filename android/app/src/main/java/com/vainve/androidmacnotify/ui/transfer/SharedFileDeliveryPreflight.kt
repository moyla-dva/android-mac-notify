package com.vainve.androidmacnotify.ui.transfer

import com.vainve.androidmacnotify.ui.PairingUiState

internal data class SharedFileDeliveryTarget(
    val host: String,
    val port: Int,
    val deviceToken: String,
    val deviceId: String,
)

internal sealed class SharedFileDeliveryPreflightResult {
    data class Ready(val target: SharedFileDeliveryTarget) : SharedFileDeliveryPreflightResult()
    data class Failed(
        val message: String,
        val canRetry: Boolean,
    ) : SharedFileDeliveryPreflightResult()
}

internal object SharedFileDeliveryPreflight {
    fun check(snapshot: PairingUiState): SharedFileDeliveryPreflightResult {
        val port = snapshot.port.toIntOrNull()
        return when {
            !snapshot.relayEnabled -> SharedFileDeliveryPreflightResult.Failed(
                message = "手机端已暂停接力，恢复后再投递文件",
                canRetry = true,
            )
            snapshot.host.isBlank() || port == null || snapshot.deviceToken.isBlank() -> {
                SharedFileDeliveryPreflightResult.Failed(
                    message = "请先连接并配对 Mac 后再投递文件",
                    canRetry = false,
                )
            }
            else -> SharedFileDeliveryPreflightResult.Ready(
                target = SharedFileDeliveryTarget(
                    host = snapshot.host.trim(),
                    port = port,
                    deviceToken = snapshot.deviceToken,
                    deviceId = snapshot.deviceId,
                )
            )
        }
    }
}
