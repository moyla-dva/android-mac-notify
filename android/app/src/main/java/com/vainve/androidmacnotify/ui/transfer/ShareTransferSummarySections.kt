package com.vainve.androidmacnotify.ui.transfer

import android.text.format.Formatter
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Error
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp

@Composable
internal fun TransferTerminalSummary(transfer: SharedFileTransferUi) {
    val isCancelled = transfer.stage == SharedFileDeliveryStage.Cancelled
    val containerColor = if (isCancelled) {
        MaterialTheme.colorScheme.tertiaryContainer
    } else {
        MaterialTheme.colorScheme.errorContainer
    }
    val contentColor = if (isCancelled) {
        MaterialTheme.colorScheme.onTertiaryContainer
    } else {
        MaterialTheme.colorScheme.onErrorContainer
    }
    val title = when {
        isCancelled -> "投递已取消"
        transfer.canRetry -> "可以重试投递"
        else -> "需要处理后再投递"
    }
    val description = when {
        isCancelled -> "未完成的文件不会留在 Mac 上，可以重新选择或重试。"
        transfer.canRetry -> "文件选择已保留，恢复连接或确认 Mac 可接收后可直接重试。"
        else -> "请按提示修复连接、权限或重新选择文件。"
    }

    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        color = containerColor,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = if (isCancelled) Icons.Filled.Cancel else Icons.Filled.Error,
                contentDescription = null,
                tint = contentColor,
                modifier = Modifier.size(26.dp),
            )
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(3.dp),
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleSmall,
                    color = contentColor,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    text = description,
                    style = MaterialTheme.typography.bodySmall,
                    color = contentColor,
                )
            }
        }
    }
}

@Composable
internal fun TransferCompletionSummary(transfer: SharedFileTransferUi) {
    val context = LocalContext.current
    val transferredLabel = transferredLabel(transfer, context)
    val completedCount = transfer.batchCompletedCount
        .coerceAtLeast(if (transfer.batchTotalCount > 1) transfer.batchTotalCount else 1)
    val title = if (transfer.batchTotalCount > 1) {
        "已完成 $completedCount 个文件"
    } else {
        "Mac 已收到文件"
    }
    val description = if (transfer.batchTotalCount > 1) {
        "文件会按投递顺序出现在 Mac 主面板。"
    } else {
        "文件卡片会出现在 Mac 主面板。"
    }

    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.primaryContainer,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = Icons.Filled.CheckCircle,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onPrimaryContainer,
                modifier = Modifier.size(26.dp),
            )
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(3.dp),
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleSmall,
                    color = MaterialTheme.colorScheme.onPrimaryContainer,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    text = transferredLabel?.let { "$description 已传 $it。" } ?: description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onPrimaryContainer,
                )
            }
        }
    }
}

@Composable
internal fun TransferSessionInfo(transfer: SharedFileTransferUi) {
    val context = LocalContext.current
    val transferredLabel = transferredLabel(transfer, context)
    val speedLabel = transfer.speedBytesPerSecond
        ?.takeIf { it > 0L }
        ?.let { "${Formatter.formatFileSize(context, it)}/s" }
        ?: if (transfer.stage == SharedFileDeliveryStage.Sending) "计算中" else null
    val remainingLabel = transfer.remainingSeconds
        ?.takeIf { transfer.stage.isActive && it > 0L }
        ?.let(::remainingTimeLabel)
    val secondaryProgressLabel = remainingLabel ?: when (transfer.stage) {
        SharedFileDeliveryStage.Success -> "已完成"
        SharedFileDeliveryStage.Cancelled -> "已取消"
        SharedFileDeliveryStage.Failed -> "已中断"
        SharedFileDeliveryStage.Cancelling -> "取消中"
        else -> "计算中"
    }

    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surfaceVariant,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (transferredLabel != null) {
                TransferMetric(
                    label = if (transfer.stage == SharedFileDeliveryStage.Success) "已完成" else "已传",
                    value = transferredLabel,
                    modifier = Modifier.fillMaxWidth(),
                    valueMaxLines = 2,
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                if (transfer.batchTotalCount > 1) {
                    TransferMetric(
                        label = "队列",
                        value = "${transfer.batchCompletedCount} / ${transfer.batchTotalCount}",
                        modifier = Modifier.weight(1f),
                    )
                }
                TransferMetric(
                    label = "方式",
                    value = transfer.transferModeLabel,
                    modifier = Modifier.weight(1f),
                )
                TransferMetric(
                    label = "任务",
                    value = transfer.transferId?.takeLast(8)?.uppercase() ?: "待创建",
                    modifier = Modifier.weight(1f),
                )
            }

            if (speedLabel != null || remainingLabel != null) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    TransferMetric(
                        label = "速度",
                        value = speedLabel ?: "待开始",
                        modifier = Modifier.weight(1f),
                    )
                    TransferMetric(
                        label = "预计剩余",
                        value = secondaryProgressLabel,
                        modifier = Modifier.weight(1f),
                    )
                }
            }
        }
    }
}

@Composable
private fun TransferMetric(
    label: String,
    value: String,
    modifier: Modifier = Modifier,
    valueMaxLines: Int = 1,
) {
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 1,
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface,
            fontWeight = FontWeight.Medium,
            maxLines = valueMaxLines,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
internal fun TransferProgressIndicator(transfer: SharedFileTransferUi) {
    val percent = transfer.progressPercent
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        if (percent == null) {
            LinearProgressIndicator(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(6.dp)
                    .clip(RoundedCornerShape(999.dp)),
            )
        } else {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(6.dp)
                    .clip(RoundedCornerShape(999.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant),
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth((percent / 100f).coerceIn(0f, 1f))
                        .height(6.dp)
                        .background(MaterialTheme.colorScheme.primary),
                )
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "上传进度",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    text = "$percent%",
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.primary,
                )
            }
        }
    }
}

@Composable
internal fun BatchProgressSummary(transfer: SharedFileTransferUi) {
    val label = batchProgressLabel(transfer)
    val progress = batchProgressFraction(transfer)

    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "文件队列",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                text = label,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.primary,
            )
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(5.dp)
                .clip(RoundedCornerShape(999.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(progress)
                    .height(5.dp)
                    .background(MaterialTheme.colorScheme.secondary),
            )
        }
    }
}

internal fun batchProgressLabel(transfer: SharedFileTransferUi): String {
    val total = transfer.batchTotalCount.coerceAtLeast(1)
    val completed = transfer.batchCompletedCount.coerceIn(0, total)
    val currentIndex = (transfer.batchCurrentIndex + 1).coerceIn(1, total)
    return when (transfer.stage) {
        SharedFileDeliveryStage.Success -> "全部完成 · $total 个"
        SharedFileDeliveryStage.Failed -> "中断 · 已完成 $completed / $total 个"
        SharedFileDeliveryStage.Cancelled -> "已取消 · 完成 $completed / $total 个"
        else -> "第 $currentIndex / $total 个 · 已完成 $completed 个"
    }
}

internal fun batchProgressFraction(transfer: SharedFileTransferUi): Float {
    val total = transfer.batchTotalCount
    if (total <= 0) return 0f
    return if (transfer.stage.isActive) {
        ((transfer.progressPercent ?: 0).coerceIn(0, 100).toFloat() / 100f)
            .coerceIn(0f, 1f)
    } else {
        val completed = transfer.batchCompletedCount.coerceIn(0, total)
        (completed.toFloat() / total.toFloat()).coerceIn(0f, 1f)
    }
}

private fun transferredLabel(transfer: SharedFileTransferUi, context: android.content.Context): String? {
    val sentBytes = transfer.sentBytes ?: return null
    val totalBytes = transfer.totalBytes
    return if (totalBytes != null && totalBytes > 0L) {
        "${Formatter.formatFileSize(context, sentBytes)} / ${Formatter.formatFileSize(context, totalBytes)}"
    } else {
        Formatter.formatFileSize(context, sentBytes)
    }
}

private fun remainingTimeLabel(seconds: Long): String {
    if (seconds <= 0L) return "即将完成"
    if (seconds < 60L) return "${seconds} 秒"

    val minutes = seconds / 60L
    val remainingSeconds = seconds % 60L
    if (minutes < 60L) {
        return if (remainingSeconds == 0L) {
            "${minutes} 分钟"
        } else {
            "${minutes} 分 ${remainingSeconds} 秒"
        }
    }

    val hours = minutes / 60L
    val remainingMinutes = minutes % 60L
    return if (remainingMinutes == 0L) {
        "${hours} 小时"
    } else {
        "${hours} 小时 ${remainingMinutes} 分"
    }
}
