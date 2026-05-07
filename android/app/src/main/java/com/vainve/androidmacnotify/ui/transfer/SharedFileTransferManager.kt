package com.vainve.androidmacnotify.ui.transfer

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.text.format.Formatter
import com.vainve.androidmacnotify.network.RelayApi
import com.vainve.androidmacnotify.network.SharedFileRelayPayload
import com.vainve.androidmacnotify.network.SharedFileRelayResponse
import java.util.UUID

class SharedFileTransferManager(
    private val context: Context,
    private val relayApi: RelayApi = RelayApi(),
    private val selectionReader: SharedFileSelectionReader = SharedFileSelectionReader(context),
    private val payloadBuilder: SharedFileUploadPayloadBuilder = SharedFileUploadPayloadBuilder(context),
) {
    fun createTransferId(): String {
        return "share_${UUID.randomUUID().toString().replace("-", "")}"
    }

    fun selectionsFrom(intent: Intent): List<SharedFileSelection> {
        return selectionReader.selectionsFrom(intent)
    }

    fun selectionsFrom(uris: List<Uri>): List<SharedFileSelection> {
        return selectionReader.selectionsFrom(uris)
    }

    fun buildPayload(
        uri: Uri,
        deviceId: String,
        shareId: String,
        batchId: String? = null,
        batchIndex: Int? = null,
        batchTotal: Int? = null,
        cancelToken: SharedFileTransferCancelToken,
        onProgress: (sentBytes: Long, totalBytes: Long) -> Unit = { _, _ -> },
    ): SharedFileRelayPayload {
        return payloadBuilder.buildPayload(
            uri = uri,
            deviceId = deviceId,
            shareId = shareId,
            batchId = batchId,
            batchIndex = batchIndex,
            batchTotal = batchTotal,
            cancelToken = cancelToken,
            onProgress = onProgress,
        )
    }

    fun sendPayload(
        host: String,
        port: Int,
        deviceToken: String,
        payload: SharedFileRelayPayload,
    ): Result<SharedFileRelayResponse> {
        return try {
            relayApi.sendSharedFile(
                host = host,
                port = port,
                deviceToken = deviceToken,
                payload = payload,
            )
        } finally {
            payload.cleanup()
        }
    }

    fun formatFileSize(size: Long): String {
        return Formatter.formatFileSize(context, size)
    }
}
