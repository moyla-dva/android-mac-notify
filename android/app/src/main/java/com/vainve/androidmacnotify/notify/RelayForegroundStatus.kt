package com.vainve.androidmacnotify.notify

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.util.Log
import com.vainve.androidmacnotify.MainActivity
import com.vainve.androidmacnotify.R
import com.vainve.androidmacnotify.data.AppConfig
import com.vainve.androidmacnotify.data.MacReachabilityStatus

object RelayForegroundStatus {
    private const val CHANNEL_ID = "relay_status"
    private const val NOTIFICATION_ID = 1001

    fun start(service: Service, config: AppConfig? = null) {
        createChannel(service)
        val notification = buildNotification(service, config)

        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                service.startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE,
                )
            } else {
                service.startForeground(NOTIFICATION_ID, notification)
            }
        }.onFailure { error ->
            Log.w("AndroidMacNotify", "Unable to start foreground relay status", error)
        }
    }

    fun update(context: Context, config: AppConfig) {
        createChannel(context)
        val manager = context.getSystemService(NotificationManager::class.java)
        runCatching {
            manager.notify(NOTIFICATION_ID, buildNotification(context, config))
        }.onFailure { error ->
            Log.w("AndroidMacNotify", "Unable to update foreground relay status", error)
        }
    }

    private fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            "接力状态",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "显示 Android 与 Mac 接力正在运行"
            setShowBadge(false)
        }

        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(context: Context, config: AppConfig?): Notification {
        val contentIntent = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java)
                .setAction(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_LAUNCHER),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val title = when {
            config == null || config.deviceToken.isNullOrBlank() || config.host.isBlank() -> {
                "接力服务待命中"
            }
            !config.relayEnabled || config.macReachabilityStatus == MacReachabilityStatus.Paused -> {
                "接力已暂停"
            }
            config.macReachabilityStatus == MacReachabilityStatus.AuthFailed -> {
                "配对已失效"
            }
            config.macReachabilityStatus == MacReachabilityStatus.MacPaused -> {
                "Mac 已暂停接收"
            }
            config.macReachabilityStatus == MacReachabilityStatus.Unreachable -> {
                "无法连接到 ${config.macDisplayName ?: "Mac"}"
            }
            config.macReachabilityStatus == MacReachabilityStatus.Unknown -> {
                "正在确认 ${config.macDisplayName ?: "Mac"}"
            }
            else -> {
                "正在接力到 ${config.macDisplayName ?: "Mac"}"
            }
        }
        val text = when {
            config == null || config.deviceToken.isNullOrBlank() || config.host.isBlank() -> {
                "配对 Mac 后，通知和文件会变成可处理的动作。"
            }
            !config.relayEnabled || config.macReachabilityStatus == MacReachabilityStatus.Paused -> {
                "恢复接力后，手机通知和文件会继续发送到 Mac。"
            }
            config.macReachabilityStatus == MacReachabilityStatus.AuthFailed -> {
                "需要重新选择 Mac 并完成配对确认。"
            }
            config.macReachabilityStatus == MacReachabilityStatus.MacPaused -> {
                config.macReachabilityMessage ?: "Mac 接收器暂时不处理通知和文件。"
            }
            config.macReachabilityStatus == MacReachabilityStatus.Unreachable -> {
                config.macReachabilityMessage ?: "请确认 Mac 应用正在运行，并且两端在同一网络。"
            }
            config.macReachabilityStatus == MacReachabilityStatus.Unknown -> {
                "后台正在通过心跳确认连接状态。"
            }
            else -> {
                "手机通知和文件会在 Mac 上变成可处理的动作。"
            }
        }

        return Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_relay)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(contentIntent)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .build()
    }
}
