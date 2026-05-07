package com.vainve.androidmacnotify.ui.pairing

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Computer
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.vainve.androidmacnotify.ui.PairingUiState
import com.vainve.androidmacnotify.ui.discovery.DiscoveredMacDeviceUi
import com.vainve.androidmacnotify.ui.theme.AndroidMacNotifyTheme

@Composable
fun PairingSetupScreen(
    uiState: PairingUiState,
    onRegister: () -> Unit,
    onSetRelayEnabled: (Boolean) -> Unit,
    onRefreshConnectionStatus: () -> Unit,
    onRefreshDiscovery: () -> Unit,
    onSelectDiscoveredDevice: (DiscoveredMacDeviceUi) -> Unit,
    onOpenNotificationAccess: () -> Unit,
    onRequestPostNotificationsPermission: () -> Unit,
    onOpenBatteryOptimizationSettings: () -> Unit,
    onOpenReliabilitySettings: () -> Unit,
    modifier: Modifier = Modifier,
) {
    ScreenColumn(modifier = modifier) {
        PairingSetupContent(
            uiState = uiState,
            onRegister = onRegister,
            onSetRelayEnabled = onSetRelayEnabled,
            onRefreshConnectionStatus = onRefreshConnectionStatus,
            onRefreshDiscovery = onRefreshDiscovery,
            onSelectDiscoveredDevice = onSelectDiscoveredDevice,
            onOpenNotificationAccess = onOpenNotificationAccess,
            onRequestPostNotificationsPermission = onRequestPostNotificationsPermission,
            onOpenBatteryOptimizationSettings = onOpenBatteryOptimizationSettings,
            onOpenReliabilitySettings = onOpenReliabilitySettings,
        )
    }
}

@Composable
private fun PairingSetupContent(
    uiState: PairingUiState,
    onRegister: () -> Unit,
    onSetRelayEnabled: (Boolean) -> Unit,
    onRefreshConnectionStatus: () -> Unit,
    onRefreshDiscovery: () -> Unit,
    onSelectDiscoveredDevice: (DiscoveredMacDeviceUi) -> Unit,
    onOpenNotificationAccess: () -> Unit,
    onRequestPostNotificationsPermission: () -> Unit,
    onOpenBatteryOptimizationSettings: () -> Unit,
    onOpenReliabilitySettings: () -> Unit,
) {
    val isPaired = uiState.deviceToken.isNotBlank()
    val isWaitingForMac = uiState.isRegistering || uiState.pairingRequestId.isNotBlank()

    LaunchedEffect(uiState.deviceToken, uiState.relayEnabled) {
        if (isPaired && uiState.relayEnabled) {
            onRefreshConnectionStatus()
        }
    }

    AppHeader(
        title = "接力",
        subtitle = "",
    ) {
        TextButton(onClick = onOpenReliabilitySettings) {
            Icon(
                imageVector = Icons.Filled.Settings,
                contentDescription = null,
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text("可靠性")
        }
    }

    ConnectionHero(
        uiState = uiState,
        onSetRelayEnabled = onSetRelayEnabled,
    )

    NextStepCard(
        uiState = uiState,
        onOpenNotificationAccess = onOpenNotificationAccess,
        onRequestPostNotificationsPermission = onRequestPostNotificationsPermission,
        onOpenBatteryOptimizationSettings = onOpenBatteryOptimizationSettings,
        onRegister = onRegister,
    )

    if (!isPaired) {
        SectionHeader(
            title = if (isWaitingForMac) "正在确认" else "开始连接",
            subtitle = if (isWaitingForMac) {
                "Mac 允许后，这台手机会自动完成配对。"
            } else {
                "选择附近的 Mac，然后在 Mac 上确认这台手机。"
            },
            icon = Icons.Filled.Computer,
        )
        DiscoverySection(
            uiState = uiState,
            onRefreshDiscovery = onRefreshDiscovery,
            onSelectDiscoveredDevice = onSelectDiscoveredDevice,
        )
    }

}

@Preview(showBackground = true)
@Composable
fun PairingScreenPreview() {
    AndroidMacNotifyTheme {
        PairingSetupScreen(
            uiState = PairingUiState(
                deviceId = "android-123456",
                deviceDisplayName = "Mate40",
                host = "192.168.43.158",
                port = "38471",
                pairingToken = "pair_abcdef",
                discoveredDevices = listOf(
                    DiscoveredMacDeviceUi(
                        serviceName = "VaInve 的 MacBook Air",
                        macDeviceId = "mac-1",
                        macDisplayName = "VaInve 的 MacBook Air",
                        host = "192.168.43.158",
                        port = 38471,
                        isPaired = true,
                        isCurrentTarget = true,
                        status = "已配对，可自动连接",
                    ),
                ),
                registrationStatus = "尚未注册到 Mac",
            ),
            onRegister = {},
            onSetRelayEnabled = {},
            onRefreshConnectionStatus = {},
            onRefreshDiscovery = {},
            onSelectDiscoveredDevice = {},
            onOpenNotificationAccess = {},
            onRequestPostNotificationsPermission = {},
            onOpenBatteryOptimizationSettings = {},
            onOpenReliabilitySettings = {},
        )
    }
}
