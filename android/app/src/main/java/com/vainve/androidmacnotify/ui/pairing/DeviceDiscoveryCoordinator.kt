package com.vainve.androidmacnotify.ui.pairing

import android.content.Context
import com.vainve.androidmacnotify.data.AppConfigStore
import com.vainve.androidmacnotify.network.MacDiscoveryResult
import com.vainve.androidmacnotify.ui.PairingUiState
import com.vainve.androidmacnotify.ui.discovery.DiscoveredMacDeviceUi
import com.vainve.androidmacnotify.ui.discovery.MacDiscoveryCoordinator
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

internal class DeviceDiscoveryCoordinator(
    context: Context,
    private val configStore: AppConfigStore,
    private val scope: CoroutineScope,
    private val readState: () -> PairingUiState,
    private val updateState: ((PairingUiState) -> PairingUiState) -> Unit,
    private val onVerifyExistingPairingOrRequestApproval: (DiscoveredMacDeviceUi) -> Unit,
    private val onRequestPairingApproval: (host: String, port: Int) -> Unit,
) {
    private val macDiscoveryCoordinator = MacDiscoveryCoordinator(context, scope)
    private var verifiedPairedMacDeviceId: String? = null
    private var verifyingPairedMacDeviceId: String? = null

    fun start(clearExisting: Boolean = false) {
        if (clearExisting) {
            macDiscoveryCoordinator.clear()
        }
        updateState {
            it.copy(
                isDiscovering = true,
                discoveryStatus = "正在查找附近的 Mac...",
                discoveredDevices = if (clearExisting) emptyList() else it.discoveredDevices,
            )
        }

        macDiscoveryCoordinator.start(
            onStatus = { status ->
                updateState { it.copy(discoveryStatus = status, isDiscovering = status.contains("正在")) }
            },
            onDeviceListChanged = {
                updateDiscoveredDeviceList()
            },
            onDeviceResolved = { device ->
                autoConnectPairedDeviceIfNeeded(device)
            },
        )
    }

    fun refresh() {
        start(clearExisting = true)
    }

    fun stop() {
        macDiscoveryCoordinator.stop()
    }

    fun clearPairingVerificationState() {
        verifiedPairedMacDeviceId = null
        verifyingPairedMacDeviceId = null
    }

    fun markExistingPairingVerified(macDeviceId: String) {
        if (verifyingPairedMacDeviceId == macDeviceId) {
            verifyingPairedMacDeviceId = null
        }
        verifiedPairedMacDeviceId = macDeviceId
    }

    fun markExistingPairingVerificationFailed(macDeviceId: String) {
        if (verifyingPairedMacDeviceId == macDeviceId) {
            verifyingPairedMacDeviceId = null
        }
        if (verifiedPairedMacDeviceId == macDeviceId) {
            verifiedPairedMacDeviceId = null
        }
    }

    fun selectDiscoveredDevice(device: DiscoveredMacDeviceUi) {
        updateState {
            it.copy(
                host = device.host,
                port = device.port.toString(),
                registrationStatus = if (device.isPaired) {
                    "已选择已配对 Mac: ${device.macDisplayName}"
                } else {
                    "已选择 ${device.macDisplayName}，正在请求 Mac 确认"
                },
            )
        }

        if (device.isPaired) {
            onVerifyExistingPairingOrRequestApproval(device)
        } else {
            onRequestPairingApproval(device.host, device.port)
        }
    }

    fun updateDiscoveredDeviceList() {
        val snapshot = readState()
        val devices = macDiscoveryCoordinator.buildDeviceList(
            currentMacDeviceId = snapshot.macDeviceId,
            currentHost = snapshot.host,
            currentPort = snapshot.port.toIntOrNull(),
            hasDeviceToken = snapshot.deviceToken.isNotBlank(),
        )

        updateState {
            it.copy(
                discoveredDevices = devices,
                discoveryStatus = if (devices.isEmpty()) {
                    it.discoveryStatus
                } else {
                    "找到 ${devices.size} 台 Mac"
                },
                isDiscovering = false,
            )
        }
    }

    private fun autoConnectPairedDeviceIfNeeded(device: MacDiscoveryResult) {
        val snapshot = readState()
        val currentPort = snapshot.port.toIntOrNull()
        val isPairedDevice = snapshot.deviceToken.isNotBlank() &&
            snapshot.macDeviceId.isNotBlank() &&
            device.macDeviceId == snapshot.macDeviceId

        if (!isPairedDevice) return

        if (snapshot.host != device.host || currentPort != device.port) {
            updateState {
                it.copy(
                    host = device.host,
                    port = device.port.toString(),
                    registrationStatus = "已自动连接到 ${device.macDisplayName}",
                )
            }
            updateDiscoveredDeviceList()

            scope.launch {
                configStore.updateConnectionFields(
                    host = device.host,
                    port = device.port,
                    pairingToken = snapshot.pairingToken,
                    deviceDisplayName = snapshot.deviceDisplayName,
                )
            }
        }

        if (
            verifiedPairedMacDeviceId != device.macDeviceId &&
            verifyingPairedMacDeviceId != device.macDeviceId &&
            !snapshot.isRegistering &&
            snapshot.pairingRequestId.isBlank()
        ) {
            verifyingPairedMacDeviceId = device.macDeviceId
            onVerifyExistingPairingOrRequestApproval(
                DiscoveredMacDeviceUi(
                    serviceName = device.serviceName,
                    macDeviceId = device.macDeviceId,
                    macDisplayName = device.macDisplayName,
                    host = device.host,
                    port = device.port,
                    isPaired = true,
                    isCurrentTarget = true,
                    status = "正在确认配对状态",
                )
            )
        }
    }
}
