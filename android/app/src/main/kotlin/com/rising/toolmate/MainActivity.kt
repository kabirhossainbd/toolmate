package com.rising.toolmate

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Bundle
import id.flutter.flutter_background_service.BackgroundService
import id.flutter.flutter_background_service.Config
import id.flutter.flutter_background_service.WatchdogReceiver
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "toolmate/app_info"

    override fun onCreate(savedInstanceState: Bundle?) {
        // Kill leftover FGS BEFORE the UI FlutterEngine starts.
        stopLeftoverBackgroundEngine()
        // Never restore a dead Flutter instance from a process kept alive by NLS.
        super.onCreate(null)
    }

    override fun shouldDestroyEngineWithHost(): Boolean = true

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "getAppIcon") {
                    val packageName = call.argument<String>("packageName")
                    if (packageName.isNullOrBlank()) {
                        result.success(null)
                    } else {
                        result.success(loadAppIcon(packageName))
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun stopLeftoverBackgroundEngine() {
        try {
            Config(applicationContext).apply {
                setManuallyStopped(true)
                setAutoStartOnBoot(false)
            }
            WatchdogReceiver.remove(applicationContext)
            stopService(Intent(this, BackgroundService::class.java))
        } catch (_: Exception) {
        }
    }

    private fun loadAppIcon(packageName: String): ByteArray? {
        return try {
            drawableToPng(packageManager.getApplicationIcon(packageName))
        } catch (_: Exception) {
            null
        }
    }

    private fun drawableToPng(drawable: Drawable): ByteArray? {
        val src = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            drawable.bitmap
        } else {
            val w = (if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 96)
                .coerceAtMost(192)
            val h = (if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 96)
                .coerceAtMost(192)
            val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            bmp
        }
        val scaled = if (src.width > 192 || src.height > 192) {
            Bitmap.createScaledBitmap(src, 192, 192, true)
        } else {
            src
        }
        val out = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.PNG, 90, out)
        return out.toByteArray()
    }
}
