package com.vainve.androidmacnotify.network

import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.util.concurrent.TimeUnit

data class MacDiscoveryResult(
    val serviceName: String = "",
    val protocolVersion: Int,
    val serviceType: String,
    val macDeviceId: String,
    val macDisplayName: String,
    val host: String,
    val port: Int,
)

class DiscoveryApi(
    private val client: OkHttpClient = OkHttpClient.Builder()
        .callTimeout(2, TimeUnit.SECONDS)
        .build(),
) {
    fun fetchDiscovery(
        host: String,
        port: Int,
    ): Result<MacDiscoveryResult> {
        return runCatching {
            val request = Request.Builder()
                .url("http://${hostForUrl(host)}:$port/api/v1/discovery")
                .get()
                .build()

            client.newCall(request).execute().use { response ->
                val responseBody = response.body?.string().orEmpty()
                if (!response.isSuccessful) {
                    error("Discovery failed (${response.code}): $responseBody")
                }

                val json = JSONObject(responseBody)
                MacDiscoveryResult(
                    protocolVersion = json.optInt("protocolVersion", 1),
                    serviceType = json.optString("serviceType"),
                    macDeviceId = json.getString("macDeviceId"),
                    macDisplayName = json.getString("macDisplayName"),
                    host = host,
                    port = json.optInt("port", port),
                )
            }
        }
    }
}
