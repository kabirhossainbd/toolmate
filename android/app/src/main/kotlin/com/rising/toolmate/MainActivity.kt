package com.rising.toolmate

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

/**
 * Swipe-from-recents leaves [flutter_background_service]'s FlutterEngine alive
 * (WatchdogReceiver respawns it). A second UI engine then hangs on the splash.
 * Clear that leftover engine before Flutter Activity starts, and stop it when
 * the task is removed so the next cold start is clean.
 */
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        stopLeftoverBackgroundService()
        super.onCreate(savedInstanceState)
    }

    override fun onDestroy() {
        // Activity has no onTaskRemoved; stop leftover service when this
        // task is finishing (e.g. swipe-from-recents).
        if (isFinishing) {
            stopLeftoverBackgroundService()
        }
        super.onDestroy()
    }

    private fun stopLeftoverBackgroundService() {
        try {
            val prefs = applicationContext.getSharedPreferences(
                "id.flutter.background_service",
                Context.MODE_PRIVATE,
            )
            prefs.edit().putBoolean("is_manually_stopped", true).commit()

            cancelWatchdog()

            val serviceClass = Class.forName(
                "id.flutter.flutter_background_service.BackgroundService",
            )
            stopService(Intent(applicationContext, serviceClass))
        } catch (_: Throwable) {
            // Plugin may be absent in some build variants.
        }
    }

    private fun cancelWatchdog() {
        try {
            val receiverClass = Class.forName(
                "id.flutter.flutter_background_service.WatchdogReceiver",
            )
            val intent = Intent(applicationContext, receiverClass).apply {
                action = "id.flutter.background_service.RESPAWN"
            }
            var flags = PendingIntent.FLAG_CANCEL_CURRENT
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                flags = flags or PendingIntent.FLAG_MUTABLE
            }
            val pi = PendingIntent.getBroadcast(applicationContext, 111, intent, flags)
            val am = getSystemService(ALARM_SERVICE) as AlarmManager
            am.cancel(pi)
            pi.cancel()
        } catch (_: Throwable) {
            // Best-effort.
        }
    }
}
