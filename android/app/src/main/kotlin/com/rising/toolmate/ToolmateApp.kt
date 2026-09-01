package com.rising.toolmate

import android.app.Application
import android.os.Build

/// Default process hosts Flutter. The `:nls` process must not touch Flutter —
/// that is what froze cold start on `onPreDraw return false`.
class ToolmateApp : Application() {
    override fun onCreate() {
        super.onCreate()
        if (isNotificationProcess()) return
    }

    private fun isNotificationProcess(): Boolean {
        val name = if (Build.VERSION.SDK_INT >= 28) {
            getProcessName()
        } else {
            try {
                val pid = android.os.Process.myPid()
                val am = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
                am.runningAppProcesses?.firstOrNull { it.pid == pid }?.processName
            } catch (_: Exception) {
                null
            }
        }
        return name?.endsWith(":nls") == true
    }
}
