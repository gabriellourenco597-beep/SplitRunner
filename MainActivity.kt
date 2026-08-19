  package com.splitrunner

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "splitrunner/overlay"

    private lateinit var methodChannel: MethodChannel

    // ============================================================
    // RECEBE COMANDOS DO OVERLAY
    // ============================================================

    private val overlayReceiver = object : BroadcastReceiver() {

        override fun onReceive(
            context: Context?,
            intent: Intent?
        ) {

            when (intent?.action) {

                OverlayService.ACTION_TOGGLE -> {

                    if (::methodChannel.isInitialized) {

                        methodChannel.invokeMethod(
                            "toggleTimerFromOverlay",
                            null
                        )
                    }
                }

                OverlayService.ACTION_RESTART -> {

                    if (::methodChannel.isInitialized) {

                        methodChannel.invokeMethod(
                            "restartTimerFromOverlay",
                            null
                        )
                    }
                }
            }
        }
    }

    // ============================================================
    // ON CREATE
    // ============================================================

    override fun onCreate(
        savedInstanceState: Bundle?
    ) {

        super.onCreate(savedInstanceState)

        val filter = IntentFilter().apply {

            addAction(
                OverlayService.ACTION_TOGGLE
            )

            addAction(
                OverlayService.ACTION_RESTART
            )
        }

        if (
            Build.VERSION.SDK_INT >=
            Build.VERSION_CODES.TIRAMISU
        ) {

            registerReceiver(
                overlayReceiver,
                filter,
                Context.RECEIVER_NOT_EXPORTED
            )

        } else {

            @Suppress("DEPRECATION")

            registerReceiver(
                overlayReceiver,
                filter
            )
        }
    }

    // ============================================================
    // FLUTTER ENGINE
    // ============================================================

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {

        super.configureFlutterEngine(
            flutterEngine
        )

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        methodChannel.setMethodCallHandler {
            call,
            result ->

            when (call.method) {

                // ==================================================
                // VERIFICAR PERMISSÃO
                // ==================================================

                "isOverlayGranted" -> {

                    val granted =
                        if (
                            Build.VERSION.SDK_INT >=
                            Build.VERSION_CODES.M
                        ) {

                            Settings.canDrawOverlays(
                                this
                            )

                        } else {

                            true
                        }

                    result.success(granted)
                }

                // ==================================================
                // PEDIR PERMISSÃO
                // ==================================================

                "requestOverlayPermission" -> {

                    if (
                        Build.VERSION.SDK_INT >=
                        Build.VERSION_CODES.M &&
                        !Settings.canDrawOverlays(this)
                    ) {

                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse(
                                "package:$packageName"
                            )
                        )

                        startActivity(intent)
                    }

                    result.success(null)
                }

                // ==================================================
                // INICIAR OVERLAY
                // ==================================================

                "startOverlay" -> {

                    if (
                        Build.VERSION.SDK_INT >=
                        Build.VERSION_CODES.M &&
                        !Settings.canDrawOverlays(this)
                    ) {

                        result.error(
                            "NO_PERMISSION",
                            "Permissão de overlay não concedida",
                            null
                        )

                        return@setMethodCallHandler
                    }

                    val intent = Intent(
                        this,
                        OverlayService::class.java
                    ).apply {

                        action =
                            OverlayService.ACTION_START

                        putExtra(
                            "elapsedMs",
                            call.argument<Int>(
                                "elapsedMs"
                            ) ?: 0
                        )

                        putExtra(
                            "running",
                            call.argument<Boolean>(
                                "running"
                            ) ?: false
                        )

                        putExtra(
                            "current",
                            call.argument<String>(
                                "current"
                            ) ?: "Início"
                        )

                        putExtra(
                            "next",
                            call.argument<String>(
                                "next"
                            ) ?: "FINAL"
                        )
                    }

                    if (
                        Build.VERSION.SDK_INT >=
                        Build.VERSION_CODES.O
                    ) {

                        startForegroundService(
                            intent
                        )

                    } else {

                        startService(intent)
                    }

                    result.success(null)
                }

                // ==================================================
                // ATUALIZAR OVERLAY
                // ==================================================

                "updateOverlay" -> {

                    val intent = Intent(
                        this,
                        OverlayService::class.java
                    ).apply {

                        action =
                            OverlayService.ACTION_UPDATE

                        putExtra(
                            "elapsedMs",
                            call.argument<Int>(
                                "elapsedMs"
                            ) ?: 0
                        )

                        putExtra(
                            "running",
                            call.argument<Boolean>(
                                "running"
                            ) ?: false
                        )

                        putExtra(
                            "current",
                            call.argument<String>(
                                "current"
                            ) ?: "Início"
                        )

                        putExtra(
                            "next",
                            call.argument<String>(
                                "next"
                            ) ?: "FINAL"
                        )
                    }

                    if (
                        Build.VERSION.SDK_INT >=
                        Build.VERSION_CODES.O
                    ) {

                        startForegroundService(
                            intent
                        )

                    } else {

                        startService(intent)
                    }

                    result.success(null)
                }

                // ==================================================
                // PARAR OVERLAY
                // ==================================================

                "stopOverlay" -> {

                    val intent = Intent(
                        this,
                        OverlayService::class.java
                    ).apply {

                        action =
                            OverlayService.ACTION_STOP
                    }

                    startService(intent)

                    result.success(null)
                }

                // ==================================================
                // MÉTODO DESCONHECIDO
                // ==================================================

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // ============================================================
    // DESTROY
    // ============================================================

    override fun onDestroy() {

        try {

            unregisterReceiver(
                overlayReceiver
            )

        } catch (_: Exception) {
        }

        super.onDestroy()
    }
}               
