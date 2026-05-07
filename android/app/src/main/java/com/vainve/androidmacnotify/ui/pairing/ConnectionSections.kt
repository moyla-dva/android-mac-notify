package com.vainve.androidmacnotify.ui.pairing

import android.text.format.DateUtils
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Computer
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.PhoneAndroid
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.vainve.androidmacnotify.data.MacReachabilityStatus
import com.vainve.androidmacnotify.ui.PairingUiState

@Composable
fun ConnectionHero(
    uiState: PairingUiState,
    onSetRelayEnabled: (Boolean) -> Unit,
) {
    val isPaired = uiState.deviceToken.isNotBlank()
    val isWaitingForMac = uiState.isRegistering || uiState.pairingRequestId.isNotBlank()
    val targetName = uiState.macDisplayName.ifBlank { uiState.host }.ifBlank { "附近的 Mac" }
    val isPaused = isPaired && (!uiState.relayEnabled || uiState.macReachabilityStatus == MacReachabilityStatus.Paused)
    val isConnected = isPaired &&
        uiState.relayEnabled &&
        uiState.macReachabilityStatus == MacReachabilityStatus.Reachable
    val isAuthFailed = isPaired && uiState.macReachabilityStatus == MacReachabilityStatus.AuthFailed
    val isMacPaused = isPaired && uiState.macReachabilityStatus == MacReachabilityStatus.MacPaused
    val isUnreachable = isPaired &&
        uiState.relayEnabled &&
        uiState.macReachabilityStatus == MacReachabilityStatus.Unreachable
    val isConfirming = isPaired &&
        uiState.relayEnabled &&
        uiState.macReachabilityStatus == MacReachabilityStatus.Unknown
    val title = when {
        isConnected -> "正在接力到 $targetName"
        isAuthFailed -> "配对已失效"
        isMacPaused -> "Mac 已暂停接收"
        isUnreachable -> "无法连接到 $targetName"
        isPaused -> "已暂停接力"
        isConfirming -> "正在确认 $targetName"
        isWaitingForMac -> "等待 Mac 确认"
        uiState.host.isNotBlank() -> "准备连接 $targetName"
        else -> "还没有连接 Mac"
    }
    val subtitle = when {
        isConnected -> "验证码、链接和文件会从这台手机接力到 Mac。"
        isAuthFailed -> uiState.macReachabilityMessage ?: "需要重新选择 Mac 并完成配对确认。"
        isMacPaused -> uiState.macReachabilityMessage ?: "Mac 接收器暂时不处理通知和文件，恢复后会继续接力。"
        isUnreachable -> uiState.macReachabilityMessage ?: "请确认 Mac 应用正在运行，并且两端在同一网络。"
        isPaused -> "不会向 Mac 发送通知和文件，配对仍保留。"
        isConfirming -> "正在通过心跳确认 Mac 是否在线。"
        isWaitingForMac -> "请在 Mac 上允许这台手机的配对请求。"
        uiState.host.isNotBlank() -> "确认后，这台手机就能开始协同。"
        else -> "保持手机和 Mac 在同一 Wi-Fi 或热点网络。"
    }

    ElevatedCard(
        modifier = Modifier
            .fillMaxWidth()
            .semantics {
                contentDescription = "协同连接状态，$title，$subtitle"
            },
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.elevatedCardColors(
            containerColor = MaterialTheme.colorScheme.primaryContainer,
        ),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                HeroDeviceNode(
                    icon = Icons.Filled.PhoneAndroid,
                    label = uiState.deviceDisplayName.ifBlank { "Android" },
                    isActive = true,
                )
                HeroSignalRail(
                    isActive = isConnected,
                    isWarning = isAuthFailed || isMacPaused || isUnreachable || isPaused || isConfirming || isWaitingForMac,
                    modifier = Modifier.weight(1f),
                )
                HeroDeviceNode(
                    icon = Icons.Filled.Computer,
                    label = if (isPaired || uiState.host.isNotBlank()) targetName else "Mac",
                    isActive = isPaired,
                )
            }

            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = title,
                        modifier = Modifier.weight(1f),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                    )
                    HeroStatusBadge(
                        label = when {
                            isConnected -> "可用"
                            isAuthFailed -> "需重新连接"
                            isMacPaused -> "Mac 暂停"
                            isUnreachable -> "不可达"
                            isPaused -> "已暂停"
                            isConfirming -> "确认中"
                            isWaitingForMac -> "确认中"
                            else -> "未连接"
                        },
                        isPositive = isConnected,
                        isWarning = isPaired || isWaitingForMac,
                    )
                }
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.74f),
                )
                if (isPaired) {
                    Text(
                        text = reachabilityFreshnessText(uiState),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.62f),
                    )
                }
            }

            if (isPaired) {
                if (uiState.relayEnabled) {
                    FilledTonalButton(
                        onClick = { onSetRelayEnabled(false) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(min = 46.dp),
                        colors = ButtonDefaults.filledTonalButtonColors(
                            containerColor = MaterialTheme.colorScheme.surface,
                            contentColor = MaterialTheme.colorScheme.primary,
                        ),
                    ) {
                        Text(if (isMacPaused) "暂停本机接力" else "暂停接力")
                    }
                } else {
                    Button(
                        onClick = { onSetRelayEnabled(true) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(min = 48.dp),
                    ) {
                        Text("恢复接力")
                    }
                }
            }
        }
    }
}

private fun reachabilityFreshnessText(uiState: PairingUiState): String {
    if (!uiState.relayEnabled || uiState.macReachabilityStatus == MacReachabilityStatus.Paused) {
        return "接力暂停期间不会主动发送到 Mac"
    }
    if (uiState.macReachabilityCheckedAt <= 0L) {
        return "尚未确认 Mac 在线状态"
    }
    val relativeTime = DateUtils.getRelativeTimeSpanString(
        uiState.macReachabilityCheckedAt,
        System.currentTimeMillis(),
        DateUtils.MINUTE_IN_MILLIS,
    )
    return "上次确认：$relativeTime"
}

@Composable
private fun HeroDeviceNode(
    icon: ImageVector,
    label: String,
    isActive: Boolean,
) {
    val containerColor = if (isActive) {
        MaterialTheme.colorScheme.surface.copy(alpha = 0.78f)
    } else {
        MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.55f)
    }
    val contentColor = if (isActive) {
        MaterialTheme.colorScheme.primary
    } else {
        MaterialTheme.colorScheme.onSurfaceVariant
    }

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
        modifier = Modifier.width(78.dp),
    ) {
        Surface(
            shape = CircleShape,
            color = containerColor,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = contentColor,
                modifier = Modifier
                    .padding(14.dp)
                    .size(26.dp),
            )
        }
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.74f),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun HeroSignalRail(
    isActive: Boolean,
    isWarning: Boolean,
    modifier: Modifier = Modifier,
) {
    val railColor = when {
        isActive -> MaterialTheme.colorScheme.primary
        isWarning -> MaterialTheme.colorScheme.tertiary
        else -> MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.22f)
    }
    Row(
        modifier = modifier.padding(horizontal = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(5.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        repeat(5) { index ->
            Surface(
                modifier = Modifier
                    .weight(1f)
                    .height(if (isActive || index == 2) 4.dp else 3.dp),
                shape = RoundedCornerShape(999.dp),
                color = railColor,
            ) {}
        }
    }
}

@Composable
private fun HeroStatusBadge(
    label: String,
    isPositive: Boolean,
    isWarning: Boolean,
) {
    val containerColor = when {
        isPositive -> MaterialTheme.colorScheme.secondaryContainer
        isWarning -> MaterialTheme.colorScheme.tertiaryContainer
        else -> MaterialTheme.colorScheme.surfaceVariant
    }
    val contentColor = when {
        isPositive -> MaterialTheme.colorScheme.onSecondaryContainer
        isWarning -> MaterialTheme.colorScheme.onTertiaryContainer
        else -> MaterialTheme.colorScheme.onSurfaceVariant
    }

    Surface(
        shape = RoundedCornerShape(999.dp),
        color = containerColor,
    ) {
        Text(
            text = label,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
            style = MaterialTheme.typography.labelMedium,
            color = contentColor,
            maxLines = 1,
        )
    }
}

@Composable
fun NextStepCard(
    uiState: PairingUiState,
    onOpenNotificationAccess: () -> Unit,
    onRequestPostNotificationsPermission: () -> Unit,
    onOpenBatteryOptimizationSettings: () -> Unit,
    onRegister: () -> Unit,
) {
    val isPaired = uiState.deviceToken.isNotBlank()
    val isWaitingForMac = uiState.isRegistering || uiState.pairingRequestId.isNotBlank()
    val targetName = uiState.macDisplayName.ifBlank { uiState.host }.ifBlank { "这台 Mac" }

    when {
        isPaired && uiState.relayEnabled && !uiState.notificationAccessEnabled -> {
            ActionPromptCard(
                icon = Icons.Filled.Notifications,
                title = "还需要开启通知访问",
                subtitle = "开启后，验证码和通知里的链接才会接力到 Mac。",
                actionLabel = "去开启",
                isWarning = true,
                onAction = onOpenNotificationAccess,
            )
        }

        isPaired && uiState.relayEnabled && !uiState.postNotificationsGranted -> {
            ActionPromptCard(
                icon = Icons.Filled.Notifications,
                title = "允许显示接力状态",
                subtitle = "前台运行通知能让系统更稳定地保留接力服务。",
                actionLabel = "允许",
                isWarning = true,
                onAction = onRequestPostNotificationsPermission,
            )
        }

        isPaired && uiState.relayEnabled && !uiState.batteryOptimizationIgnored -> {
            ActionPromptCard(
                icon = Icons.Filled.CheckCircle,
                title = "建议放行后台限制",
                subtitle = "锁屏后继续接力需要后台放行。若进入应用列表，请找到 Android Mac Notify 并设为不限制。",
                actionLabel = "去放行",
                isWarning = true,
                onAction = onOpenBatteryOptimizationSettings,
            )
        }

        !isPaired && isWaitingForMac -> {
            ActionPromptCard(
                icon = Icons.Filled.Computer,
                title = "等待 $targetName 确认",
                subtitle = "请在 Mac 上允许这台手机。确认后会自动完成连接。",
                actionLabel = null,
                isWarning = false,
                onAction = null,
            )
        }

        !isPaired && uiState.host.isNotBlank() -> {
            ActionPromptCard(
                icon = Icons.Filled.Computer,
                title = "准备连接 $targetName",
                subtitle = "向 Mac 发起确认请求，允许后即可开始接力。",
                actionLabel = "请求确认",
                isWarning = false,
                onAction = onRegister,
            )
        }
    }
}

@Composable
private fun ActionPromptCard(
    icon: ImageVector,
    title: String,
    subtitle: String,
    actionLabel: String?,
    isWarning: Boolean,
    onAction: (() -> Unit)?,
) {
    val iconContainerColor = if (isWarning) {
        MaterialTheme.colorScheme.tertiaryContainer
    } else {
        MaterialTheme.colorScheme.primaryContainer
    }
    val iconColor = if (isWarning) {
        MaterialTheme.colorScheme.onTertiaryContainer
    } else {
        MaterialTheme.colorScheme.onPrimaryContainer
    }

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
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Surface(
                shape = CircleShape,
                color = iconContainerColor,
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = iconColor,
                    modifier = Modifier
                        .padding(10.dp)
                        .size(20.dp),
                )
            }

            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Medium,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }

            if (actionLabel != null && onAction != null) {
                Button(
                    onClick = onAction,
                    modifier = Modifier.heightIn(min = 44.dp),
                ) {
                    Text(actionLabel)
                }
            }
        }
    }
}
