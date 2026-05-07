package com.vainve.androidmacnotify.network

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.Collections

class MacDiscoveryBrowser(
    context: Context,
    private val scope: CoroutineScope,
    private val discoveryApi: DiscoveryApi = DiscoveryApi(),
) {
    companion object {
        const val SERVICE_TYPE = "_amnotify._tcp."
        private const val TAG = "MacDiscoveryBrowser"
    }

    private val nsdManager = context.getSystemService(Context.NSD_SERVICE) as NsdManager
    private var discoveryListener: NsdManager.DiscoveryListener? = null
    private val resolvingServices = Collections.synchronizedSet(mutableSetOf<String>())

    fun start(
        onStatus: (String) -> Unit,
        onDevice: (MacDiscoveryResult) -> Unit,
        onLost: (String) -> Unit,
    ) {
        stop()

        val listener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(regType: String) {
                onStatus("正在查找附近的 Mac...")
            }

            override fun onServiceFound(service: NsdServiceInfo) {
                if (!sameServiceType(service.serviceType, SERVICE_TYPE)) return
                resolve(service, onStatus, onDevice)
            }

            override fun onServiceLost(service: NsdServiceInfo) {
                resolvingServices.remove(service.serviceName)
                onLost(service.serviceName)
            }

            override fun onDiscoveryStopped(serviceType: String) {
                onStatus("已停止查找 Mac")
            }

            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                onStatus("查找 Mac 失败: $errorCode")
                runCatching { nsdManager.stopServiceDiscovery(this) }
                if (discoveryListener === this) {
                    discoveryListener = null
                }
                resolvingServices.clear()
            }

            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {
                Log.w(TAG, "Stop discovery failed: $errorCode")
                runCatching { nsdManager.stopServiceDiscovery(this) }
            }
        }

        discoveryListener = listener
        nsdManager.discoverServices(SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, listener)
    }

    fun stop() {
        val listener = discoveryListener ?: return
        runCatching { nsdManager.stopServiceDiscovery(listener) }
        discoveryListener = null
        resolvingServices.clear()
    }

    private fun resolve(
        service: NsdServiceInfo,
        onStatus: (String) -> Unit,
        onDevice: (MacDiscoveryResult) -> Unit,
    ) {
        val key = service.serviceName
        if (!resolvingServices.add(key)) return

        nsdManager.resolveService(
            service,
            object : NsdManager.ResolveListener {
                override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                    resolvingServices.remove(key)
                    onStatus("发现 ${serviceInfo.serviceName}，但解析失败: $errorCode")
                }

                override fun onServiceResolved(serviceInfo: NsdServiceInfo) {
                    resolvingServices.remove(key)
                    val host = serviceInfo.host?.hostAddress ?: return
                    val port = serviceInfo.port.takeIf { it > 0 } ?: return

                    scope.launch(Dispatchers.IO) {
                        discoveryApi.fetchDiscovery(host, port)
                            .onSuccess { result ->
                                onDevice(result.copy(serviceName = serviceInfo.serviceName))
                            }
                            .onFailure { error ->
                                Log.w(TAG, "Discovery endpoint failed for $host:$port", error)
                                onStatus("发现 ${serviceInfo.serviceName}，但无法读取设备信息")
                            }
                    }
                }
            },
        )
    }

    private fun sameServiceType(lhs: String?, rhs: String): Boolean {
        return lhs.orEmpty().trimEnd('.') == rhs.trimEnd('.')
    }
}
