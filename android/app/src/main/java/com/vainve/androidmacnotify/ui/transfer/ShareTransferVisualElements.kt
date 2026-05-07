package com.vainve.androidmacnotify.ui.transfer

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.InsertDriveFile
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Error
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp

internal val SharedFileTransferUi.shouldShowFileInfo: Boolean
    get() = fileName.isNotBlank() &&
        fileName != "未知文件" &&
        fileName != "原文件无法访问"

internal val SharedFileDeliveryStage.isTerminal: Boolean
    get() = this == SharedFileDeliveryStage.Failed || this == SharedFileDeliveryStage.Cancelled

internal val SharedFileDeliveryStage.isActive: Boolean
    get() = this == SharedFileDeliveryStage.ReadingConfig ||
        this == SharedFileDeliveryStage.Preparing ||
        this == SharedFileDeliveryStage.Sending ||
        this == SharedFileDeliveryStage.Cancelling

internal val SharedFileDeliveryStage.isRetryableTerminal: Boolean
    get() = this == SharedFileDeliveryStage.Failed ||
        this == SharedFileDeliveryStage.Cancelled

internal fun stageTitle(stage: SharedFileDeliveryStage): String {
    return when (stage) {
        SharedFileDeliveryStage.ReadingConfig -> "正在连接"
        SharedFileDeliveryStage.Preparing -> "正在准备"
        SharedFileDeliveryStage.Sending -> "正在发送"
        SharedFileDeliveryStage.Cancelling -> "正在取消"
        SharedFileDeliveryStage.Cancelled -> "已取消投递"
        SharedFileDeliveryStage.Success -> "投递完成"
        SharedFileDeliveryStage.Failed -> "投递失败"
    }
}

@Composable
internal fun StatusIcon(stage: SharedFileDeliveryStage) {
    val icon = when (stage) {
        SharedFileDeliveryStage.Success -> Icons.Filled.CheckCircle
        SharedFileDeliveryStage.Cancelled -> Icons.Filled.Cancel
        SharedFileDeliveryStage.Failed -> Icons.Filled.Error
        else -> Icons.AutoMirrored.Filled.Send
    }
    val backgroundColor = when (stage) {
        SharedFileDeliveryStage.Success -> MaterialTheme.colorScheme.primaryContainer
        SharedFileDeliveryStage.Cancelled -> MaterialTheme.colorScheme.tertiaryContainer
        SharedFileDeliveryStage.Failed -> MaterialTheme.colorScheme.errorContainer
        else -> MaterialTheme.colorScheme.secondaryContainer
    }
    val foregroundColor = when (stage) {
        SharedFileDeliveryStage.Success -> MaterialTheme.colorScheme.onPrimaryContainer
        SharedFileDeliveryStage.Cancelled -> MaterialTheme.colorScheme.onTertiaryContainer
        SharedFileDeliveryStage.Failed -> MaterialTheme.colorScheme.onErrorContainer
        else -> MaterialTheme.colorScheme.onSecondaryContainer
    }

    Box(
        modifier = Modifier
            .size(56.dp)
            .clip(CircleShape)
            .background(backgroundColor),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = foregroundColor,
            modifier = Modifier.size(28.dp),
        )
    }
}

@Composable
internal fun FileInfoRow(transfer: SharedFileTransferUi) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surfaceVariant,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.InsertDriveFile,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(28.dp),
            )

            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(
                    text = transfer.fileName,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Medium,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = transfer.fileMetaLabel,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
internal fun DeliveryStepRow(transfer: SharedFileTransferUi) {
    val stage = transfer.stage
    val steps = listOf("配置", "准备", "发送", "完成")
    val activeIndex = when (stage) {
        SharedFileDeliveryStage.ReadingConfig -> 0
        SharedFileDeliveryStage.Preparing -> 1
        SharedFileDeliveryStage.Sending -> 2
        SharedFileDeliveryStage.Cancelling -> 2
        SharedFileDeliveryStage.Success -> 3
        SharedFileDeliveryStage.Cancelled,
        SharedFileDeliveryStage.Failed -> transfer.lastKnownStepIndex()
    }

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        steps.forEachIndexed { index, label ->
            DeliveryStep(
                label = label,
                isActive = index == activeIndex && stage.isActive,
                isDone = stage == SharedFileDeliveryStage.Success || index < activeIndex,
                isFailed = stage == SharedFileDeliveryStage.Failed && index == activeIndex,
                isCancelled = stage == SharedFileDeliveryStage.Cancelled && index == activeIndex,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun DeliveryStep(
    label: String,
    isActive: Boolean,
    isDone: Boolean,
    isFailed: Boolean,
    isCancelled: Boolean,
    modifier: Modifier = Modifier,
) {
    val containerColor = when {
        isFailed -> MaterialTheme.colorScheme.errorContainer
        isCancelled -> MaterialTheme.colorScheme.tertiaryContainer
        isDone || isActive -> MaterialTheme.colorScheme.primaryContainer
        else -> MaterialTheme.colorScheme.surfaceVariant
    }
    val contentColor = when {
        isFailed -> MaterialTheme.colorScheme.onErrorContainer
        isCancelled -> MaterialTheme.colorScheme.onTertiaryContainer
        isDone || isActive -> MaterialTheme.colorScheme.onPrimaryContainer
        else -> MaterialTheme.colorScheme.onSurfaceVariant
    }

    Surface(
        modifier = modifier.heightIn(min = 36.dp),
        shape = RoundedCornerShape(999.dp),
        color = containerColor,
    ) {
        Box(
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 8.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelMedium,
                color = contentColor,
                maxLines = 1,
            )
        }
    }
}

@Composable
internal fun TransferStatusBadge(
    label: String,
    isPositive: Boolean,
) {
    val containerColor = if (isPositive) {
        MaterialTheme.colorScheme.secondaryContainer
    } else {
        MaterialTheme.colorScheme.errorContainer
    }
    val contentColor = if (isPositive) {
        MaterialTheme.colorScheme.onSecondaryContainer
    } else {
        MaterialTheme.colorScheme.onErrorContainer
    }

    Surface(
        shape = RoundedCornerShape(999.dp),
        color = containerColor,
    ) {
        Text(
            text = label,
            modifier = Modifier.padding(horizontal = 9.dp, vertical = 5.dp),
            style = MaterialTheme.typography.labelMedium,
            color = contentColor,
            maxLines = 1,
        )
    }
}

private fun SharedFileTransferUi.lastKnownStepIndex(): Int {
    return when {
        progressPercent != null || sentBytes != null -> 2
        totalBytes != null || transferId != null -> 1
        else -> 0
    }
}

private val SharedFileTransferUi.fileMetaLabel: String
    get() {
        val size = sizeLabel ?: "大小未知"
        return if (batchTotalCount > 1) {
            "已完成 ${batchCompletedCount.coerceIn(0, batchTotalCount)} / $batchTotalCount 个"
        } else {
            size
        }
    }
