package com.vainve.androidmacnotify.ui.pairing

import android.text.format.DateUtils
import android.text.format.Formatter
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.InsertDriveFile
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Computer
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.History
import androidx.compose.material3.Button
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedCard
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.vainve.androidmacnotify.data.SharedFileDeliveryRecord
import com.vainve.androidmacnotify.data.SharedFileDeliveryRecordStatus
import com.vainve.androidmacnotify.ui.PairingUiState
import com.vainve.androidmacnotify.ui.transfer.ShareTransferCard
import com.vainve.androidmacnotify.ui.transfer.SharedFileDeliveryStage
import com.vainve.androidmacnotify.ui.transfer.SharedFileTransferUi
import kotlinx.coroutines.delay

private const val SINGLE_FILE_COMPLETED_AUTO_DISMISS_MILLIS = 1_800L
private const val BATCH_COMPLETED_AUTO_DISMISS_MILLIS = 2_400L
private const val RECENT_FILE_DELIVERY_VISIBLE_LIMIT = 6

@Composable
fun ShareDeliveryScreen(
    uiState: PairingUiState,
    onSetRelayEnabled: (Boolean) -> Unit,
    onPickFilesRequested: () -> Unit,
    onRetrySharedFileTransfer: () -> Unit,
    onRetrySharedFileDeliveryRecord: (SharedFileDeliveryRecord) -> Unit,
    onCancelSharedFileTransfer: () -> Unit,
    onClearSharedFileDeliveryRecords: () -> Unit,
    onDismissCompletedSharedFileTransfer: (String?) -> Unit,
    onOpenDevices: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val shareTransfer = uiState.sharedFileTransfer
    val transferId = shareTransfer?.transferId
    val batchTotalCount = shareTransfer?.batchTotalCount ?: 1

    LaunchedEffect(shareTransfer?.stage, transferId, batchTotalCount) {
        if (shareTransfer?.stage == SharedFileDeliveryStage.Success) {
            val autoDismissDelay = if (batchTotalCount > 1) {
                BATCH_COMPLETED_AUTO_DISMISS_MILLIS
            } else {
                SINGLE_FILE_COMPLETED_AUTO_DISMISS_MILLIS
            }
            delay(autoDismissDelay)
            onDismissCompletedSharedFileTransfer(transferId)
        }
    }

    ScreenColumn(modifier = modifier) {
        if (shareTransfer == null) {
            FileDeliveryIdleContent(
                uiState = uiState,
                onSetRelayEnabled = onSetRelayEnabled,
                onPickFilesRequested = onPickFilesRequested,
                onRetryRecord = onRetrySharedFileDeliveryRecord,
                onClearRecords = onClearSharedFileDeliveryRecords,
                onOpenDevices = onOpenDevices,
            )
        } else {
            ShareDeliveryContent(
                uiState = uiState,
                transfer = shareTransfer,
                onSetRelayEnabled = onSetRelayEnabled,
                onPickFilesRequested = onPickFilesRequested,
                onRetrySharedFileTransfer = onRetrySharedFileTransfer,
                onCancelSharedFileTransfer = onCancelSharedFileTransfer,
                onRetryRecord = onRetrySharedFileDeliveryRecord,
                onClearRecords = onClearSharedFileDeliveryRecords,
                onOpenDevices = onOpenDevices,
            )
        }
    }
}

@Composable
private fun ShareDeliveryContent(
    uiState: PairingUiState,
    transfer: SharedFileTransferUi,
    onSetRelayEnabled: (Boolean) -> Unit,
    onPickFilesRequested: () -> Unit,
    onRetrySharedFileTransfer: () -> Unit,
    onCancelSharedFileTransfer: () -> Unit,
    onRetryRecord: (SharedFileDeliveryRecord) -> Unit,
    onClearRecords: () -> Unit,
    onOpenDevices: () -> Unit,
) {
    AppHeader(
        title = "文件投递",
        subtitle = "把手机里的文件发送到 Mac。",
    )

    ShareTransferCard(
        transfer = transfer,
        onRetry = onRetrySharedFileTransfer,
        onCancel = onCancelSharedFileTransfer,
        onContinue = onPickFilesRequested,
    )

    if (uiState.deviceToken.isBlank()) {
        DevicePagePromptCard(
            title = "还没有连接 Mac",
            message = "先到设备页选择或手动连接一台 Mac，之后再回到这里投递文件。",
            actionText = "去设备页连接",
            onAction = onOpenDevices,
        )
    } else if (!uiState.relayEnabled) {
        Button(
            onClick = { onSetRelayEnabled(true) },
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 48.dp),
        ) {
            Text("恢复接力")
        }
    } else {
        Text(
            text = "完成后，Mac 主面板会出现文件卡片，可打开、定位或复制路径。",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }

    RecentFileDeliveriesSection(
        records = uiState.recentSharedFileDeliveries.visibleOutsideCurrentTransfer(transfer),
        onRetryRecord = onRetryRecord,
        onClearRecords = onClearRecords,
    )
}

@Composable
private fun FileDeliveryIdleContent(
    uiState: PairingUiState,
    onSetRelayEnabled: (Boolean) -> Unit,
    onPickFilesRequested: () -> Unit,
    onRetryRecord: (SharedFileDeliveryRecord) -> Unit,
    onClearRecords: () -> Unit,
    onOpenDevices: () -> Unit,
) {
    val isPaired = uiState.deviceToken.isNotBlank()
    val isReady = isPaired && uiState.relayEnabled

    AppHeader(
        title = "文件投递",
        subtitle = "选择文件，或从系统分享菜单发送到 Mac。",
    )

    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Surface(
                shape = RoundedCornerShape(18.dp),
                color = if (isReady) {
                    MaterialTheme.colorScheme.primaryContainer
                } else {
                    MaterialTheme.colorScheme.tertiaryContainer
                },
            ) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.InsertDriveFile,
                    contentDescription = null,
                    tint = if (isReady) {
                        MaterialTheme.colorScheme.onPrimaryContainer
                    } else {
                        MaterialTheme.colorScheme.onTertiaryContainer
                    },
                    modifier = Modifier
                        .padding(14.dp)
                        .size(30.dp),
                )
            }

            Text(
                text = when {
                    isReady -> "选择要投递的文件"
                    isPaired -> "接力已暂停"
                    else -> "先连接一台 Mac"
                },
                style = MaterialTheme.typography.titleLarge,
            )
            Text(
                text = when {
                    isReady -> "将发送到 ${uiState.fileTargetName()}。也可以在相册、文件管理器或浏览器里用系统分享。"
                    isPaired -> "恢复接力后，文件会继续发送到 ${uiState.fileTargetName()}。"
                    else -> "连接并配对后，文件会直接保存到 Mac 的下载目录。"
                },
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            if (isReady) {
                Button(
                    onClick = onPickFilesRequested,
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 48.dp),
                ) {
                    Text("选择文件")
                }
            } else if (uiState.deviceToken.isNotBlank() && !uiState.relayEnabled) {
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

    if (!isPaired) {
        DevicePagePromptCard(
            title = "还没有连接 Mac",
            message = "设备发现、配对和手动地址都在设备页处理。连接后这里会直接投递文件。",
            actionText = "去设备页连接",
            onAction = onOpenDevices,
        )
    }

    RecentFileDeliveriesSection(
        records = uiState.recentSharedFileDeliveries,
        onRetryRecord = onRetryRecord,
        onClearRecords = onClearRecords,
    )
}

@Composable
private fun DevicePagePromptCard(
    title: String,
    message: String,
    actionText: String,
    onAction: () -> Unit,
) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = Icons.Filled.Computer,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(28.dp),
            )
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    text = message,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            FilledTonalButton(onClick = onAction) {
                Text(actionText)
            }
        }
    }
}

@Composable
private fun RecentFileDeliveriesSection(
    records: List<SharedFileDeliveryRecord>,
    onRetryRecord: (SharedFileDeliveryRecord) -> Unit,
    onClearRecords: () -> Unit,
) {
    if (records.isEmpty()) return
    val visibleRecords = records.take(RECENT_FILE_DELIVERY_VISIBLE_LIMIT)
    val hiddenCount = records.size - visibleRecords.size

    SectionHeader(
        title = "最近结果",
        subtitle = if (hiddenCount > 0) {
            "显示最近 ${visibleRecords.size} 条，失败或取消可从这里重试。"
        } else {
            "成功少量保留，失败或取消可从这里重试。"
        },
        icon = Icons.Filled.History,
    )

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.End,
    ) {
        OutlinedButton(onClick = onClearRecords) {
            Text("清空记录")
        }
    }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        visibleRecords.forEach { record ->
            RecentFileDeliveryRow(
                record = record,
                onRetry = { onRetryRecord(record) },
            )
        }
    }
}

@Composable
private fun RecentFileDeliveryRow(
    record: SharedFileDeliveryRecord,
    onRetry: () -> Unit,
) {
    val context = LocalContext.current
    val sizeLabel = record.totalBytes?.let { Formatter.formatFileSize(context, it) }
    val metaParts = listOfNotNull(
        if (record.fileCount > 1) {
            "${record.completedCount} / ${record.fileCount} 个"
        } else {
            sizeLabel ?: "1 个文件"
        },
        sizeLabel?.takeIf { record.fileCount > 1 },
        record.targetName,
        deliveryTimeLabel(record.finishedAt),
    )

    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Surface(
                shape = RoundedCornerShape(14.dp),
                color = deliveryStatusContainerColor(record.status),
            ) {
                Icon(
                    imageVector = deliveryStatusIcon(record.status),
                    contentDescription = null,
                    tint = deliveryStatusContentColor(record.status),
                    modifier = Modifier
                        .padding(10.dp)
                        .size(24.dp),
                )
            }

            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = record.fileName,
                        modifier = Modifier.weight(1f),
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Medium,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    StatusBadge(
                        label = deliveryStatusLabel(record.status),
                        isPositive = record.status == SharedFileDeliveryRecordStatus.Success,
                        isWarning = record.status == SharedFileDeliveryRecordStatus.Cancelled,
                    )
                }
                Text(
                    text = metaParts.joinToString(" · "),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = record.message,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                if (record.canRetryFromHistory) {
                    if (record.status == SharedFileDeliveryRecordStatus.Failed) {
                        Button(
                            onClick = onRetry,
                            modifier = Modifier.heightIn(min = 40.dp),
                        ) {
                            Text("重试投递")
                        }
                    } else {
                        FilledTonalButton(
                            onClick = onRetry,
                            modifier = Modifier.heightIn(min = 40.dp),
                        ) {
                            Text("重试投递")
                        }
                    }
                }
            }
        }
    }
}

private fun deliveryStatusIcon(status: SharedFileDeliveryRecordStatus): ImageVector {
    return when (status) {
        SharedFileDeliveryRecordStatus.Success -> Icons.Filled.CheckCircle
        SharedFileDeliveryRecordStatus.Cancelled -> Icons.Filled.Cancel
        SharedFileDeliveryRecordStatus.Failed -> Icons.Filled.Error
    }
}

private fun deliveryStatusLabel(status: SharedFileDeliveryRecordStatus): String {
    return when (status) {
        SharedFileDeliveryRecordStatus.Success -> "完成"
        SharedFileDeliveryRecordStatus.Cancelled -> "取消"
        SharedFileDeliveryRecordStatus.Failed -> "失败"
    }
}

private val SharedFileDeliveryRecord.canRetryFromHistory: Boolean
    get() = sourceUris.isNotEmpty() &&
        canRetry &&
        (status == SharedFileDeliveryRecordStatus.Failed || status == SharedFileDeliveryRecordStatus.Cancelled)

@Composable
private fun deliveryStatusContainerColor(status: SharedFileDeliveryRecordStatus) = when (status) {
    SharedFileDeliveryRecordStatus.Success -> MaterialTheme.colorScheme.primaryContainer
    SharedFileDeliveryRecordStatus.Cancelled -> MaterialTheme.colorScheme.tertiaryContainer
    SharedFileDeliveryRecordStatus.Failed -> MaterialTheme.colorScheme.errorContainer
}

@Composable
private fun deliveryStatusContentColor(status: SharedFileDeliveryRecordStatus) = when (status) {
    SharedFileDeliveryRecordStatus.Success -> MaterialTheme.colorScheme.onPrimaryContainer
    SharedFileDeliveryRecordStatus.Cancelled -> MaterialTheme.colorScheme.onTertiaryContainer
    SharedFileDeliveryRecordStatus.Failed -> MaterialTheme.colorScheme.onErrorContainer
}

private fun deliveryTimeLabel(finishedAt: Long): String {
    if (finishedAt <= 0L) return "刚刚"
    return DateUtils.getRelativeTimeSpanString(
        finishedAt,
        System.currentTimeMillis(),
        DateUtils.MINUTE_IN_MILLIS,
    ).toString()
}

private fun PairingUiState.fileTargetName(): String {
    return macDisplayName.ifBlank { "已配对 Mac" }
}

private fun List<SharedFileDeliveryRecord>.visibleOutsideCurrentTransfer(
    transfer: SharedFileTransferUi,
): List<SharedFileDeliveryRecord> {
    val activeRecordId = transfer.transferId
        ?.takeIf { transfer.stage == SharedFileDeliveryStage.Success }
        ?: return this
    return filterNot { it.recordId == activeRecordId }
}
