package com.vainve.androidmacnotify.network

import android.util.Base64
import okhttp3.Call
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.IOException
import java.util.concurrent.TimeUnit

data class NotificationRelayPayload(
    val eventId: String,
    val deviceId: String,
    val appPackage: String,
    val appName: String,
    val title: String,
    val text: String,
    val postedAt: Long,
    val notificationKey: String,
)

data class SharedFileRelayPayload(
    val deviceId: String,
    val shareId: String,
    val batchId: String? = null,
    val batchIndex: Int? = null,
    val batchTotal: Int? = null,
    val fileName: String,
    val mimeType: String?,
    val size: Long,
    val sharedAt: Long,
    val fileBody: RequestBody,
    val onCallCreated: (Call) -> Unit = {},
    val cleanup: () -> Unit = {},
)

data class SharedFileRelayResponse(
    val accepted: Boolean,
    val shareId: String,
    val fileName: String,
    val savedPath: String?,
    val size: Long,
)

data class HeartbeatRelayResponse(
    val ok: Boolean,
    val serverTime: Long,
    val sessionState: String,
) {
    val acceptsSession: Boolean
        get() = ok && sessionState != "unpaired"
}

data class RelayStateUpdateResponse(
    val ok: Boolean,
    val serverTime: Long,
    val sessionState: String,
)

data class SessionForgetResponse(
    val ok: Boolean,
    val serverTime: Long,
    val sessionState: String,
)

class RelayApiException(
    val statusCode: Int,
    val code: String?,
    val serverMessage: String?,
    val retryable: Boolean?,
    operation: String,
    responseBody: String,
) : IOException(
    buildString {
        append("$operation failed ($statusCode)")
        if (!code.isNullOrBlank()) append(" [$code]")
        if (!serverMessage.isNullOrBlank()) append(": $serverMessage")
        if (serverMessage.isNullOrBlank() && responseBody.isNotBlank()) append(": $responseBody")
    }
)

class RelayApi(
    private val client: OkHttpClient = OkHttpClient(),
) {
    private val fileTransferClient = client.newBuilder()
        .callTimeout(0, TimeUnit.MILLISECONDS)
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .writeTimeout(0, TimeUnit.MILLISECONDS)
        .build()

    fun sendHeartbeat(
        host: String,
        port: Int,
        deviceToken: String,
        deviceId: String,
        networkType: String,
    ): Result<HeartbeatRelayResponse> {
        return runCatching {
            val json = JSONObject()
                .put("deviceId", deviceId)
                .put("sentAt", System.currentTimeMillis())
                .put("networkType", networkType)

            val request = Request.Builder()
                .url("http://${hostForUrl(host)}:$port/api/v1/session/heartbeat")
                .header("Authorization", "Bearer $deviceToken")
                .post(json.toString().toRequestBody("application/json; charset=utf-8".toMediaType()))
                .build()

            client.newCall(request).execute().use { response ->
                val responseBody = response.body?.string().orEmpty()
                if (!response.isSuccessful) {
                    throw relayApiException(
                        operation = "Heartbeat",
                        statusCode = response.code,
                        responseBody = responseBody,
                    )
                }
                val responseJson = JSONObject(responseBody)
                HeartbeatRelayResponse(
                    ok = responseJson.optBoolean("ok", false),
                    serverTime = responseJson.optLong("serverTime"),
                    sessionState = responseJson.optString("sessionState", "unknown"),
                )
            }
        }
    }

    fun updateRelayState(
        host: String,
        port: Int,
        deviceToken: String,
        deviceId: String,
        relayState: String,
    ): Result<RelayStateUpdateResponse> {
        return runCatching {
            val json = JSONObject()
                .put("deviceId", deviceId)
                .put("relayState", relayState)
                .put("sentAt", System.currentTimeMillis())

            val request = Request.Builder()
                .url("http://${hostForUrl(host)}:$port/api/v1/session/relay-state")
                .header("Authorization", "Bearer $deviceToken")
                .post(json.toString().toRequestBody("application/json; charset=utf-8".toMediaType()))
                .build()

            client.newCall(request).execute().use { response ->
                val responseBody = response.body?.string().orEmpty()
                if (!response.isSuccessful) {
                    throw relayApiException(
                        operation = "Relay state update",
                        statusCode = response.code,
                        responseBody = responseBody,
                    )
                }
                val responseJson = JSONObject(responseBody)
                RelayStateUpdateResponse(
                    ok = responseJson.optBoolean("ok", false),
                    serverTime = responseJson.optLong("serverTime"),
                    sessionState = responseJson.optString("sessionState", "unknown"),
                )
            }
        }
    }

    fun forgetSession(
        host: String,
        port: Int,
        deviceToken: String,
        deviceId: String,
    ): Result<SessionForgetResponse> {
        return runCatching {
            val json = JSONObject()
                .put("deviceId", deviceId)
                .put("sentAt", System.currentTimeMillis())

            val request = Request.Builder()
                .url("http://${hostForUrl(host)}:$port/api/v1/session/forget")
                .header("Authorization", "Bearer $deviceToken")
                .post(json.toString().toRequestBody("application/json; charset=utf-8".toMediaType()))
                .build()

            client.newCall(request).execute().use { response ->
                val responseBody = response.body?.string().orEmpty()
                if (!response.isSuccessful) {
                    throw relayApiException(
                        operation = "Session forget",
                        statusCode = response.code,
                        responseBody = responseBody,
                    )
                }
                val responseJson = JSONObject(responseBody)
                SessionForgetResponse(
                    ok = responseJson.optBoolean("ok", false),
                    serverTime = responseJson.optLong("serverTime"),
                    sessionState = responseJson.optString("sessionState", "unknown"),
                )
            }
        }
    }

    fun sendNotificationEvent(
        host: String,
        port: Int,
        deviceToken: String,
        payload: NotificationRelayPayload,
    ): Result<Unit> {
        return runCatching {
            val json = JSONObject()
                .put("eventId", payload.eventId)
                .put("deviceId", payload.deviceId)
                .put("appPackage", payload.appPackage)
                .put("appName", payload.appName)
                .put("title", payload.title)
                .put("text", payload.text)
                .put("postedAt", payload.postedAt)
                .put("notificationKey", payload.notificationKey)

            val request = Request.Builder()
                .url("http://${hostForUrl(host)}:$port/api/v1/events/notification")
                .header("Authorization", "Bearer $deviceToken")
                .post(json.toString().toRequestBody("application/json; charset=utf-8".toMediaType()))
                .build()

            client.newCall(request).execute().use { response ->
                val responseBody = response.body?.string().orEmpty()
                if (!response.isSuccessful) {
                    throw relayApiException(
                        operation = "Notification relay",
                        statusCode = response.code,
                        responseBody = responseBody,
                    )
                }
            }
        }
    }

    fun sendSharedFile(
        host: String,
        port: Int,
        deviceToken: String,
        payload: SharedFileRelayPayload,
    ): Result<SharedFileRelayResponse> {
        return runCatching {
            val requestBuilder = Request.Builder()
                .url("http://${hostForUrl(host)}:$port/api/v1/share/file")
                .header("Authorization", "Bearer $deviceToken")
                .header("X-AMN-Upload-Mode", "stream")
                .header("X-AMN-Device-Id", payload.deviceId)
                .header("X-AMN-Share-Id", payload.shareId)
                .header("X-AMN-File-Name-B64", payload.fileName.utf8Base64Header())
                .header("X-AMN-Mime-Type", payload.mimeType.orEmpty())
                .header("X-AMN-Shared-At", payload.sharedAt.toString())

            payload.batchId?.takeIf { it.isNotBlank() }?.let { batchId ->
                requestBuilder.header("X-AMN-Batch-Id", batchId)
            }
            payload.batchIndex?.let { batchIndex ->
                requestBuilder.header("X-AMN-Batch-Index", batchIndex.toString())
            }
            payload.batchTotal?.let { batchTotal ->
                requestBuilder.header("X-AMN-Batch-Total", batchTotal.toString())
            }

            val request = requestBuilder
                .post(payload.fileBody)
                .build()

            val call = fileTransferClient.newCall(request)
            payload.onCallCreated(call)
            call.execute().use { response ->
                val responseBody = response.body?.string().orEmpty()
                if (!response.isSuccessful) {
                    throw relayApiException(
                        operation = "File delivery",
                        statusCode = response.code,
                        responseBody = responseBody,
                    )
                }

                val responseJson = JSONObject(responseBody)
                SharedFileRelayResponse(
                    accepted = responseJson.optBoolean("accepted", true),
                    shareId = responseJson.optString("shareId").takeIf { it.isNotBlank() } ?: payload.shareId,
                    fileName = responseJson.optString("fileName").takeIf { it.isNotBlank() } ?: payload.fileName,
                    savedPath = responseJson.optString("savedPath").takeIf { it.isNotBlank() },
                    size = responseJson.optLong("size").takeIf { it > 0L } ?: payload.size,
                )
            }
        }
    }
}

fun Throwable.isPermanentRelayAuthFailure(): Boolean {
    val error = this as? RelayApiException ?: return false
    return error.statusCode == 401 ||
        error.statusCode == 403 ||
        error.code == "INVALID_DEVICE_TOKEN" ||
        error.code == "DEVICE_TOKEN_DEVICE_MISMATCH" ||
        error.code == "DEVICE_NOT_REGISTERED"
}

fun Throwable.isMacReceiverPaused(): Boolean {
    val error = this as? RelayApiException ?: return false
    return error.code == "MAC_RECEIVER_PAUSED"
}

fun Throwable.isMacFileSaveFailure(): Boolean {
    val error = this as? RelayApiException ?: return false
    return error.code == "INSUFFICIENT_STORAGE" ||
        error.code == "FILE_SAVE_FAILED"
}

fun Throwable.isRetryableRelayFailure(defaultValue: Boolean = true): Boolean {
    val error = this as? RelayApiException ?: return defaultValue
    return error.retryable ?: defaultValue
}

fun Throwable.toRelayStatusMessage(defaultMessage: String = "无法连接到 Mac"): String {
    val error = this as? RelayApiException
    return error?.serverMessage
        ?.takeIf { it.isNotBlank() }
        ?: message?.takeIf { it.isNotBlank() }
        ?: defaultMessage
}

private fun relayApiException(
    operation: String,
    statusCode: Int,
    responseBody: String,
): RelayApiException {
    val errorObject = runCatching {
        JSONObject(responseBody).optJSONObject("error")
    }.getOrNull()

    return RelayApiException(
        statusCode = statusCode,
        code = errorObject?.optString("code")?.takeIf { it.isNotBlank() },
        serverMessage = errorObject?.optString("message")?.takeIf { it.isNotBlank() },
        retryable = errorObject?.takeIf { it.has("retryable") }?.optBoolean("retryable"),
        operation = operation,
        responseBody = responseBody,
    )
}

private fun String.utf8Base64Header(): String {
    return Base64.encodeToString(toByteArray(Charsets.UTF_8), Base64.NO_WRAP)
}
