package com.vainve.androidmacnotify.ui

import android.content.Intent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.InsertDriveFile
import androidx.compose.material.icons.filled.Devices
import androidx.compose.material.icons.filled.PowerSettingsNew
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.navigation.NavHostController
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.vainve.androidmacnotify.data.SharedFileDeliveryRecord
import com.vainve.androidmacnotify.ui.discovery.DiscoveredMacDeviceUi
import com.vainve.androidmacnotify.ui.pairing.DeviceManagementScreen
import com.vainve.androidmacnotify.ui.pairing.PairingSetupScreen
import com.vainve.androidmacnotify.ui.pairing.ReliabilityScreen
import com.vainve.androidmacnotify.ui.pairing.ShareDeliveryScreen

private data class AppRoute(
    val route: String,
    val label: String,
    val icon: ImageVector,
) {
    companion object {
        val Relay = AppRoute("relay", "接力", Icons.Filled.PowerSettingsNew)
        val ShareDelivery = AppRoute("share_delivery", "文件", Icons.AutoMirrored.Filled.InsertDriveFile)
        val Devices = AppRoute("devices", "设备", Icons.Filled.Devices)
        val Reliability = AppRoute("reliability", "可靠性", Icons.Filled.Settings)
        val tabs = listOf(Relay, ShareDelivery, Devices)
    }
}

@Composable
fun AndroidMacNotifyApp(
    uiState: PairingUiState,
    pendingShareIntent: Intent?,
    onPendingShareIntentConsumed: () -> Unit,
    onHandleShareIntent: (Intent) -> Unit,
    onPickFilesRequested: () -> Unit,
    onRetrySharedFileTransfer: () -> Unit,
    onRetrySharedFileDeliveryRecord: (SharedFileDeliveryRecord) -> Unit,
    onCancelSharedFileTransfer: () -> Unit,
    onClearSharedFileDeliveryRecords: () -> Unit,
    onDismissCompletedSharedFileTransfer: (String?) -> Unit,
    onHostChange: (String) -> Unit,
    onPortChange: (String) -> Unit,
    onDeviceDisplayNameChange: (String) -> Unit,
    onSaveDraft: () -> Unit,
    onRegister: () -> Unit,
    onSetRelayEnabled: (Boolean) -> Unit,
    onRefreshConnectionStatus: () -> Unit,
    onForgetMacRegistration: () -> Unit,
    onRefreshDiscovery: () -> Unit,
    onSelectDiscoveredDevice: (DiscoveredMacDeviceUi) -> Unit,
    onOpenNotificationAccess: () -> Unit,
    onRequestPostNotificationsPermission: () -> Unit,
    onOpenBatteryOptimizationSettings: () -> Unit,
    modifier: Modifier = Modifier,
    navController: NavHostController = rememberNavController(),
) {
    LaunchedEffect(pendingShareIntent) {
        val intent = pendingShareIntent ?: return@LaunchedEffect
        val isShareIntent = intent.action == Intent.ACTION_SEND ||
            intent.action == Intent.ACTION_SEND_MULTIPLE

        onHandleShareIntent(intent)
        onPendingShareIntentConsumed()

        if (isShareIntent) {
            navController.navigate(AppRoute.ShareDelivery.route) {
                launchSingleTop = true
            }
        }
    }

    val currentBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = currentBackStackEntry?.destination?.route
    val selectedTabRoute = when (currentRoute) {
        AppRoute.Reliability.route -> AppRoute.Relay.route
        else -> currentRoute
    }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        bottomBar = {
            NavigationBar(
                containerColor = MaterialTheme.colorScheme.surface,
            ) {
                AppRoute.tabs.forEach { tab ->
                    NavigationBarItem(
                        selected = selectedTabRoute == tab.route,
                        onClick = {
                            navController.navigate(tab.route) {
                                popUpTo(AppRoute.Relay.route) {
                                    saveState = true
                                }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        icon = {
                            Icon(imageVector = tab.icon, contentDescription = null)
                        },
                        label = {
                            Text(tab.label)
                        },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = MaterialTheme.colorScheme.primary,
                            selectedTextColor = MaterialTheme.colorScheme.primary,
                            indicatorColor = MaterialTheme.colorScheme.primaryContainer,
                            unselectedIconColor = MaterialTheme.colorScheme.onSurfaceVariant,
                            unselectedTextColor = MaterialTheme.colorScheme.onSurfaceVariant,
                        ),
                    )
                }
            }
        },
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = AppRoute.Relay.route,
            modifier = Modifier.padding(innerPadding),
        ) {
            composable(AppRoute.Relay.route) {
                PairingSetupScreen(
                    uiState = uiState,
                    onRegister = onRegister,
                    onSetRelayEnabled = onSetRelayEnabled,
                    onRefreshConnectionStatus = onRefreshConnectionStatus,
                    onRefreshDiscovery = onRefreshDiscovery,
                    onSelectDiscoveredDevice = onSelectDiscoveredDevice,
                    onOpenNotificationAccess = onOpenNotificationAccess,
                    onRequestPostNotificationsPermission = onRequestPostNotificationsPermission,
                    onOpenBatteryOptimizationSettings = onOpenBatteryOptimizationSettings,
                    onOpenReliabilitySettings = {
                        navController.navigate(AppRoute.Reliability.route) {
                            launchSingleTop = true
                        }
                    },
                )
            }

            composable(AppRoute.ShareDelivery.route) {
                ShareDeliveryScreen(
                    uiState = uiState,
                    onSetRelayEnabled = onSetRelayEnabled,
                    onPickFilesRequested = onPickFilesRequested,
                    onRetrySharedFileTransfer = onRetrySharedFileTransfer,
                    onRetrySharedFileDeliveryRecord = onRetrySharedFileDeliveryRecord,
                    onCancelSharedFileTransfer = onCancelSharedFileTransfer,
                    onClearSharedFileDeliveryRecords = onClearSharedFileDeliveryRecords,
                    onDismissCompletedSharedFileTransfer = onDismissCompletedSharedFileTransfer,
                    onOpenDevices = {
                        navController.navigate(AppRoute.Devices.route) {
                            launchSingleTop = true
                        }
                    },
                )
            }

            composable(AppRoute.Devices.route) {
                DeviceManagementScreen(
                    uiState = uiState,
                    onHostChange = onHostChange,
                    onPortChange = onPortChange,
                    onDeviceDisplayNameChange = onDeviceDisplayNameChange,
                    onSaveDraft = onSaveDraft,
                    onRegister = onRegister,
                    onForgetMacRegistration = onForgetMacRegistration,
                    onRefreshDiscovery = onRefreshDiscovery,
                    onSelectDiscoveredDevice = onSelectDiscoveredDevice,
                )
            }

            composable(AppRoute.Reliability.route) {
                ReliabilityScreen(
                    uiState = uiState,
                    onOpenNotificationAccess = onOpenNotificationAccess,
                    onRequestPostNotificationsPermission = onRequestPostNotificationsPermission,
                    onOpenBatteryOptimizationSettings = onOpenBatteryOptimizationSettings,
                )
            }
        }
    }
}
