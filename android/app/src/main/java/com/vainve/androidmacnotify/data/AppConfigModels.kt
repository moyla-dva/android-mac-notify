package com.vainve.androidmacnotify.data

data class AppConfig(
    val deviceId: String,
    val deviceDisplayName: String,
    val host: String,
    val port: Int,
    val pairingToken: String,
    val deviceToken: String?,
    val macDeviceId: String?,
    val macDisplayName: String?,
    val relayEnabled: Boolean,
    val notificationServiceLastActiveAt: Long,
    val macReachabilityStatus: MacReachabilityStatus,
    val macReachabilityCheckedAt: Long,
    val macReachabilityMessage: String?,
)

enum class MacReachabilityStatus {
    Unknown,
    Reachable,
    Unreachable,
    AuthFailed,
    Paused,
    MacPaused,
}

data class PendingNotificationEvent(
    val eventId: String,
    val deviceId: String,
    val appPackage: String,
    val appName: String,
    val title: String,
    val text: String,
    val postedAt: Long,
    val notificationKey: String,
)

data class RelayActivityRecord(
    val eventId: String,
    val appPackage: String,
    val appName: String,
    val title: String,
    val text: String,
    val postedAt: Long,
    val relayedAt: Long,
)

enum class SharedFileDeliveryRecordStatus {
    Success,
    Failed,
    Cancelled,
}

data class SharedFileDeliveryRecord(
    val recordId: String,
    val fileName: String,
    val fileCount: Int,
    val completedCount: Int,
    val totalBytes: Long?,
    val sourceUris: List<String> = emptyList(),
    val targetName: String?,
    val status: SharedFileDeliveryRecordStatus,
    val message: String,
    val canRetry: Boolean = true,
    val finishedAt: Long,
)
