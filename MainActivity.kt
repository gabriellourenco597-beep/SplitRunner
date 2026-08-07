package com.splitrunner

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "splitrunner/overlay"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "isOverlayGranted" -> result.success(Settings.canDrawOverlays(this))
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                    }
                    result.success(null)
                }
                "startOverlay" -> {
                    if (!Settings.canDrawOverlays(this)) {
                        result.error("NO_PERMISSION", "Permissão de overlay não concedida", null)
                        return@setMethodCallHandler
                    }
                    val intent = Intent(this, OverlayService::class.java).apply {
                        action = OverlayService.ACTION_START
                        putExtra("elapsedMs", call.argument<Int>("elapsedMs") ?: 0)
                        putExtra("running", call.argument<Boolean>("running") ?: false)
                        putExtra("current", call.argument<String>("current") ?: "Início")
                        putExtra("next", call.argument<String>("next") ?: "FINAL")
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent) else startService(intent)
                    result.success(null)
                }
                "updateOverlay" -> {
                    val intent = Intent(this, OverlayService::class.java).apply {
                        action = OverlayService.ACTION_UPDATE
                        putExtra("elapsedMs", call.argument<Int>("elapsedMs") ?: 0)
                        putExtra("running", call.argument<Boolean>("running") ?: false)
                        putExtra("current", call.argument<String>("current") ?: "Início")
                        putExtra("next", call.argument<String>("next") ?: "FINAL")
                    }
                    startService(intent)
                    result.success(null)
                }
                "stopOverlay" -> {
                    val intent = Intent(this, OverlayService::class.java).apply { action = OverlayService.ACTION_STOP }
                    startService(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
