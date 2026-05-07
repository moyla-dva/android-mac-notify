package com.vainve.androidmacnotify.ui.pairing

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.vainve.androidmacnotify.ui.PairingUiState
import com.vainve.androidmacnotify.ui.discovery.DiscoveredMacDeviceUi

@Composable
fun DeviceManagementScreen(
    uiState: PairingUiState,
    onHostChange: (String) -> Unit,
    onPortChange: (String) -> Unit,
    onDeviceDisplayNameChange: (String) -> Unit,
    onSaveDraft: () -> Unit,
    onRegister: () -> Unit,
    onForgetMacRegistration: () -> Unit,
    onRefreshDiscovery: () -> Unit,
    onSelectDiscoveredDevice: (DiscoveredMacDeviceUi) -> Unit,
    modifier: Modifier = Modifier,
) {
    var showDeviceNameEditor by remember { mutableStateOf(false) }
    val isPaired = uiState.deviceToken.isNotBlank()

    ScreenColumn(modifier = modifier) {
        AppHeader(
            title = "设备",
            subtitle = "管理这台手机连接的 Mac。",
        )
        DiscoverySection(
            uiState = uiState,
            onRefreshDiscovery = onRefreshDiscovery,
            onSelectDiscoveredDevice = onSelectDiscoveredDevice,
        )

        ManualConnectionSection(
            uiState = uiState,
            onHostChange = onHostChange,
            onPortChange = onPortChange,
            onSaveDraft = onSaveDraft,
            onRegister = onRegister,
            initiallyExpanded = !isPaired && uiState.discoveredDevices.isEmpty(),
        )

        DeviceIdentitySection(
            uiState = uiState,
            isEditing = showDeviceNameEditor,
            onToggleEditing = { showDeviceNameEditor = !showDeviceNameEditor },
            onDeviceDisplayNameChange = onDeviceDisplayNameChange,
            onSaveDraft = onSaveDraft,
        )

        if (isPaired) {
            ForgetPairedMacSection(onForgetMacRegistration = onForgetMacRegistration)
        }
    }
}
