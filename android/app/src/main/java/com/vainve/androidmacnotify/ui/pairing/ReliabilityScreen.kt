package com.vainve.androidmacnotify.ui.pairing

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BatteryChargingFull
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import com.vainve.androidmacnotify.ui.PairingUiState

private const val RELAY_SERVICE_ACTIVE_FRESH_MILLIS = 90_000L

@Composable
fun ReliabilityScreen(
    uiState: PairingUiState,
    onOpenNotificationAccess: () -> Unit,
    onRequestPostNotificationsPermission: () -> Unit,
    onOpenBatteryOptimizationSettings: () -> Unit,
    modifier: Modifier = Modifier,
) {
    ScreenColumn(modifier = modifier) {
        AppHeader(
            title = "可靠性",
            subtitle = "让锁屏后接力更稳定。",
        )

        ReliabilitySettingsSection(
            uiState = uiState,
            onOpenNotificationAccess = onOpenNotificationAccess,
            onRequestPostNotificationsPermission = onRequestPostNotificationsPermission,
            onOpenBatteryOptimizationSettings = onOpenBatteryOptimizationSettings,
        )
    }
}

@Composable
private fun ReliabilitySettingsSection(
    uiState: PairingUiState,
    onOpenNotificationAccess: () -> Unit,
    onRequestPostNotificationsPermission: () -> Unit,
    onOpenBatteryOptimizationSettings: () -> Unit,
) {
    val serviceDisplay = relayServiceDisplay(uiState.notificationServiceLastActiveAt)

    ReliabilitySettingRow(
        icon = Icons.Filled.Notifications,
        title = "接力服务",
        subtitle = serviceDisplay.subtitle,
        status = serviceDisplay.status,
        isReady = serviceDisplay.isReady,
        actionLabel = null,
        onAction = {},
    )
    ReliabilitySettingRow(
        icon = Icons.Filled.Notifications,
        title = "通知访问",
        subtitle = "用于读取手机通知并生成 Mac 动作。",
        status = if (uiState.notificationAccessEnabled) "已开启" else "待开启",
        isReady = uiState.notificationAccessEnabled,
        actionLabel = if (uiState.notificationAccessEnabled) null else "去开启",
        onAction = onOpenNotificationAccess,
    )
    ReliabilitySettingRow(
        icon = Icons.Filled.Notifications,
        title = "系统通知",
        subtitle = "用于显示前台服务状态，让接力更不容易被系统回收。",
        status = if (uiState.postNotificationsGranted) "已允许" else "待允许",
        isReady = uiState.postNotificationsGranted,
        actionLabel = if (uiState.postNotificationsGranted) null else "允许",
        onAction = onRequestPostNotificationsPermission,
    )
    ReliabilitySettingRow(
        icon = Icons.Filled.BatteryChargingFull,
        title = "后台限制",
        subtitle = "点击后按系统提示放行；若进入列表页，请找到 Android Mac Notify 并设为不限制。",
        status = if (uiState.batteryOptimizationIgnored) "已放行" else "建议放行",
        isReady = uiState.batteryOptimizationIgnored,
        actionLabel = if (uiState.batteryOptimizationIgnored) null else "去放行",
        onAction = onOpenBatteryOptimizationSettings,
    )
}

@Composable
private fun ReliabilitySettingRow(
    icon: ImageVector,
    title: String,
    subtitle: String,
    status: String,
    isReady: Boolean,
    actionLabel: String?,
    onAction: () -> Unit,
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        color = MaterialTheme.colorScheme.surface,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(24.dp),
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleSmall,
                )
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Column(
                horizontalAlignment = androidx.compose.ui.Alignment.End,
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                StatusBadge(
                    label = status,
                    isPositive = isReady,
                    isWarning = !isReady,
                )
                if (actionLabel != null) {
                    Button(
                        onClick = onAction,
                        modifier = Modifier.heightIn(min = 40.dp),
                    ) {
                        Text(actionLabel)
                    }
                }
            }
        }
    }
}

private data class RelayServiceDisplay(
    val status: String,
    val subtitle: String,
    val isReady: Boolean,
)

private fun relayServiceDisplay(
    lastActiveAt: Long,
    now: Long = System.currentTimeMillis(),
): RelayServiceDisplay {
    if (lastActiveAt <= 0L) {
        return RelayServiceDisplay(
            status = "待启动",
            subtitle = "等待系统启动通知监听服务；开启通知访问后通常会自动启动。",
            isReady = false,
        )
    }

    val elapsed = (now - lastActiveAt).coerceAtLeast(0L)
    val lastActiveText = when {
        elapsed < 60_000L -> "刚刚活跃"
        elapsed < 60 * 60_000L -> "${elapsed / 60_000L} 分钟前活跃"
        else -> "${elapsed / (60 * 60_000L)} 小时前活跃"
    }

    return if (elapsed <= RELAY_SERVICE_ACTIVE_FRESH_MILLIS) {
        RelayServiceDisplay(
            status = "运行中",
            subtitle = "通知监听服务$lastActiveText，锁屏后仍会继续尝试接力。",
            isReady = true,
        )
    } else {
        RelayServiceDisplay(
            status = "可能受限",
            subtitle = "通知监听服务$lastActiveText；若收不到通知，请检查后台限制。",
            isReady = false,
        )
    }
}
