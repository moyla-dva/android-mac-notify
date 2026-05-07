package com.vainve.androidmacnotify.notify

import android.content.Context
import com.vainve.androidmacnotify.data.AppConfig
import com.vainve.androidmacnotify.data.AppConfigStore
import com.vainve.androidmacnotify.data.MacReachabilityStatus
import com.vainve.androidmacnotify.network.RelayApi
import com.vainve.androidmacnotify.network.isMacReceiverPaused
import com.vainve.androidmacnotify.network.isPermanentRelayAuthFailure
import com.vainve.androidmacnotify.network.isRetryableRelayFailure
import com.vainve.androidmacnotify.network.toRelayStatusMessage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

internal enum class HeartbeatOutcome {
    Ready,
    TemporaryFailure,
    MacPaused,
    PermanentFailure,
    Skipped,
}

internal class RelayHeartbeatCoordinator(
    private val context: Context,
    private val relayApi: RelayApi,
    private val appConfigStore: AppConfigStore,
    private val scope: CoroutineScope,
    private val currentConfig: suspend () -> AppConfig,
    private val flushPendingNotificationsIfDue: suspend (AppConfig, String, Boolean) -> Boolean,
) {
    private companion object {
        const val HEARTBEAT_INTERVAL_MILLIS = 30_000L
        const val HEARTBEAT_RECOVERY_INTERVAL_MILLIS = 8_000L
    }

    private var heartbeatJob: Job? = null

    fun start() {
        if (heartbeatJob?.isActive == true) return

        heartbeatJob = scope.launch {
            delay(2_000L)
            while (true) {
                val outcome = sendAndUpdateStatus(currentConfig(), forceFlushPending = false)
                delay(nextHeartbeatDelay(outcome))
            }
        }
    }

    suspend fun sendAndUpdateStatus(
        config: AppConfig,
        forceFlushPending: Boolean,
    ): HeartbeatOutcome {
        appConfigStore.recordNotificationServiceActive()

        if (!config.relayEnabled) {
            if (config.macReachabilityStatus != MacReachabilityStatus.Paused) {
                appConfigStore.updateMacReachability(MacReachabilityStatus.Paused, "接力已暂停")
            }
            return HeartbeatOutcome.Skipped
        }

        val deviceToken = config.deviceToken ?: return HeartbeatOutcome.Skipped
        if (config.host.isBlank()) return HeartbeatOutcome.Skipped

        val result = relayApi.sendHeartbeat(
            host = config.host,
            port = config.port,
            deviceToken = deviceToken,
            deviceId = config.deviceId,
            networkType = inferNetworkType(context),
        )

        return result.fold(
            onSuccess = { response ->
                if (!response.acceptsSession) {
                    appConfigStore.updateMacReachability(
                        MacReachabilityStatus.AuthFailed,
                        "旧配对已失效，请重新连接 Mac",
                    )
                    HeartbeatOutcome.PermanentFailure
                } else if (response.sessionState == "mac_paused") {
                    appConfigStore.updateMacReachability(
                        MacReachabilityStatus.MacPaused,
                        "Mac 已暂停接收，重新开始后会继续接力",
                    )
                    HeartbeatOutcome.MacPaused
                } else {
                    appConfigStore.updateMacReachability(MacReachabilityStatus.Reachable)
                    if (flushPendingNotificationsIfDue(config, deviceToken, forceFlushPending)) {
                        HeartbeatOutcome.Ready
                    } else {
                        HeartbeatOutcome.TemporaryFailure
                    }
                }
            },
            onFailure = { error ->
                if (error.isPermanentRelayAuthFailure()) {
                    appConfigStore.updateMacReachability(
                        MacReachabilityStatus.AuthFailed,
                        "旧配对已失效，请重新连接 Mac",
                    )
                    HeartbeatOutcome.PermanentFailure
                } else if (error.isMacReceiverPaused()) {
                    appConfigStore.updateMacReachability(
                        MacReachabilityStatus.MacPaused,
                        "Mac 已暂停接收，重新开始后会继续接力",
                    )
                    HeartbeatOutcome.MacPaused
                } else {
                    appConfigStore.updateMacReachability(
                        MacReachabilityStatus.Unreachable,
                        error.toRelayStatusMessage("无法连接到 ${config.macDisplayName ?: "Mac"}"),
                    )
                    if (error.isRetryableRelayFailure()) {
                        HeartbeatOutcome.TemporaryFailure
                    } else {
                        HeartbeatOutcome.PermanentFailure
                    }
                }
            },
        )
    }

    private fun nextHeartbeatDelay(outcome: HeartbeatOutcome): Long {
        return when (outcome) {
            HeartbeatOutcome.TemporaryFailure,
            HeartbeatOutcome.MacPaused -> HEARTBEAT_RECOVERY_INTERVAL_MILLIS
            HeartbeatOutcome.Ready,
            HeartbeatOutcome.PermanentFailure,
            HeartbeatOutcome.Skipped -> HEARTBEAT_INTERVAL_MILLIS
        }
    }
}

private fun inferNetworkType(context: Context): String {
    return runCatching {
        val connectivityManager =
            context.getSystemService(Context.CONNECTIVITY_SERVICE) as android.net.ConnectivityManager
        val capabilities = connectivityManager.getNetworkCapabilities(connectivityManager.activeNetwork)
        when {
            capabilities == null -> "unknown"
            capabilities.hasTransport(android.net.NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
            capabilities.hasTransport(android.net.NetworkCapabilities.TRANSPORT_CELLULAR) -> "hotspot"
            else -> "unknown"
        }
    }.getOrDefault("unknown")
}
