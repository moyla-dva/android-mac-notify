package com.vainve.androidmacnotify.ui.transfer

import android.net.Uri
import com.vainve.androidmacnotify.network.SharedFileRelayPayload
import com.vainve.androidmacnotify.network.SharedFileRelayResponse

internal interface SharedFileDeliveryTransferClient {
    fun createTransferId(): String

    fun buildPayload(
        uri: Uri,
        deviceId: String,
        shareId: String,
        batchId: String? = null,
        batchIndex: Int? = null,
        batchTotal: Int? = null,
        cancelToken: SharedFileTransferCancelToken,
        onProgress: (sentBytes: Long, totalBytes: Long) -> Unit = { _, _ -> },
    ): SharedFileRelayPayload

    fun sendPayload(
        host: String,
        port: Int,
        deviceToken: String,
        payload: SharedFileRelayPayload,
    ): Result<SharedFileRelayResponse>
}

internal class SharedFileTransferManagerClient(
    private val transferManager: SharedFileTransferManager,
) : SharedFileDeliveryTransferClient {
    override fun createTransferId(): String {
        return transferManager.createTransferId()
    }

    override fun buildPayload(
        uri: Uri,
        deviceId: String,
        shareId: String,
        batchId: String?,
        batchIndex: Int?,
        batchTotal: Int?,
        cancelToken: SharedFileTransferCancelToken,
        onProgress: (sentBytes: Long, totalBytes: Long) -> Unit,
    ): SharedFileRelayPayload {
        return transferManager.buildPayload(
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

    override fun sendPayload(
        host: String,
        port: Int,
        deviceToken: String,
        payload: SharedFileRelayPayload,
    ): Result<SharedFileRelayResponse> {
        return transferManager.sendPayload(
            host = host,
            port = port,
            deviceToken = deviceToken,
            payload = payload,
        )
    }
}
