package com.vainve.androidmacnotify.ui.transfer

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

@Composable
fun ShareTransferCard(
    transfer: SharedFileTransferUi,
    onRetry: () -> Unit,
    onCancel: () -> Unit,
    onContinue: (() -> Unit)? = null,
) {
    ElevatedCard(
        modifier = Modifier
            .fillMaxWidth()
            .semantics {
                contentDescription = "文件投递状态，${transfer.fileName}，${transfer.message}"
            },
        colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = RoundedCornerShape(24.dp),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                StatusIcon(stage = transfer.stage)

                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Text(
                        text = stageTitle(transfer.stage),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Text(
                        text = transfer.message,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            if (transfer.shouldShowFileInfo) {
                FileInfoRow(transfer)
            }

            if (transfer.stage == SharedFileDeliveryStage.Success) {
                TransferCompletionSummary(transfer)
                if (onContinue != null) {
                    Button(
                        onClick = onContinue,
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(min = 48.dp),
                    ) {
                        Text("继续投递文件")
                    }
                }
            } else if (transfer.stage.isTerminal) {
                TransferTerminalSummary(transfer)
            } else {
                if (transfer.batchTotalCount > 1) {
                    BatchProgressSummary(transfer)
                }

                if (transfer.batchTotalCount == 1 && (transfer.stage.isActive || transfer.progressPercent != null)) {
                    TransferProgressIndicator(transfer)
                }

                if (
                    transfer.batchTotalCount == 1 &&
                    (transfer.transferId != null || transfer.sentBytes != null || transfer.stage == SharedFileDeliveryStage.Sending)
                ) {
                    TransferSessionInfo(transfer)
                }
            }

            if (transfer.stage.isRetryableTerminal && transfer.canRetry) {
                FilledTonalButton(
                    onClick = onRetry,
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 48.dp),
                ) {
                    Text("重试投递")
                }
            }

            if (transfer.canCancel) {
                OutlinedButton(
                    onClick = onCancel,
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 48.dp),
                ) {
                    Text("取消投递")
                }
            }

            if (transfer.stage.isActive) {
                DeliveryStepRow(transfer = transfer)
            }
        }
    }
}
