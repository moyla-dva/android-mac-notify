package com.vainve.androidmacnotify.ui.pairing

import android.util.Log
import com.vainve.androidmacnotify.data.AppConfigStore
import com.vainve.androidmacnotify.data.MacReachabilityStatus
import com.vainve.androidmacnotify.network.PairApprovalStartResult
import com.vainve.androidmacnotify.network.PairApprovalStatusResult
import com.vainve.androidmacnotify.network.PairRegistrationResult
import com.vainve.androidmacnotify.network.PairingApi
import com.vainve.androidmacnotify.ui.PairingUiState
import com.vainve.androidmacnotify.ui.discovery.DiscoveredMacDeviceUi
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class PairingRegistrationCoordinator(
    private val pairingApi: PairingApi,
    private val configStore: AppConfigStore,
    private val scope: CoroutineScope,
    private val readState: () -> PairingUiState,
    private val updateState: ((PairingUiState) -> PairingUiState) -> Unit,
    private val onRegistrationApplied: (PairRegistrationResult) -> Unit,
    private val onExistingPairingVerified: (String) -> Unit = {},
    private val onExistingPairingVerificationFailed: (String) -> Unit = {},
) {
    private var pairingApprovalPollJob: Job? = null

    fun cancel() {
        pairingApprovalPollJob?.cancel()
        pairingApprovalPollJob = null
    }

    fun requestPairingApproval(host: String, port: Int) {
        cancel()
        scope.launch {
            val snapshot = readState()
            updateState {
                it.copy(
                    isRegistering = true,
                    registrationStatus = "正在向 Mac 发送配对请求...",
                )
            }

            val result = withContext(Dispatchers.IO) {
                pairingApi.requestPairingApproval(
                    host = host,
                    port = port,
                    deviceId = snapshot.deviceId,
                    deviceDisplayName = snapshot.deviceDisplayName.trim(),
                )
            }

            result.onSuccess { approval ->
                configStore.updateConnectionFields(
                    host = host,
                    port = port,
                    pairingToken = "",
                    deviceDisplayName = snapshot.deviceDisplayName,
                )
                updateState {
                    it.copy(
                        host = host,
                        port = port.toString(),
                        pairingToken = "",
                        pairingRequestId = approval.requestId,
                        macDeviceId = approval.macDeviceId,
                        macDisplayName = approval.macDisplayName,
                        registrationStatus = "请在 Mac 上允许 ${snapshot.deviceDisplayName} 的配对请求",
                    )
                }
                startPairingApprovalPolling(
                    host = host,
                    port = port,
                    approval = approval,
                )
            }.onFailure { error ->
                Log.e("AndroidMacNotify", "Pair approval request failed", error)
                updateState {
                    it.copy(
                        isRegistering = false,
                        pairingRequestId = "",
                        registrationStatus = error.message ?: "注册失败",
                    )
                }
            }
        }
    }

    fun verifyExistingPairingOrRequestApproval(device: DiscoveredMacDeviceUi) {
        scope.launch {
            val snapshot = readState()
            updateState {
                it.copy(registrationStatus = "正在确认 ${device.macDisplayName} 是否仍信任本机...")
            }

            val result = withContext(Dispatchers.IO) {
                pairingApi.checkSessionStatus(
                    host = device.host,
                    port = device.port,
                    deviceToken = snapshot.deviceToken,
                    deviceId = snapshot.deviceId,
                )
            }

            result.onSuccess {
                onExistingPairingVerified(device.macDeviceId)
                configStore.updateConnectionFields(
                    host = device.host,
                    port = device.port,
                    pairingToken = snapshot.pairingToken,
                    deviceDisplayName = snapshot.deviceDisplayName,
                )
                configStore.updateMacReachability(MacReachabilityStatus.Reachable)
                updateState {
                    it.copy(registrationStatus = "已连接到 ${device.macDisplayName}")
                }
            }.onFailure {
                onExistingPairingVerificationFailed(device.macDeviceId)
                updateState {
                    it.copy(registrationStatus = "旧配对已失效，正在请求 Mac 重新确认")
                }
                requestPairingApproval(host = device.host, port = device.port)
            }
        }
    }

    private fun startPairingApprovalPolling(
        host: String,
        port: Int,
        approval: PairApprovalStartResult,
    ) {
        cancel()
        pairingApprovalPollJob = scope.launch {
            val pollAfterMillis = approval.pollAfterMillis.coerceIn(1_000L, 5_000L)
            while (isActive) {
                delay(pollAfterMillis)

                val deviceId = readState().deviceId
                val result = withContext(Dispatchers.IO) {
                    pairingApi.pollPairingApprovalStatus(
                        host = host,
                        port = port,
                        requestId = approval.requestId,
                        deviceId = deviceId,
                    )
                }

                result.onSuccess { status ->
                    val shouldStop = handlePairingApprovalStatus(status, host, port)
                    if (shouldStop) return@launch
                }.onFailure { error ->
                    Log.e("AndroidMacNotify", "Pair approval polling failed", error)
                    updateState {
                        it.copy(
                            isRegistering = false,
                            pairingRequestId = "",
                            registrationStatus = error.message ?: "配对确认失败，请重新发起请求",
                        )
                    }
                    return@launch
                }
            }
        }
    }

    private fun handlePairingApprovalStatus(
        status: PairApprovalStatusResult,
        host: String,
        port: Int,
    ): Boolean {
        return when (status.status) {
            "approved" -> {
                val registration = status.registration
                if (registration == null) {
                    updateState {
                        it.copy(
                            isRegistering = false,
                            pairingRequestId = "",
                            registrationStatus = "Mac 已允许，但没有返回注册信息，请重试",
                        )
                    }
                    true
                } else {
                    scope.launch {
                        val snapshot = readState()
                        configStore.updateConnectionFields(
                            host = host,
                            port = port,
                            pairingToken = "",
                            deviceDisplayName = snapshot.deviceDisplayName,
                        )
                        configStore.saveRegistration(
                            deviceToken = registration.deviceToken,
                            macDeviceId = registration.macDeviceId,
                            macDisplayName = registration.macDisplayName,
                        )
                    }
                    onRegistrationApplied(registration)
                    true
                }
            }
            "rejected" -> {
                updateState {
                    it.copy(
                        isRegistering = false,
                        pairingRequestId = "",
                        registrationStatus = "Mac 已拒绝配对请求",
                    )
                }
                true
            }
            "expired" -> {
                updateState {
                    it.copy(
                        isRegistering = false,
                        pairingRequestId = "",
                        registrationStatus = "配对请求已过期，请重新发起",
                    )
                }
                true
            }
            else -> {
                updateState {
                    it.copy(
                        isRegistering = true,
                        registrationStatus = "等待 Mac 确认配对...",
                    )
                }
                false
            }
        }
    }
}
