package com.vainve.androidmacnotify.ui.transfer

import android.net.Uri
import com.vainve.androidmacnotify.data.MacReachabilityStatus
import com.vainve.androidmacnotify.data.SharedFileDeliveryRecord
import com.vainve.androidmacnotify.network.RelayApiException
import com.vainve.androidmacnotify.network.SharedFileRelayPayload
import com.vainve.androidmacnotify.network.SharedFileRelayResponse
import com.vainve.androidmacnotify.ui.PairingUiState
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody

internal class SharedFileDeliveryStateHarness(
    initialState: PairingUiState = PairingUiState(
        host = "192.168.1.2",
        port = "38471",
        deviceToken = "device-token",
        deviceId = "android-device",
        sharedFileTransfer = testTransferUi(),
    ),
) {
    var state = initialState
    val records = mutableListOf<SharedFileDeliveryRecord>()
    val reachabilityUpdates = mutableListOf<Pair<MacReachabilityStatus, String?>>()

    val uiUpdater = SharedFileDeliveryUiUpdater(
        updateState = { reducer -> state = reducer(state) },
        targetName = { "MacBook" },
        formatFileSize = { "$it B" },
    )
    val recorder = SharedFileDeliveryRecorder(
        targetName = { "MacBook" },
        onRecordDelivery = records::add,
    )

    fun updateReachability(status: MacReachabilityStatus, message: String?) {
        reachabilityUpdates += status to message
    }
}

internal class FakeSharedFileDeliveryTransferClient(
    private val generatedTransferIds: MutableList<String> = mutableListOf("share_generated"),
) : SharedFileDeliveryTransferClient {
    var buildFailure: Throwable? = null
    val sendResults = ArrayDeque<Result<SharedFileRelayResponse>>()
    val sentPayloads = mutableListOf<SharedFileRelayPayload>()
    val buildCalls = mutableListOf<FakeBuildCall>()
    val sendCalls = mutableListOf<FakeSendCall>()

    override fun createTransferId(): String {
        return if (generatedTransferIds.isNotEmpty()) {
            generatedTransferIds.removeAt(0)
        } else {
            "share_generated_${buildCalls.size + sentPayloads.size}"
        }
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
        buildCalls += FakeBuildCall(
            uri = uri,
            deviceId = deviceId,
            shareId = shareId,
            batchId = batchId,
            batchIndex = batchIndex,
            batchTotal = batchTotal,
        )
        buildFailure?.let { throw it }
        onProgress(25, 100)
        return testPayload(
            deviceId = deviceId,
            shareId = shareId,
            batchId = batchId,
            batchIndex = batchIndex,
            batchTotal = batchTotal,
            fileName = uri.lastPathSegment ?: "shared-file",
            size = 100,
        )
    }

    override fun sendPayload(
        host: String,
        port: Int,
        deviceToken: String,
        payload: SharedFileRelayPayload,
    ): Result<SharedFileRelayResponse> {
        sendCalls += FakeSendCall(host, port, deviceToken)
        sentPayloads += payload
        return sendResults.removeFirstOrNull()
            ?: Result.success(testResponse(payload.fileName, payload.shareId, payload.size))
    }
}

internal data class FakeBuildCall(
    val uri: Uri,
    val deviceId: String,
    val shareId: String,
    val batchId: String?,
    val batchIndex: Int?,
    val batchTotal: Int?,
)

internal data class FakeSendCall(
    val host: String,
    val port: Int,
    val deviceToken: String,
)

internal fun testSelection(
    fileName: String,
    sizeBytes: Long? = 100,
): SharedFileSelection {
    return SharedFileSelection(
        uri = Uri.parse("content://test/$fileName"),
        fileName = fileName,
        sizeLabel = sizeBytes?.let { "$it B" },
        sizeBytes = sizeBytes,
    )
}

internal fun testTransferUi(
    fileName: String = "file.txt",
): SharedFileTransferUi {
    return SharedFileTransferUi(
        fileName = fileName,
        sizeLabel = "100 B",
        targetName = "MacBook",
        stage = SharedFileDeliveryStage.ReadingConfig,
        message = "准备投递",
    )
}

internal fun testPayload(
    deviceId: String = "android-device",
    shareId: String = "share-id",
    batchId: String? = null,
    batchIndex: Int? = null,
    batchTotal: Int? = null,
    fileName: String = "file.txt",
    size: Long = 100,
): SharedFileRelayPayload {
    return SharedFileRelayPayload(
        deviceId = deviceId,
        shareId = shareId,
        batchId = batchId,
        batchIndex = batchIndex,
        batchTotal = batchTotal,
        fileName = fileName,
        mimeType = "text/plain",
        size = size,
        sharedAt = 123L,
        fileBody = ByteArray(size.coerceAtMost(8).toInt()) { 1 }
            .toRequestBody("text/plain".toMediaType()),
    )
}

internal fun testResponse(
    fileName: String = "file.txt",
    shareId: String = "share-id",
    size: Long = 100,
): SharedFileRelayResponse {
    return SharedFileRelayResponse(
        accepted = true,
        shareId = shareId,
        fileName = fileName,
        savedPath = "/tmp/$fileName",
        size = size,
    )
}

internal fun relayError(
    statusCode: Int,
    code: String,
    retryable: Boolean?,
    serverMessage: String? = null,
): RelayApiException {
    return RelayApiException(
        statusCode = statusCode,
        code = code,
        serverMessage = serverMessage,
        retryable = retryable,
        operation = "File delivery",
        responseBody = "",
    )
}
