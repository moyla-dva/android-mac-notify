package com.vainve.androidmacnotify.network

import okhttp3.MediaType.Companion.toMediaType
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.IOException
import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException

data class PairRegistrationResult(
    val deviceToken: String,
    val macDisplayName: String,
    val macDeviceId: String,
)

data class PairApprovalStartResult(
    val requestId: String,
    val status: String,
    val macDisplayName: String,
    val macDeviceId: String,
    val expiresAt: Long,
    val pollAfterMillis: Long,
)

data class PairApprovalStatusResult(
    val requestId: String,
    val status: String,
    val macDisplayName: String,
    val macDeviceId: String,
    val message: String?,
    val registration: PairRegistrationResult?,
)

class PairingApi(
    private val client: OkHttpClient = OkHttpClient(),
) {
    fun checkSessionStatus(
        host: String,
        port: Int,
        deviceToken: String,
        deviceId: String,
    ): Result<Unit> {
        return runCatching {
            val url = "http://${hostForUrl(host)}:$port/api/v1/session/status"
                .toHttpUrl()
                .newBuilder()
                .addQueryParameter("deviceId", deviceId)
                .build()

            val request = Request.Builder()
                .url(url)
                .header("Authorization", "Bearer $deviceToken")
                .get()
                .build()

            client.newCall(request).execute().use { response ->
                val responseBody = response.body?.string().orEmpty()
                if (!response.isSuccessful) {
                    throw macApiException("Session status failed", response.code, responseBody)
                }
            }
        }.fold(
            onSuccess = { Result.success(Unit) },
            onFailure = { throwable ->
                Result.failure(IOException(throwable.toUserMessage(), throwable))
            },
        )
    }

    fun requestPairingApproval(
        host: String,
        port: Int,
        deviceId: String,
        deviceDisplayName: String,
    ): Result<PairApprovalStartResult> {
        return runCatching {
            val json = JSONObject()
                .put(
                    "device",
                    JSONObject()
                        .put("deviceId", deviceId)
                        .put("platform", "android")
                        .put("displayName", deviceDisplayName),
                )

            val request = Request.Builder()
                .url("http://${hostForUrl(host)}:$port/api/v1/pair/request")
                .post(json.toString().toRequestBody("application/json; charset=utf-8".toMediaType()))
                .build()

            client.newCall(request).execute().use { response ->
                val responseBody = response.body?.string().orEmpty()
                if (!response.isSuccessful) {
                    throw macApiException("Pair approval request failed", response.code, responseBody)
                }

                val responseJson = JSONObject(responseBody)
                PairApprovalStartResult(
                    requestId = responseJson.getString("requestId"),
                    status = responseJson.optString("status", "pending"),
                    macDisplayName = responseJson.getString("macDisplayName"),
                    macDeviceId = responseJson.getString("macDeviceId"),
                    expiresAt = responseJson.optLong("expiresAt"),
                    pollAfterMillis = responseJson.optLong("pollAfterMillis", 2_000L),
                )
            }
        }.fold(
            onSuccess = { Result.success(it) },
            onFailure = { throwable ->
                Result.failure(IOException(throwable.toUserMessage(), throwable))
            },
        )
    }

    fun pollPairingApprovalStatus(
        host: String,
        port: Int,
        requestId: String,
        deviceId: String,
    ): Result<PairApprovalStatusResult> {
        return runCatching {
            val url = "http://${hostForUrl(host)}:$port/api/v1/pair/request/status"
                .toHttpUrl()
                .newBuilder()
                .addQueryParameter("requestId", requestId)
                .addQueryParameter("deviceId", deviceId)
                .build()

            val request = Request.Builder()
                .url(url)
                .get()
                .build()

            client.newCall(request).execute().use { response ->
                val responseBody = response.body?.string().orEmpty()
                if (!response.isSuccessful) {
                    throw macApiException("Pair approval status failed", response.code, responseBody)
                }

                val responseJson = JSONObject(responseBody)
                val registrationJson = responseJson.optJSONObject("registration")
                PairApprovalStatusResult(
                    requestId = responseJson.getString("requestId"),
                    status = responseJson.optString("status", "pending"),
                    macDisplayName = responseJson.getString("macDisplayName"),
                    macDeviceId = responseJson.getString("macDeviceId"),
                    message = responseJson.optString("message").ifBlank { null },
                    registration = registrationJson?.let {
                        PairRegistrationResult(
                            deviceToken = it.getString("deviceToken"),
                            macDisplayName = it.getString("macDisplayName"),
                            macDeviceId = it.getString("macDeviceId"),
                        )
                    },
                )
            }
        }.fold(
            onSuccess = { Result.success(it) },
            onFailure = { throwable ->
                Result.failure(IOException(throwable.toUserMessage(), throwable))
            },
        )
    }

    fun registerDevice(
        host: String,
        port: Int,
        pairingToken: String,
        deviceId: String,
        deviceDisplayName: String,
    ): Result<PairRegistrationResult> {
        return runCatching {
            val json = JSONObject()
                .put("pairingToken", pairingToken)
                .put(
                    "device",
                    JSONObject()
                        .put("deviceId", deviceId)
                        .put("platform", "android")
                        .put("displayName", deviceDisplayName),
                )

            val request = Request.Builder()
                .url("http://${hostForUrl(host)}:$port/api/v1/pair/register")
                .post(json.toString().toRequestBody("application/json; charset=utf-8".toMediaType()))
                .build()

            client.newCall(request).execute().use { response ->
                val responseBody = response.body?.string().orEmpty()
                if (!response.isSuccessful) {
                    throw macApiException("Pair register failed", response.code, responseBody)
                }

                val responseJson = JSONObject(responseBody)
                PairRegistrationResult(
                    deviceToken = responseJson.getString("deviceToken"),
                    macDisplayName = responseJson.getString("macDisplayName"),
                    macDeviceId = responseJson.getString("macDeviceId"),
                )
            }
        }.fold(
            onSuccess = { Result.success(it) },
            onFailure = { throwable ->
                Result.failure(IOException(throwable.toUserMessage(), throwable))
            },
        )
    }

    private fun Throwable.toUserMessage(): String {
        val causes = generateSequence(this) { it.cause }.toList()
        val allMessages = causes.mapNotNull { it.message }.filter { it.isNotBlank() }
        val macError = causes.firstNotNullOfOrNull { it as? MacApiException }

        return when {
            macError?.code == "INVALID_PAIRING_TOKEN" ->
                "这次配对已经失效，请重新选择 Mac 并在 Mac 上确认。"
            macError?.code == "PAIR_REQUEST_NOT_FOUND" ->
                "Mac 端配对确认没有完成，请重新发起请求。"
            macError?.code == "PAIR_REQUEST_DEVICE_MISMATCH" ->
                "这次配对请求不属于当前手机，请重新选择 Mac。"
            macError?.code == "INVALID_DEVICE_TOKEN" ||
                macError?.code == "DEVICE_TOKEN_DEVICE_MISMATCH" ||
                macError?.code == "DEVICE_NOT_REGISTERED" ->
                "旧配对已失效，请重新选择 Mac 并确认。"
            macError?.code == "INVALID_REQUEST" ->
                "发往 Mac 的注册请求格式不正确，请重试或更新到最新调试版本。"
            macError?.serverMessage?.isNotBlank() == true ->
                macError.serverMessage.orEmpty()
            causes.any { it is UnknownHostException } ->
                "找不到这台 Mac，请检查手动输入的地址是否正确。"
            causes.any { it is ConnectException } ->
                "无法连接到 Mac，请确认 Mac 端应用还在运行，并且手机和 Mac 在同一网络。"
            causes.any { it is SocketTimeoutException } ->
                "连接 Mac 超时，请确认 Mac 接收器仍在运行，然后重试。"
            allMessages.any { it.contains("ERR_SOCKET_NOT_CONNECTED", ignoreCase = true) } ->
                "与 Mac 的连接没有建立成功。请保持 USB 连接，并临时关闭手机上的代理/VPN 后重试。"
            allMessages.any { it.contains("INVALID_PAIRING_TOKEN", ignoreCase = true) } ->
                "这次配对已经失效，请重新选择 Mac 并在 Mac 上确认。"
            allMessages.any { it.contains("PAIR_REQUEST", ignoreCase = true) } ->
                "Mac 端配对确认没有完成，请重新发起请求。"
            allMessages.any { it.contains("INVALID_REQUEST", ignoreCase = true) } ->
                "发往 Mac 的注册请求格式不正确，请重试或更新到最新调试版本。"
            allMessages.isNotEmpty() ->
                allMessages.first()
            else ->
                this::class.simpleName ?: "注册失败"
        }
    }
}

private class MacApiException(
    val statusCode: Int,
    val code: String?,
    val serverMessage: String?,
    val retryable: Boolean?,
    operation: String,
    responseBody: String,
) : IOException("$operation ($statusCode): ${code ?: responseBody}")

private fun macApiException(operation: String, statusCode: Int, responseBody: String): MacApiException {
    val errorJson = runCatching {
        JSONObject(responseBody).optJSONObject("error")
    }.getOrNull()
    return MacApiException(
        statusCode = statusCode,
        code = errorJson?.optString("code")?.takeIf { it.isNotBlank() },
        serverMessage = errorJson?.optString("message")?.takeIf { it.isNotBlank() },
        retryable = errorJson?.takeIf { it.has("retryable") }?.optBoolean("retryable"),
        operation = operation,
        responseBody = responseBody,
    )
}
