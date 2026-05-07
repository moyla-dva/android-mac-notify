package com.vainve.androidmacnotify.notify

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import com.vainve.androidmacnotify.data.AppConfig
import com.vainve.androidmacnotify.data.AppConfigStore
import com.vainve.androidmacnotify.data.MacReachabilityStatus
import com.vainve.androidmacnotify.data.PendingNotificationEvent
import com.vainve.androidmacnotify.data.RelayActivityRecord
import com.vainve.androidmacnotify.network.NotificationRelayPayload
import com.vainve.androidmacnotify.network.RelayApi
import com.vainve.androidmacnotify.network.isMacReceiverPaused
import com.vainve.androidmacnotify.network.isPermanentRelayAuthFailure
import com.vainve.androidmacnotify.network.isRetryableRelayFailure
import com.vainve.androidmacnotify.network.toRelayStatusMessage
import kotlinx.coroutines.Job
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

class NotificationRelayService : NotificationListenerService() {
    private companion object {
        const val RETRY_INITIAL_DELAY_MILLIS = 5_000L
        const val RETRY_INTERVAL_MILLIS = 15_000L
        const val RETRY_MAX_ATTEMPTS = 24
        const val PENDING_FLUSH_MIN_INTERVAL_MILLIS = 30_000L
        const val SERVICE_ACTIVE_RECORD_MIN_INTERVAL_MILLIS = 30_000L
    }

    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private lateinit var appConfigStore: AppConfigStore
    private lateinit var heartbeatCoordinator: RelayHeartbeatCoordinator
    private lateinit var payloadBuilder: NotificationRelayPayloadBuilder
    private val relayApi = RelayApi()
    private var retryJob: Job? = null
    @Volatile
    private var cachedConfig: AppConfig? = null
    @Volatile
    private var lastPendingFlushAt: Long = 0L
    @Volatile
    private var lastServiceActiveRecordedAt: Long = 0L

    override fun onCreate() {
        super.onCreate()
        appConfigStore = AppConfigStore(applicationContext)
        payloadBuilder = NotificationRelayPayloadBuilder(applicationContext)
        heartbeatCoordinator = RelayHeartbeatCoordinator(
            context = applicationContext,
            relayApi = relayApi,
            appConfigStore = appConfigStore,
            scope = serviceScope,
            currentConfig = ::currentConfig,
            flushPendingNotificationsIfDue = ::flushPendingNotificationsIfDue,
        )
        RelayForegroundStatus.start(this)
        serviceScope.launch {
            appConfigStore.initializeIfNeeded()
            recordNotificationServiceActive(force = true)
            appConfigStore.configFlow.collect { config ->
                cachedConfig = config
                RelayForegroundStatus.update(this@NotificationRelayService, config)
            }
        }
        heartbeatCoordinator.start()
    }

    override fun onDestroy() {
        serviceScope.cancel()
        super.onDestroy()
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        serviceScope.launch {
            recordNotificationServiceActive(force = true)
            val outcome = heartbeatCoordinator.sendAndUpdateStatus(currentConfig(), forceFlushPending = true)
            if (outcome == HeartbeatOutcome.TemporaryFailure) {
                schedulePendingRetry()
            }
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        val source = sbn ?: return
        if (source.packageName == packageName) return
        recordNotificationServiceActive(force = false)

        val title = payloadBuilder.title(source.notification)
        val text = payloadBuilder.text(source.notification)
        val decisionText = payloadBuilder.decisionText(source.notification, title, text)
        val relayDecision = AndroidNotificationRelayGate.decide(
            AndroidNotificationRelayInput(
                packageName = source.packageName,
                title = title,
                text = decisionText,
                category = source.notification.category,
                isOngoing = source.isOngoing,
            )
        )
        if (!relayDecision.shouldRelay) return

        serviceScope.launch {
            val config = currentConfig()
            if (!config.relayEnabled) return@launch
            if (config.macReachabilityStatus == MacReachabilityStatus.AuthFailed) return@launch
            val deviceToken = config.deviceToken ?: return@launch
            if (config.host.isBlank()) return@launch

            if (!flushPendingNotificationsIfDue(config, deviceToken, force = false)) {
                schedulePendingRetry()
            }

            val payload = payloadBuilder.build(source, config.deviceId, title, text)

            sendOrQueue(config, deviceToken, payload)
        }
    }

    private suspend fun currentConfig(): AppConfig {
        cachedConfig?.let { return it }
        appConfigStore.initializeIfNeeded()
        val config = appConfigStore.configFlow.first()
        cachedConfig = config
        RelayForegroundStatus.update(this, config)
        return config
    }

    private fun recordNotificationServiceActive(force: Boolean) {
        val now = System.currentTimeMillis()
        if (!force && now - lastServiceActiveRecordedAt < SERVICE_ACTIVE_RECORD_MIN_INTERVAL_MILLIS) {
            return
        }
        lastServiceActiveRecordedAt = now
        serviceScope.launch {
            appConfigStore.recordNotificationServiceActive(now)
        }
    }

    private suspend fun sendOrQueue(
        config: AppConfig,
        deviceToken: String,
        payload: NotificationRelayPayload,
    ) {
        relayApi.sendNotificationEvent(
            host = config.host,
            port = config.port,
            deviceToken = deviceToken,
            payload = payload,
        ).onSuccess {
            appConfigStore.updateMacReachability(MacReachabilityStatus.Reachable)
            appConfigStore.removePendingNotification(payload.eventId)
            appConfigStore.recordRelayActivity(payload.toRelayActivityRecord())
        }.onFailure { error ->
            if (error.isPermanentRelayAuthFailure()) {
                appConfigStore.updateMacReachability(
                    MacReachabilityStatus.AuthFailed,
                    "旧配对已失效，请重新连接 Mac",
                )
                return
            }

            if (error.isMacReceiverPaused()) {
                appConfigStore.updateMacReachability(
                    MacReachabilityStatus.MacPaused,
                    "Mac 已暂停接收，重新开始后会继续接力",
                )
            } else {
                appConfigStore.updateMacReachability(
                    MacReachabilityStatus.Unreachable,
                    error.toRelayStatusMessage("无法连接到 ${config.macDisplayName ?: "Mac"}"),
                )
            }
            if (error.isRetryableRelayFailure()) {
                runCatching {
                    appConfigStore.enqueuePendingNotification(payload.toPendingNotificationEvent())
                }
                schedulePendingRetry()
            }
        }
    }

    private suspend fun flushPendingNotifications(
        config: AppConfig,
        deviceToken: String,
    ): Boolean {
        val pendingEvents = appConfigStore.pendingNotificationEvents()
        if (pendingEvents.isEmpty()) return true
        if (!config.relayEnabled) return true
        if (config.host.isBlank()) return false

        for (event in pendingEvents) {
            val result = relayApi.sendNotificationEvent(
                host = config.host,
                port = config.port,
                deviceToken = deviceToken,
                payload = event.toRelayPayload(),
            )
            if (result.isSuccess) {
                appConfigStore.updateMacReachability(MacReachabilityStatus.Reachable)
                appConfigStore.removePendingNotification(event.eventId)
                appConfigStore.recordRelayActivity(event.toRelayActivityRecord())
            } else {
                val error = result.exceptionOrNull()
                if (error?.isPermanentRelayAuthFailure() == true) {
                    appConfigStore.updateMacReachability(
                        MacReachabilityStatus.AuthFailed,
                        "旧配对已失效，请重新连接 Mac",
                    )
                } else if (error?.isMacReceiverPaused() == true) {
                    appConfigStore.updateMacReachability(
                        MacReachabilityStatus.MacPaused,
                        "Mac 已暂停接收，重新开始后会继续接力",
                    )
                } else if (error != null) {
                    appConfigStore.updateMacReachability(
                        MacReachabilityStatus.Unreachable,
                        error.toRelayStatusMessage("无法连接到 ${config.macDisplayName ?: "Mac"}"),
                    )
                }
                return false
            }
        }
        return true
    }

    private suspend fun flushPendingNotificationsIfDue(
        config: AppConfig,
        deviceToken: String,
        force: Boolean,
    ): Boolean {
        val now = System.currentTimeMillis()
        if (!force && now - lastPendingFlushAt < PENDING_FLUSH_MIN_INTERVAL_MILLIS) {
            return true
        }
        lastPendingFlushAt = now
        return flushPendingNotifications(config, deviceToken)
    }

    private fun schedulePendingRetry() {
        if (retryJob?.isActive == true) return

        retryJob = serviceScope.launch retryLoop@{
            delay(RETRY_INITIAL_DELAY_MILLIS)

            repeat(RETRY_MAX_ATTEMPTS) {
                val config = currentConfig()
                when (heartbeatCoordinator.sendAndUpdateStatus(config, forceFlushPending = true)) {
                    HeartbeatOutcome.Ready,
                    HeartbeatOutcome.PermanentFailure,
                    HeartbeatOutcome.Skipped -> return@retryLoop
                    HeartbeatOutcome.MacPaused,
                    HeartbeatOutcome.TemporaryFailure -> delay(RETRY_INTERVAL_MILLIS)
                }
            }

            appConfigStore.updateMacReachability(
                MacReachabilityStatus.Unreachable,
                "Mac 暂时不可达，后台会继续定期确认",
            )
        }
    }

    private fun NotificationRelayPayload.toRelayActivityRecord(): RelayActivityRecord {
        return RelayActivityRecord(
            eventId = eventId,
            appPackage = appPackage,
            appName = appName,
            title = title.activityPreview(),
            text = text.activityPreview(),
            postedAt = postedAt,
            relayedAt = System.currentTimeMillis(),
        )
    }

    private fun PendingNotificationEvent.toRelayActivityRecord(): RelayActivityRecord {
        return RelayActivityRecord(
            eventId = eventId,
            appPackage = appPackage,
            appName = appName,
            title = title.activityPreview(),
            text = text.activityPreview(),
            postedAt = postedAt,
            relayedAt = System.currentTimeMillis(),
        )
    }

}

private fun NotificationRelayPayload.toPendingNotificationEvent(): PendingNotificationEvent {
    return PendingNotificationEvent(
        eventId = eventId,
        deviceId = deviceId,
        appPackage = appPackage,
        appName = appName,
        title = title,
        text = text,
        postedAt = postedAt,
        notificationKey = notificationKey,
    )
}

private fun PendingNotificationEvent.toRelayPayload(): NotificationRelayPayload {
    return NotificationRelayPayload(
        eventId = eventId,
        deviceId = deviceId,
        appPackage = appPackage,
        appName = appName,
        title = title,
        text = text,
        postedAt = postedAt,
        notificationKey = notificationKey,
    )
}

private fun String.activityPreview(maxLength: Int = 160): String {
    val normalized = trim()
        .replace(Regex("\\s+"), " ")
    return if (normalized.length <= maxLength) {
        normalized
    } else {
        "${normalized.take(maxLength - 1)}…"
    }
}
