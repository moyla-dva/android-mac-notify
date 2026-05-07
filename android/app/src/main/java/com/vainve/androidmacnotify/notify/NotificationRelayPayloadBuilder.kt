package com.vainve.androidmacnotify.notify

import android.app.Notification
import android.content.Context
import android.os.Build
import android.service.notification.StatusBarNotification
import com.vainve.androidmacnotify.network.NotificationRelayPayload
import java.security.MessageDigest

internal class NotificationRelayPayloadBuilder(
    private val context: Context,
) {
    fun title(notification: Notification): String {
        return listOf(
            notification.extras.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE),
            notification.extras.getCharSequence(Notification.EXTRA_TITLE_BIG),
            notification.extras.getCharSequence(Notification.EXTRA_TITLE),
        ).firstNotNullOfOrNull { value ->
            value?.toString()?.trim()?.takeIf { it.isNotBlank() }
        }.orEmpty()
    }

    fun text(notification: Notification): String {
        val messages = extractMessagingStyleText(notification)
        if (messages.isNotBlank()) return messages

        val lines = extractTextLines(notification)
        if (lines.isNotBlank()) return lines

        val direct = notification.extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim().orEmpty()
        if (direct.isNotBlank()) return direct

        val big = notification.extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()?.trim().orEmpty()
        if (big.isNotBlank()) return big

        return notification.tickerText?.toString()?.trim().orEmpty()
    }

    fun decisionText(notification: Notification, title: String, text: String): String {
        val parts = mutableListOf(title, text)
        parts += listOf(
            notification.extras.getCharSequence(Notification.EXTRA_SUB_TEXT),
            notification.extras.getCharSequence(Notification.EXTRA_SUMMARY_TEXT),
            notification.extras.getCharSequence(Notification.EXTRA_INFO_TEXT),
        ).mapNotNull { value ->
            value?.toString()?.trim()?.takeIf { it.isNotBlank() }
        }
        val messageSenders = extractMessagingStyleSenders(notification)
        if (messageSenders.isNotBlank()) parts += messageSenders
        return parts
            .map { it.trim() }
            .filter { it.isNotBlank() }
            .distinct()
            .joinToString(separator = "\n")
    }

    fun build(
        source: StatusBarNotification,
        deviceId: String,
        title: String,
        text: String,
    ): NotificationRelayPayload {
        return NotificationRelayPayload(
            eventId = buildEventId(source, deviceId, title, text),
            deviceId = deviceId,
            appPackage = source.packageName,
            appName = resolveAppName(source.packageName),
            title = title,
            text = text,
            postedAt = source.postTime,
            notificationKey = source.key ?: source.packageName,
        )
    }

    private fun extractMessagingStyleText(notification: Notification): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return ""

        @Suppress("DEPRECATION")
        val rawMessages = notification.extras.getParcelableArray(Notification.EXTRA_MESSAGES) ?: return ""
        return Notification.MessagingStyle.Message.getMessagesFromBundleArray(rawMessages)
            ?.mapNotNull { message -> message.text?.toString()?.trim()?.takeIf { it.isNotBlank() } }
            ?.joinToString(separator = "\n")
            .orEmpty()
    }

    private fun extractMessagingStyleSenders(notification: Notification): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return ""

        @Suppress("DEPRECATION")
        val rawMessages = notification.extras.getParcelableArray(Notification.EXTRA_MESSAGES) ?: return ""
        return Notification.MessagingStyle.Message.getMessagesFromBundleArray(rawMessages)
            ?.mapNotNull { message ->
                @Suppress("DEPRECATION")
                message.sender?.toString()?.trim()?.takeIf { it.isNotBlank() }
            }
            ?.distinct()
            ?.joinToString(separator = "\n")
            .orEmpty()
    }

    private fun extractTextLines(notification: Notification): String {
        return notification.extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
            ?.mapNotNull { line -> line?.toString()?.trim()?.takeIf { it.isNotBlank() } }
            ?.joinToString(separator = "\n")
            .orEmpty()
    }

    private fun resolveAppName(packageName: String): String {
        return runCatching {
            val packageManager = context.packageManager
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(appInfo).toString()
        }.getOrDefault(packageName)
    }

    private fun buildEventId(
        sbn: StatusBarNotification,
        deviceId: String,
        title: String,
        text: String,
    ): String {
        val raw = listOf(
            deviceId,
            sbn.key ?: sbn.packageName,
            sbn.postTime.toString(),
            sbn.packageName,
            title,
            text,
        ).joinToString("|")
        val digest = MessageDigest.getInstance("SHA-256").digest(raw.toByteArray(Charsets.UTF_8))
        return "evt_${digest.toHexString().take(24)}"
    }
}

private fun ByteArray.toHexString(): String {
    return joinToString(separator = "") { byte ->
        (byte.toInt() and 0xff).toString(16).padStart(2, '0')
    }
}
