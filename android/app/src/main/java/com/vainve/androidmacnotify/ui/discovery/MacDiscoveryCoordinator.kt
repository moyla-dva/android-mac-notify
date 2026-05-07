package com.vainve.androidmacnotify.ui.discovery

import android.content.Context
import com.vainve.androidmacnotify.network.MacDiscoveryBrowser
import com.vainve.androidmacnotify.network.MacDiscoveryResult
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

data class DiscoveredMacDeviceUi(
    val serviceName: String,
    val macDeviceId: String,
    val macDisplayName: String,
    val host: String,
    val port: Int,
    val isPaired: Boolean,
    val isCurrentTarget: Boolean,
    val status: String,
)

class MacDiscoveryCoordinator(
    context: Context,
    private val scope: CoroutineScope,
) {
    private val discoveryBrowser = MacDiscoveryBrowser(context, scope)
    private val discoveredDevicesByService = mutableMapOf<String, MacDiscoveryResult>()

    fun start(
        onStatus: (String) -> Unit,
        onDeviceListChanged: () -> Unit,
        onDeviceResolved: (MacDiscoveryResult) -> Unit,
    ) {
        discoveryBrowser.start(
            onStatus = { status ->
                scope.launch {
                    onStatus(status)
                }
            },
            onDevice = { device ->
                scope.launch {
                    discoveredDevicesByService[device.serviceName.ifBlank { device.macDeviceId }] = device
                    onDeviceListChanged()
                    onDeviceResolved(device)
                }
            },
            onLost = { serviceName ->
                scope.launch {
                    discoveredDevicesByService.remove(serviceName)
                    onDeviceListChanged()
                }
            },
        )
    }

    fun clear() {
        discoveredDevicesByService.clear()
    }

    fun stop() {
        discoveryBrowser.stop()
    }

    fun buildDeviceList(
        currentMacDeviceId: String,
        currentHost: String,
        currentPort: Int?,
        hasDeviceToken: Boolean,
    ): List<DiscoveredMacDeviceUi> {
        return discoveredDevicesByService.values
            .sortedWith(compareByDescending<MacDiscoveryResult> { it.macDeviceId == currentMacDeviceId && hasDeviceToken }
                .thenBy { it.macDisplayName.lowercase() })
            .map { device ->
                val isPaired = hasDeviceToken &&
                    currentMacDeviceId.isNotBlank() &&
                    device.macDeviceId == currentMacDeviceId
                val isCurrentTarget = hasDeviceToken &&
                    device.host == currentHost &&
                    device.port == currentPort

                DiscoveredMacDeviceUi(
                    serviceName = device.serviceName,
                    macDeviceId = device.macDeviceId,
                    macDisplayName = device.macDisplayName,
                    host = device.host,
                    port = device.port,
                    isPaired = isPaired,
                    isCurrentTarget = isCurrentTarget,
                    status = when {
                        isPaired -> "已配对，可自动连接"
                        isCurrentTarget -> "当前连接目标，重新注册后可自动识别"
                        else -> "未配对，需要确认"
                    },
                )
            }
    }
}
