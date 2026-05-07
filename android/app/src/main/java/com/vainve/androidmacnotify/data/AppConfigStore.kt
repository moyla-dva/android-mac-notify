package com.vainve.androidmacnotify.data

import android.content.Context
import android.provider.Settings
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import java.security.MessageDigest
import java.util.UUID

private const val DATASTORE_NAME = "android_mac_notify_config"
private const val MAX_SHARED_FILE_DELIVERY_RECORDS = 10
private const val MAX_SUCCESS_SHARED_FILE_DELIVERY_RECORDS = 4
private const val MAX_RELAY_ACTIVITY_RECORDS = 20

private val Context.dataStore by preferencesDataStore(name = DATASTORE_NAME)

class AppConfigStore(private val context: Context) {
    private val defaultDeviceId: String by lazy { buildStableDeviceId(context) }
    private val defaultDeviceDisplayName: String by lazy {
        android.os.Build.MODEL.orEmpty().ifBlank { "Android Device" }
    }

    private object Keys {
        val deviceId = stringPreferencesKey("device_id")
        val deviceDisplayName = stringPreferencesKey("device_display_name")
        val host = stringPreferencesKey("host")
        val port = intPreferencesKey("port")
        val pairingToken = stringPreferencesKey("pairing_token")
        val deviceToken = stringPreferencesKey("device_token")
        val macDeviceId = stringPreferencesKey("mac_device_id")
        val macDisplayName = stringPreferencesKey("mac_display_name")
        val relayEnabled = booleanPreferencesKey("relay_enabled")
        val notificationServiceLastActiveAt = longPreferencesKey("notification_service_last_active_at")
        val macReachabilityStatus = stringPreferencesKey("mac_reachability_status")
        val macReachabilityCheckedAt = longPreferencesKey("mac_reachability_checked_at")
        val macReachabilityMessage = stringPreferencesKey("mac_reachability_message")
        val pendingNotificationEvents = stringPreferencesKey("pending_notification_events")
        val relayActivityRecords = stringPreferencesKey("relay_activity_records")
        val sharedFileDeliveryRecords = stringPreferencesKey("shared_file_delivery_records")
    }

    val configFlow: Flow<AppConfig> = context.dataStore.data.map { preferences ->
        AppConfig(
            deviceId = preferences[Keys.deviceId] ?: defaultDeviceId,
            deviceDisplayName = preferences[Keys.deviceDisplayName] ?: defaultDeviceDisplayName,
            host = preferences[Keys.host] ?: "",
            port = preferences[Keys.port] ?: 38471,
            pairingToken = preferences[Keys.pairingToken] ?: "",
            deviceToken = preferences[Keys.deviceToken],
            macDeviceId = preferences[Keys.macDeviceId],
            macDisplayName = preferences[Keys.macDisplayName],
            relayEnabled = preferences[Keys.relayEnabled] ?: true,
            notificationServiceLastActiveAt = preferences[Keys.notificationServiceLastActiveAt] ?: 0L,
            macReachabilityStatus = AppConfigCodecs.decodeMacReachabilityStatus(preferences[Keys.macReachabilityStatus]),
            macReachabilityCheckedAt = preferences[Keys.macReachabilityCheckedAt] ?: 0L,
            macReachabilityMessage = preferences[Keys.macReachabilityMessage],
        )
    }

    val sharedFileDeliveryRecordsFlow: Flow<List<SharedFileDeliveryRecord>> = context.dataStore.data.map { preferences ->
        AppConfigCodecs.trimSharedFileDeliveryRecords(
            records = AppConfigCodecs.decodeSharedFileDeliveryRecords(preferences[Keys.sharedFileDeliveryRecords].orEmpty()),
            maxSize = MAX_SHARED_FILE_DELIVERY_RECORDS,
            maxSuccessSize = MAX_SUCCESS_SHARED_FILE_DELIVERY_RECORDS,
        )
    }

    val relayActivityRecordsFlow: Flow<List<RelayActivityRecord>> = context.dataStore.data.map { preferences ->
        AppConfigCodecs.decodeRelayActivityRecords(preferences[Keys.relayActivityRecords].orEmpty())
            .sortedByDescending { it.relayedAt }
            .take(MAX_RELAY_ACTIVITY_RECORDS)
    }

    suspend fun initializeIfNeeded() {
        context.dataStore.edit { preferences ->
            if (preferences[Keys.deviceId] == null) {
                preferences[Keys.deviceId] = defaultDeviceId
            }
            if (preferences[Keys.deviceDisplayName] == null) {
                preferences[Keys.deviceDisplayName] = defaultDeviceDisplayName
            }
            if (preferences[Keys.port] == null) {
                preferences[Keys.port] = 38471
            }
        }
    }

    suspend fun updateConnectionFields(
        host: String,
        port: Int,
        pairingToken: String,
        deviceDisplayName: String,
    ) {
        context.dataStore.edit { preferences ->
            preferences[Keys.host] = host.trim()
            preferences[Keys.port] = port
            preferences[Keys.pairingToken] = pairingToken.trim()
            preferences[Keys.deviceDisplayName] = deviceDisplayName.trim()
        }
    }

    suspend fun saveRegistration(
        deviceToken: String,
        macDeviceId: String,
        macDisplayName: String,
    ) {
        context.dataStore.edit { preferences ->
            preferences[Keys.deviceToken] = deviceToken
            preferences[Keys.macDeviceId] = macDeviceId
            preferences[Keys.macDisplayName] = macDisplayName
            preferences[Keys.relayEnabled] = true
            preferences[Keys.macReachabilityStatus] = MacReachabilityStatus.Reachable.name
            preferences[Keys.macReachabilityCheckedAt] = System.currentTimeMillis()
            preferences.remove(Keys.macReachabilityMessage)
        }
    }

    suspend fun setRelayEnabled(enabled: Boolean) {
        context.dataStore.edit { preferences ->
            preferences[Keys.relayEnabled] = enabled
            preferences[Keys.macReachabilityStatus] = if (enabled) {
                MacReachabilityStatus.Unknown.name
            } else {
                MacReachabilityStatus.Paused.name
            }
            preferences[Keys.macReachabilityCheckedAt] = System.currentTimeMillis()
            if (enabled) {
                preferences.remove(Keys.macReachabilityMessage)
            } else {
                preferences[Keys.macReachabilityMessage] = "接力已暂停"
            }
        }
    }

    suspend fun updateMacReachability(
        status: MacReachabilityStatus,
        message: String? = null,
        checkedAt: Long = System.currentTimeMillis(),
    ) {
        context.dataStore.edit { preferences ->
            preferences[Keys.macReachabilityStatus] = status.name
            preferences[Keys.macReachabilityCheckedAt] = checkedAt
            if (message.isNullOrBlank()) {
                preferences.remove(Keys.macReachabilityMessage)
            } else {
                preferences[Keys.macReachabilityMessage] = message
            }
        }
    }

    suspend fun recordNotificationServiceActive(activeAt: Long = System.currentTimeMillis()) {
        context.dataStore.edit { preferences ->
            preferences[Keys.notificationServiceLastActiveAt] = activeAt
        }
    }

    suspend fun forgetMacRegistration() {
        context.dataStore.edit { preferences ->
            preferences.remove(Keys.host)
            preferences[Keys.port] = 38471
            preferences.remove(Keys.deviceToken)
            preferences.remove(Keys.macDeviceId)
            preferences.remove(Keys.macDisplayName)
            preferences[Keys.relayEnabled] = true
            preferences.remove(Keys.macReachabilityStatus)
            preferences.remove(Keys.macReachabilityCheckedAt)
            preferences.remove(Keys.macReachabilityMessage)
        }
    }

    suspend fun pendingNotificationEvents(): List<PendingNotificationEvent> {
        val preferences = context.dataStore.data.first()
        return AppConfigCodecs.decodePendingNotificationEvents(preferences[Keys.pendingNotificationEvents].orEmpty())
    }

    suspend fun enqueuePendingNotification(
        event: PendingNotificationEvent,
        maxSize: Int = 50,
    ) {
        context.dataStore.edit { preferences ->
            val current = AppConfigCodecs.decodePendingNotificationEvents(preferences[Keys.pendingNotificationEvents].orEmpty())
            val next = (current.filterNot { it.eventId == event.eventId } + event).takeLast(maxSize)
            preferences[Keys.pendingNotificationEvents] = AppConfigCodecs.encodePendingNotificationEvents(next)
        }
    }

    suspend fun removePendingNotification(eventId: String) {
        context.dataStore.edit { preferences ->
            val current = AppConfigCodecs.decodePendingNotificationEvents(preferences[Keys.pendingNotificationEvents].orEmpty())
            val next = current.filterNot { it.eventId == eventId }
            if (next.isEmpty()) {
                preferences.remove(Keys.pendingNotificationEvents)
            } else {
                preferences[Keys.pendingNotificationEvents] = AppConfigCodecs.encodePendingNotificationEvents(next)
            }
        }
    }

    suspend fun recordRelayActivity(
        record: RelayActivityRecord,
        maxSize: Int = MAX_RELAY_ACTIVITY_RECORDS,
    ) {
        context.dataStore.edit { preferences ->
            val current = AppConfigCodecs.decodeRelayActivityRecords(preferences[Keys.relayActivityRecords].orEmpty())
            val next = (listOf(record) + current.filterNot { it.eventId == record.eventId })
                .sortedByDescending { it.relayedAt }
                .take(maxSize.coerceAtLeast(1))
            preferences[Keys.relayActivityRecords] = AppConfigCodecs.encodeRelayActivityRecords(next)
        }
    }

    suspend fun recordSharedFileDelivery(
        record: SharedFileDeliveryRecord,
        maxSize: Int = MAX_SHARED_FILE_DELIVERY_RECORDS,
        maxSuccessSize: Int = MAX_SUCCESS_SHARED_FILE_DELIVERY_RECORDS,
    ) {
        context.dataStore.edit { preferences ->
            val current = AppConfigCodecs.decodeSharedFileDeliveryRecords(preferences[Keys.sharedFileDeliveryRecords].orEmpty())
            val next = AppConfigCodecs.nextSharedFileDeliveryRecords(
                current = current,
                record = record,
                maxSize = maxSize,
                maxSuccessSize = maxSuccessSize,
            )
            preferences[Keys.sharedFileDeliveryRecords] = AppConfigCodecs.encodeSharedFileDeliveryRecords(next)
        }
    }

    suspend fun clearSharedFileDeliveryRecords() {
        context.dataStore.edit { preferences ->
            preferences.remove(Keys.sharedFileDeliveryRecords)
        }
    }

}

private fun buildStableDeviceId(context: Context): String {
    val androidId = Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
        ?.takeIf { it.isNotBlank() && it != "9774d56d682e549c" }
    val seed = androidId ?: UUID.randomUUID().toString()
    val digest = MessageDigest.getInstance("SHA-256")
        .digest("${context.packageName}|$seed".toByteArray(Charsets.UTF_8))
        .joinToString(separator = "") { byte ->
            (byte.toInt() and 0xff).toString(16).padStart(2, '0')
        }
    return "android-${digest.take(12)}"
}
