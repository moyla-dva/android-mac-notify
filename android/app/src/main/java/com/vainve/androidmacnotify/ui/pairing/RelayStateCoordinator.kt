package com.vainve.androidmacnotify.ui.pairing

import com.vainve.androidmacnotify.data.AppConfigStore
import com.vainve.androidmacnotify.data.MacReachabilityStatus
import com.vainve.androidmacnotify.network.RelayApi
import com.vainve.androidmacnotify.network.isMacReceiverPaused
import com.vainve.androidmacnotify.network.isPermanentRelayAuthFailure
import com.vainve.androidmacnotify.network.toRelayStatusMessage
import com.vainve.androidmacnotify.ui.PairingUiState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

internal class RelayStateCoordinator(
    private val relayApi: RelayApi,
    private val configStore: AppConfigStore,
    private val scope: CoroutineScope,
    private val readState: () -> PairingUiState,
    private val updateState: ((PairingUiState) -> PairingUiState) -> Unit,
) {
    fun setRelayEnabled(enabled: Boolean) {
        scope.launch {
            val snapshot = readState()
            configStore.setRelayEnabled(enabled)
            updateState {
                it.copy(
                    relayEnabled = enabled,
                    registrationStatus = if (enabled) {
                        "已恢复接力"
                    } else {
                        "已暂停接力"
                    },
                )
            }
            syncRelayStateWithMac(snapshot = snapshot, enabled = enabled)
        }
    }

    fun notifyMacBeforeForget(snapshot: PairingUiState) {
        val port = snapshot.port.toIntOrNull() ?: return
        val deviceToken = snapshot.deviceToken.takeIf { it.isNotBlank() } ?: return
        val host = snapshot.host.takeIf { it.isNotBlank() } ?: return
        val deviceId = snapshot.deviceId.takeIf { it.isNotBlank() } ?: return

        scope.launch(Dispatchers.IO) {
            relayApi.forgetSession(
                host = host,
                port = port,
                deviceToken = deviceToken,
                deviceId = deviceId,
            )
        }
    }

    private suspend fun syncRelayStateWithMac(snapshot: PairingUiState, enabled: Boolean) {
        val port = snapshot.port.toIntOrNull() ?: return
        val deviceToken = snapshot.deviceToken.takeIf { it.isNotBlank() } ?: return
        val host = snapshot.host.takeIf { it.isNotBlank() } ?: return
        val deviceId = snapshot.deviceId.takeIf { it.isNotBlank() } ?: return
        val relayState = if (enabled) "active" else "paused"

        val result = withContext(Dispatchers.IO) {
            relayApi.updateRelayState(
                host = host,
                port = port,
                deviceToken = deviceToken,
                deviceId = deviceId,
                relayState = relayState,
            )
        }

        result.onFailure {
            val reachabilityStatus = if (it.isPermanentRelayAuthFailure()) {
                MacReachabilityStatus.AuthFailed
            } else if (it.isMacReceiverPaused()) {
                MacReachabilityStatus.MacPaused
            } else {
                MacReachabilityStatus.Unreachable
            }
            configStore.updateMacReachability(
                reachabilityStatus,
                when (reachabilityStatus) {
                    MacReachabilityStatus.AuthFailed -> "旧配对已失效，请重新连接 Mac"
                    MacReachabilityStatus.MacPaused -> "Mac 已暂停接收，重新开始后会继续接力"
                    else -> it.toRelayStatusMessage("Mac 状态同步失败")
                },
            )
            updateState { current ->
                if (current.relayEnabled != enabled) {
                    current
                } else {
                    current.copy(
                        registrationStatus = if (enabled) {
                            "已恢复接力，Mac 状态同步失败"
                        } else {
                            "已暂停接力，Mac 状态同步失败"
                        },
                    )
                }
            }
        }.onSuccess { response ->
            if (!response.ok || response.sessionState == "unpaired") {
                configStore.updateMacReachability(
                    MacReachabilityStatus.AuthFailed,
                    "旧配对已失效，请重新连接 Mac",
                )
            } else if (response.sessionState == "mac_paused") {
                configStore.updateMacReachability(
                    MacReachabilityStatus.MacPaused,
                    "Mac 已暂停接收，重新开始后会继续接力",
                )
            } else {
                configStore.updateMacReachability(
                    if (enabled) MacReachabilityStatus.Reachable else MacReachabilityStatus.Paused,
                    if (enabled) null else "接力已暂停",
                )
            }
        }
    }
}
