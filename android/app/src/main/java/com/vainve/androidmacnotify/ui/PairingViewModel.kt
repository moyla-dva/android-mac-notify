package com.vainve.androidmacnotify.ui

import android.app.Application
import android.content.Intent
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.vainve.androidmacnotify.data.AppConfig
import com.vainve.androidmacnotify.data.AppConfigStore
import com.vainve.androidmacnotify.data.MacReachabilityStatus
import com.vainve.androidmacnotify.data.RelayActivityRecord
import com.vainve.androidmacnotify.data.SharedFileDeliveryRecord
import com.vainve.androidmacnotify.network.PairRegistrationResult
import com.vainve.androidmacnotify.network.PairingApi
import com.vainve.androidmacnotify.network.RelayApi
import com.vainve.androidmacnotify.ui.discovery.DiscoveredMacDeviceUi
import com.vainve.androidmacnotify.ui.pairing.DeviceDiscoveryCoordinator
import com.vainve.androidmacnotify.ui.pairing.PairingRegistrationCoordinator
import com.vainve.androidmacnotify.ui.pairing.RelayStateCoordinator
import com.vainve.androidmacnotify.ui.pairing.SystemReliabilityCoordinator
import com.vainve.androidmacnotify.ui.transfer.SharedFileDeliveryCoordinator
import com.vainve.androidmacnotify.ui.transfer.SharedFileTransferManager
import com.vainve.androidmacnotify.ui.transfer.SharedFileTransferUi
import com.vainve.androidmacnotify.network.isMacReceiverPaused
import com.vainve.androidmacnotify.network.isPermanentRelayAuthFailure
import com.vainve.androidmacnotify.network.toRelayStatusMessage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

data class PairingUiState(
    val deviceId: String = "",
    val deviceDisplayName: String = "",
    val host: String = "",
    val port: String = "38471",
    val pairingToken: String = "",
    val deviceToken: String = "",
    val macDeviceId: String = "",
    val macDisplayName: String = "",
    val pairingRequestId: String = "",
    val discoveredDevices: List<DiscoveredMacDeviceUi> = emptyList(),
    val isDiscovering: Boolean = false,
    val discoveryStatus: String = "正在查找附近的 Mac...",
    val registrationStatus: String = "尚未注册到 Mac",
    val isRegistering: Boolean = false,
    val notificationAccessEnabled: Boolean = false,
    val postNotificationsGranted: Boolean = true,
    val batteryOptimizationIgnored: Boolean = true,
    val relayEnabled: Boolean = true,
    val notificationServiceLastActiveAt: Long = 0L,
    val macReachabilityStatus: MacReachabilityStatus = MacReachabilityStatus.Unknown,
    val macReachabilityCheckedAt: Long = 0L,
    val macReachabilityMessage: String? = null,
    val sharedFileTransfer: SharedFileTransferUi? = null,
    val sharedFileStatus: String? = null,
    val isSendingSharedFile: Boolean = false,
    val recentRelayActivities: List<RelayActivityRecord> = emptyList(),
    val recentSharedFileDeliveries: List<SharedFileDeliveryRecord> = emptyList(),
    val relayHint: String = "选择 Mac 后，在 Mac 上允许配对，再到系统通知访问里启用本应用。",
)

class PairingViewModel(application: Application) : AndroidViewModel(application) {
    private val configStore = AppConfigStore(application)
    private val systemReliabilityCoordinator = SystemReliabilityCoordinator(application)
    private val relayApi = RelayApi()
    private lateinit var deviceDiscoveryCoordinator: DeviceDiscoveryCoordinator
    private var lastReachabilityRefreshAt = 0L

    private val _uiState = MutableStateFlow(PairingUiState())
    val uiState: StateFlow<PairingUiState> = _uiState.asStateFlow()
    private val relayStateCoordinator = RelayStateCoordinator(
        relayApi = relayApi,
        configStore = configStore,
        scope = viewModelScope,
        readState = { _uiState.value },
        updateState = ::updateUiState,
    )
    private val sharedFileDeliveryCoordinator = SharedFileDeliveryCoordinator(
        transferManager = SharedFileTransferManager(application),
        scope = viewModelScope,
        readState = { _uiState.value },
        updateState = ::updateUiState,
        targetName = ::targetName,
        onRecordDelivery = ::recordSharedFileDelivery,
        onMacReachabilityChanged = ::recordMacReachability,
    )
    private val pairingRegistrationCoordinator = PairingRegistrationCoordinator(
        pairingApi = PairingApi(),
        configStore = configStore,
        scope = viewModelScope,
        readState = { _uiState.value },
        updateState = ::updateUiState,
        onRegistrationApplied = ::applyRegistration,
        onExistingPairingVerified = { macDeviceId ->
            deviceDiscoveryCoordinator.markExistingPairingVerified(macDeviceId)
        },
        onExistingPairingVerificationFailed = { macDeviceId ->
            deviceDiscoveryCoordinator.markExistingPairingVerificationFailed(macDeviceId)
        },
    )

    init {
        deviceDiscoveryCoordinator = DeviceDiscoveryCoordinator(
            context = application.applicationContext,
            configStore = configStore,
            scope = viewModelScope,
            readState = { _uiState.value },
            updateState = ::updateUiState,
            onVerifyExistingPairingOrRequestApproval = pairingRegistrationCoordinator::verifyExistingPairingOrRequestApproval,
            onRequestPairingApproval = pairingRegistrationCoordinator::requestPairingApproval,
        )
        viewModelScope.launch {
            configStore.initializeIfNeeded()
            refreshSystemReliabilityStatus()
            deviceDiscoveryCoordinator.start()
            configStore.configFlow.collect(::syncFromConfig)
        }
        viewModelScope.launch {
            configStore.sharedFileDeliveryRecordsFlow.collect { records ->
                _uiState.update {
                    it.copy(recentSharedFileDeliveries = records)
                }
            }
        }
        viewModelScope.launch {
            configStore.relayActivityRecordsFlow.collect { records ->
                _uiState.update {
                    it.copy(recentRelayActivities = records)
                }
            }
        }
    }

    private fun updateUiState(transform: (PairingUiState) -> PairingUiState) {
        _uiState.update(transform)
    }

    fun updateHost(value: String) {
        _uiState.update { it.copy(host = value) }
    }

    fun updatePort(value: String) {
        _uiState.update { it.copy(port = value) }
    }

    fun updatePairingToken(value: String) {
        _uiState.update { it.copy(pairingToken = value) }
    }

    fun updateDeviceDisplayName(value: String) {
        _uiState.update { it.copy(deviceDisplayName = value) }
    }

    fun saveDraft() {
        viewModelScope.launch {
            val snapshot = _uiState.value
            val port = snapshot.port.toIntOrNull() ?: 38471
            configStore.updateConnectionFields(
                host = snapshot.host,
                port = port,
                pairingToken = snapshot.pairingToken,
                deviceDisplayName = snapshot.deviceDisplayName,
            )
            _uiState.update { it.copy(registrationStatus = "配置已保存") }
        }
    }

    fun setRelayEnabled(enabled: Boolean) {
        relayStateCoordinator.setRelayEnabled(enabled)
    }

    fun forgetMacRegistration() {
        viewModelScope.launch {
            relayStateCoordinator.notifyMacBeforeForget(_uiState.value)
            configStore.forgetMacRegistration()
            deviceDiscoveryCoordinator.clearPairingVerificationState()
            _uiState.update {
                it.copy(
                    host = "",
                    port = "38471",
                    deviceToken = "",
                    macDeviceId = "",
                    macDisplayName = "",
                    pairingRequestId = "",
                    isRegistering = false,
                    relayEnabled = true,
                    macReachabilityStatus = MacReachabilityStatus.Unknown,
                    macReachabilityCheckedAt = 0L,
                    macReachabilityMessage = null,
                    registrationStatus = "已忘记这台 Mac",
                )
            }
            deviceDiscoveryCoordinator.updateDiscoveredDeviceList()
        }
    }

    fun refreshDiscovery() {
        deviceDiscoveryCoordinator.refresh()
    }

    fun selectDiscoveredDevice(device: DiscoveredMacDeviceUi) {
        deviceDiscoveryCoordinator.selectDiscoveredDevice(device)
    }

    fun registerWithMac() {
        val snapshot = _uiState.value
        val port = snapshot.port.toIntOrNull()
        if (snapshot.host.isBlank() || port == null) {
            _uiState.update { it.copy(registrationStatus = "请先选择附近的 Mac，或手动填写 Mac 地址和端口") }
            return
        }

        pairingRegistrationCoordinator.requestPairingApproval(host = snapshot.host.trim(), port = port)
    }

    fun notificationAccessIntent(): Intent {
        return systemReliabilityCoordinator.notificationAccessIntent()
    }

    fun batteryOptimizationIntent(): Intent {
        return systemReliabilityCoordinator.batteryOptimizationIntent()
    }

    fun refreshSystemReliabilityStatus() {
        val status = systemReliabilityCoordinator.currentStatus()
        _uiState.update {
            it.copy(
                notificationAccessEnabled = status.notificationAccessEnabled,
                postNotificationsGranted = status.postNotificationsGranted,
                batteryOptimizationIgnored = status.batteryOptimizationIgnored,
            )
        }
    }

    fun refreshConnectionStatus(force: Boolean = false) {
        val now = System.currentTimeMillis()
        if (!force && now - lastReachabilityRefreshAt < REACHABILITY_REFRESH_MIN_INTERVAL_MILLIS) {
            return
        }
        lastReachabilityRefreshAt = now

        viewModelScope.launch {
            val snapshot = _uiState.value
            if (!snapshot.relayEnabled) return@launch
            if (snapshot.macReachabilityStatus == MacReachabilityStatus.AuthFailed) return@launch
            val host = snapshot.host.takeIf { it.isNotBlank() } ?: return@launch
            val port = snapshot.port.toIntOrNull() ?: return@launch
            val deviceToken = snapshot.deviceToken.takeIf { it.isNotBlank() } ?: return@launch
            val deviceId = snapshot.deviceId.takeIf { it.isNotBlank() } ?: return@launch

            val result = withContext(Dispatchers.IO) {
                relayApi.sendHeartbeat(
                    host = host,
                    port = port,
                    deviceToken = deviceToken,
                    deviceId = deviceId,
                    networkType = "foreground",
                )
            }

            result.onSuccess { response ->
                when {
                    !response.acceptsSession -> configStore.updateMacReachability(
                        MacReachabilityStatus.AuthFailed,
                        "旧配对已失效，请重新连接 Mac",
                    )
                    response.sessionState == "mac_paused" -> configStore.updateMacReachability(
                        MacReachabilityStatus.MacPaused,
                        "Mac 已暂停接收，重新开始后会继续接力",
                    )
                    response.sessionState == "paused" -> configStore.updateMacReachability(
                        MacReachabilityStatus.Paused,
                        "接力已暂停",
                    )
                    else -> configStore.updateMacReachability(MacReachabilityStatus.Reachable)
                }
            }.onFailure { error ->
                when {
                    error.isPermanentRelayAuthFailure() -> configStore.updateMacReachability(
                        MacReachabilityStatus.AuthFailed,
                        "旧配对已失效，请重新连接 Mac",
                    )
                    error.isMacReceiverPaused() -> configStore.updateMacReachability(
                        MacReachabilityStatus.MacPaused,
                        "Mac 已暂停接收，重新开始后会继续接力",
                    )
                    else -> configStore.updateMacReachability(
                        MacReachabilityStatus.Unreachable,
                        error.toRelayStatusMessage("无法连接到 ${snapshot.macDisplayName.ifBlank { "Mac" }}"),
                    )
                }
            }
        }
    }

    fun handleShareIntent(intent: Intent) {
        sharedFileDeliveryCoordinator.handleShareIntent(intent)
    }

    fun handleSelectedFiles(uris: List<Uri>) {
        sharedFileDeliveryCoordinator.handleSelectedFiles(uris)
    }

    fun retrySharedFileTransfer() {
        sharedFileDeliveryCoordinator.retrySharedFileTransfer()
    }

    fun retrySharedFileDeliveryRecord(record: SharedFileDeliveryRecord) {
        sharedFileDeliveryCoordinator.retrySharedFileDeliveryRecord(record)
    }

    fun cancelSharedFileTransfer() {
        sharedFileDeliveryCoordinator.cancelSharedFileTransfer()
    }

    fun clearSharedFileDeliveryRecords() {
        viewModelScope.launch {
            configStore.clearSharedFileDeliveryRecords()
        }
    }

    fun dismissCompletedSharedFileTransfer(transferId: String?) {
        if (transferId == null) return
        _uiState.update {
            val currentTransfer = it.sharedFileTransfer ?: return@update it
            if (currentTransfer.transferId != transferId) return@update it
            it.copy(
                sharedFileTransfer = null,
                sharedFileStatus = null,
                isSendingSharedFile = false,
            )
        }
    }

    private fun recordSharedFileDelivery(record: SharedFileDeliveryRecord) {
        viewModelScope.launch {
            configStore.recordSharedFileDelivery(record)
        }
    }

    private fun recordMacReachability(status: MacReachabilityStatus, message: String?) {
        viewModelScope.launch {
            configStore.updateMacReachability(status, message)
        }
    }

    override fun onCleared() {
        pairingRegistrationCoordinator.cancel()
        deviceDiscoveryCoordinator.stop()
        super.onCleared()
    }

    private fun syncFromConfig(config: AppConfig) {
        _uiState.update {
            it.copy(
                deviceId = config.deviceId,
                deviceDisplayName = config.deviceDisplayName,
                host = config.host,
                port = config.port.toString(),
                pairingToken = config.pairingToken,
                deviceToken = config.deviceToken.orEmpty(),
                macDeviceId = config.macDeviceId.orEmpty(),
                macDisplayName = config.macDisplayName.orEmpty(),
                relayEnabled = config.relayEnabled,
                notificationServiceLastActiveAt = config.notificationServiceLastActiveAt,
                macReachabilityStatus = config.macReachabilityStatus,
                macReachabilityCheckedAt = config.macReachabilityCheckedAt,
                macReachabilityMessage = config.macReachabilityMessage,
                registrationStatus = if (it.isRegistering) {
                    it.registrationStatus
                } else if (config.deviceToken.isNullOrBlank()) {
                    it.registrationStatus
                } else {
                    registrationStatusFor(config)
                },
                sharedFileTransfer = it.sharedFileTransfer?.copy(
                    targetName = listOfNotNull(config.macDisplayName, config.host.takeIf { host -> host.isNotBlank() })
                        .firstOrNull()
                ),
            )
        }
        deviceDiscoveryCoordinator.updateDiscoveredDeviceList()
        sharedFileDeliveryCoordinator.markConfigLoaded()
    }

    private fun applyRegistration(result: PairRegistrationResult) {
        _uiState.update {
            it.copy(
                isRegistering = false,
                deviceToken = result.deviceToken,
                macDeviceId = result.macDeviceId,
                macDisplayName = result.macDisplayName,
                pairingRequestId = "",
                macReachabilityStatus = MacReachabilityStatus.Reachable,
                macReachabilityCheckedAt = System.currentTimeMillis(),
                macReachabilityMessage = null,
                registrationStatus = "已注册到 ${result.macDisplayName}",
            )
        }
        deviceDiscoveryCoordinator.updateDiscoveredDeviceList()
    }

    private fun targetName(state: PairingUiState): String? {
        return state.macDisplayName.ifBlank { state.host }.ifBlank { null }
    }

    private fun registrationStatusFor(config: AppConfig): String {
        val targetName = config.macDisplayName ?: config.host.takeIf { it.isNotBlank() } ?: "Mac"
        return when {
            !config.relayEnabled -> "已暂停接力"
            config.macReachabilityStatus == MacReachabilityStatus.Reachable -> "已连接到 $targetName"
            config.macReachabilityStatus == MacReachabilityStatus.AuthFailed -> "配对已失效，请重新连接 Mac"
            config.macReachabilityStatus == MacReachabilityStatus.MacPaused -> "Mac 已暂停接收"
            config.macReachabilityStatus == MacReachabilityStatus.Unreachable -> {
                config.macReachabilityMessage ?: "无法连接到 $targetName"
            }
            config.macReachabilityStatus == MacReachabilityStatus.Paused -> "已暂停接力"
            else -> "已注册到 $targetName，正在确认连接状态"
        }
    }

    private companion object {
        const val REACHABILITY_REFRESH_MIN_INTERVAL_MILLIS = 5_000L
    }

}
