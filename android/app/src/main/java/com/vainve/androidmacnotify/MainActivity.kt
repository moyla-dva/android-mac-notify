package com.vainve.androidmacnotify

import android.Manifest
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.vainve.androidmacnotify.ui.AndroidMacNotifyApp
import com.vainve.androidmacnotify.ui.PairingViewModel
import com.vainve.androidmacnotify.ui.theme.AndroidMacNotifyTheme

class MainActivity : ComponentActivity() {
    private var incomingShareIntent by mutableStateOf<Intent?>(null)
    private val pairingViewModel: PairingViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        incomingShareIntent = intent
        enableEdgeToEdge()
        setContent {
            AndroidMacNotifyTheme {
                val uiState by pairingViewModel.uiState.collectAsState()
                val shareIntent = incomingShareIntent
                val notificationAccessLauncher = rememberLauncherForActivityResult(
                    contract = ActivityResultContracts.StartActivityForResult(),
                    onResult = { pairingViewModel.refreshSystemReliabilityStatus() },
                )
                val postNotificationsLauncher = rememberLauncherForActivityResult(
                    contract = ActivityResultContracts.RequestPermission(),
                    onResult = { pairingViewModel.refreshSystemReliabilityStatus() },
                )
                val batteryOptimizationLauncher = rememberLauncherForActivityResult(
                    contract = ActivityResultContracts.StartActivityForResult(),
                    onResult = { pairingViewModel.refreshSystemReliabilityStatus() },
                )
                val filePickerLauncher = rememberLauncherForActivityResult(
                    contract = ActivityResultContracts.OpenMultipleDocuments(),
                    onResult = { uris ->
                        uris.forEach { uri ->
                            try {
                                contentResolver.takePersistableUriPermission(
                                    uri,
                                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                                )
                            } catch (_: SecurityException) {
                                // Some providers grant a temporary read permission only.
                            }
                        }
                        pairingViewModel.handleSelectedFiles(uris)
                    },
                )

                AndroidMacNotifyApp(
                    uiState = uiState,
                    pendingShareIntent = shareIntent,
                    onPendingShareIntentConsumed = { incomingShareIntent = null },
                    onHandleShareIntent = pairingViewModel::handleShareIntent,
                    onPickFilesRequested = {
                        filePickerLauncher.launch(arrayOf("*/*"))
                    },
                    onRetrySharedFileTransfer = pairingViewModel::retrySharedFileTransfer,
                    onRetrySharedFileDeliveryRecord = pairingViewModel::retrySharedFileDeliveryRecord,
                    onCancelSharedFileTransfer = pairingViewModel::cancelSharedFileTransfer,
                    onClearSharedFileDeliveryRecords = pairingViewModel::clearSharedFileDeliveryRecords,
                    onDismissCompletedSharedFileTransfer = pairingViewModel::dismissCompletedSharedFileTransfer,
                    onHostChange = pairingViewModel::updateHost,
                    onPortChange = pairingViewModel::updatePort,
                    onDeviceDisplayNameChange = pairingViewModel::updateDeviceDisplayName,
                    onSaveDraft = pairingViewModel::saveDraft,
                    onRegister = pairingViewModel::registerWithMac,
                    onSetRelayEnabled = pairingViewModel::setRelayEnabled,
                    onRefreshConnectionStatus = {
                        pairingViewModel.refreshConnectionStatus(force = true)
                    },
                    onForgetMacRegistration = pairingViewModel::forgetMacRegistration,
                    onRefreshDiscovery = pairingViewModel::refreshDiscovery,
                    onSelectDiscoveredDevice = pairingViewModel::selectDiscoveredDevice,
                    onOpenNotificationAccess = {
                        notificationAccessLauncher.launch(pairingViewModel.notificationAccessIntent())
                    },
                    onRequestPostNotificationsPermission = {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            postNotificationsLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                        } else {
                            pairingViewModel.refreshSystemReliabilityStatus()
                        }
                    },
                    onOpenBatteryOptimizationSettings = {
                        batteryOptimizationLauncher.launch(pairingViewModel.batteryOptimizationIntent())
                    },
                )
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        incomingShareIntent = intent
    }

    override fun onResume() {
        super.onResume()
        pairingViewModel.refreshSystemReliabilityStatus()
        pairingViewModel.refreshConnectionStatus()
    }
}
