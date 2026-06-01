package com.louisyang.aidflowlite.notifications

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.louisyang.aidflowlite.R
import com.louisyang.aidflowlite.data.CprState

class CprNotificationHelper(private val context: Context) {
    private val channelId = "aidflow_cpr"
    private val notificationId = 30_110

    fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            channelId,
            "CPR Counter",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Ongoing CPR counter status"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    fun update(state: CprState) {
        if (!hasNotificationPermission()) return
        ensureChannel()

        val content = if (state.isBreathPhase) {
            "Breaths: ${state.breathSecondsRemaining}s left | Cycles ${state.cycleCount}"
        } else {
            "Compressions ${state.compressionCount}/30 | Cycles ${state.cycleCount}"
        }

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle(if (state.isRunning) "AidFlow CPR running" else "AidFlow CPR paused")
            .setContentText(content)
            .setOngoing(state.isRunning)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        NotificationManagerCompat.from(context).notify(notificationId, notification)
    }

    fun clear() {
        NotificationManagerCompat.from(context).cancel(notificationId)
    }

    private fun hasNotificationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
    }
}
