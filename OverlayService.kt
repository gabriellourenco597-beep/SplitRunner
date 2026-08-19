  package com.splitrunner

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView

class OverlayService : Service() {

    companion object {

        const val ACTION_START =
            "splitrunner.START"

        const val ACTION_UPDATE =
            "splitrunner.UPDATE"

        const val ACTION_STOP =
            "splitrunner.STOP"

        // Comandos enviados do Overlay para o Flutter
        const val ACTION_TOGGLE =
            "splitrunner.OVERLAY_TOGGLE"

        const val ACTION_RESTART =
            "splitrunner.OVERLAY_RESTART"

        private const val CHANNEL_ID =
            "splitrunner_overlay"

        private const val NOTIFICATION_ID =
            2211

        private const val DOUBLE_TAP_DELAY =
            280L

        private const val TOUCH_SLOP =
            20f
    }

    private lateinit var windowManager: WindowManager

    private var overlayView: LinearLayout? = null

    private var timerText: TextView? = null

    private var currentText: TextView? = null

    private var nextText: TextView? = null

    private val handler =
        Handler(Looper.getMainLooper())

    private var baseElapsed =
        0L

    private var startedAt =
        0L

    private var running =
        false

    private var current =
        "Início"

    private var next =
        "FINAL"

    private var params:
        WindowManager.LayoutParams? = null

    // ============================================================
    // CONTROLE DE TOQUE
    // ============================================================

    private var downX =
        0f

    private var downY =
        0f

    private var startX =
        0

    private var startY =
        0

    private var moved =
        false

    private var waitingSecondTap =
        false

    // ============================================================
    // PRIMEIRO TOQUE
    // ============================================================

    private val singleTapRunnable =
        Runnable {

            waitingSecondTap =
                false

            sendOverlayAction(
                ACTION_TOGGLE
            )
        }

    // ============================================================
    // ATUALIZAÇÃO
    // ============================================================

    private val updater =
        object : Runnable {

            override fun run() {

                updateUi()

                handler.postDelayed(
                    this,
                    50
                )
            }
        }

    // ============================================================
    // ON CREATE
    // ============================================================

    override fun onCreate() {

        super.onCreate()

        createNotificationChannel()

        startForeground(
            NOTIFICATION_ID,
            buildNotification()
        )

        windowManager =
            getSystemService(
                WINDOW_SERVICE
            ) as WindowManager
    }

    // ============================================================
    // ON START COMMAND
    // ============================================================

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int
    ): Int {

        when (intent?.action) {

            // ----------------------------------------------------
            // START
            // ----------------------------------------------------

            ACTION_START -> {

                baseElapsed =
                    intent.getIntExtra(
                        "elapsedMs",
                        0
                    ).toLong()

                running =
                    intent.getBooleanExtra(
                        "running",
                        false
                    )

                current =
                    intent.getStringExtra(
                        "current"
                    ) ?: "Início"

                next =
                    intent.getStringExtra(
                        "next"
                    ) ?: "FINAL"

                startedAt =
                    SystemClock.elapsedRealtime()

                showOverlay()
            }

            // ----------------------------------------------------
            // UPDATE
            // ----------------------------------------------------

            ACTION_UPDATE -> {

                baseElapsed =
                    intent.getIntExtra(
                        "elapsedMs",
                        0
                    ).toLong()

                running =
                    intent.getBooleanExtra(
                        "running",
                        false
                    )

                current =
                    intent.getStringExtra(
                        "current"
                    ) ?: current

                next =
                    intent.getStringExtra(
                        "next"
                    ) ?: next

                startedAt =
                    SystemClock.elapsedRealtime()

                updateUi()
            }

            // ----------------------------------------------------
            // STOP
            // ----------------------------------------------------

            ACTION_STOP -> {

                stopOverlay()
            }
        }

        return START_STICKY
    }

    // ============================================================
    // CRIAR OVERLAY
    // ============================================================

    private fun showOverlay() {

        if (
            !Settings.canDrawOverlays(this)
        ) {
            return
        }

        if (
            overlayView != null
        ) {
            return
        }

        val root =
            LinearLayout(this).apply {

                orientation =
                    LinearLayout.VERTICAL

                setPadding(
                    18,
                    12,
                    18,
                    12
                )

                setBackgroundColor(
                    Color.argb(
                        220,
                        15,
                        17,
                        20
                    )
                )
            }

        // ========================================================
        // TIMER
        // ========================================================

        timerText =
            TextView(this).apply {

                text =
                    "00:00.00"

                setTextColor(
                    Color.WHITE
                )

                textSize =
                    28f

                setTypeface(
                    typeface,
                    android.graphics.Typeface.BOLD
                )
            }

        // ========================================================
        // SPLIT ATUAL
        // ========================================================

        currentText =
            TextView(this).apply {

                setTextColor(
                    Color.GREEN
                )

                textSize =
                    15f
            }

        // ========================================================
        // PRÓXIMO SPLIT
        // ========================================================

        nextText =
            TextView(this).apply {

                setTextColor(
                    Color.LTGRAY
                )

                textSize =
                    13f
            }

        root.addView(
            timerText
        )

        root.addView(
            currentText
        )

        root.addView(
            nextText
        )

        // ========================================================
        // TIPO DE JANELA
        // ========================================================

        val type =
            if (
                Build.VERSION.SDK_INT >=
                Build.VERSION_CODES.O
            ) {

                WindowManager
                    .LayoutParams
                    .TYPE_APPLICATION_OVERLAY

            } else {

                @Suppress("DEPRECATION")

                WindowManager
                    .LayoutParams
                    .TYPE_PHONE
            }

        // ========================================================
        // PARÂMETROS
        // ========================================================

        params =
            WindowManager.LayoutParams(

                WindowManager
                    .LayoutParams
                    .WRAP_CONTENT,

                WindowManager
                    .LayoutParams
                    .WRAP_CONTENT,

                type,

                WindowManager
                    .LayoutParams
                    .FLAG_NOT_FOCUSABLE or
                        WindowManager
                            .LayoutParams
                            .FLAG_LAYOUT_NO_LIMITS,

                PixelFormat.TRANSLUCENT

            ).apply {

                gravity =
                    Gravity.TOP or
                            Gravity.START

                x =
                    20

                y =
                    100
            }

        // ========================================================
        // TOUCH
        // ========================================================

        root.setOnTouchListener { view, event ->

            when (
                event.actionMasked
            ) {

                // ------------------------------------------------
                // DOWN
                // ------------------------------------------------

                MotionEvent.ACTION_DOWN -> {

                    downX =
                        event.rawX

                    downY =
                        event.rawY

                    startX =
                        params?.x ?: 20

                    startY =
                        params?.y ?: 100

                    moved =
                        false

                    true
                }

                // ------------------------------------------------
                // MOVE
                // ------------------------------------------------

                MotionEvent.ACTION_MOVE -> {

                    val dx =
                        event.rawX -
                                downX

                    val dy =
                        event.rawY -
                                downY

                    if (
                        kotlin.math.abs(dx) >
                        TOUCH_SLOP ||
                        kotlin.math.abs(dy) >
                        TOUCH_SLOP
                    ) {

                        moved =
                            true
                    }

                    if (moved) {

                        params?.x =
                            startX +
                                    dx.toInt()

                        params?.y =
                            startY +
                                    dy.toInt()

                        try {

                            windowManager
                                .updateViewLayout(
                                    view,
                                    params
                                )

                        } catch (
                            _: Exception
                        ) {
                        }
                    }

                    true
                }

                // ------------------------------------------------
                // UP
                // ------------------------------------------------

                MotionEvent.ACTION_UP -> {

                    if (!moved) {

                        handleTap()
                    }

                    true
                }

                // ------------------------------------------------
                // CANCEL
                // ------------------------------------------------

                MotionEvent.ACTION_CANCEL -> {

                    moved =
                        false

                    true
                }

                else -> true
            }
        }

        // ========================================================
        // MOSTRAR
        // ========================================================

        overlayView =
            root

        windowManager.addView(
            root,
            params
        )

        handler.removeCallbacks(
            updater
        )

        handler.post(
            updater
        )

        updateUi()
    }

    // ============================================================
    // DETECTAR TOQUE
    // ============================================================

    private fun handleTap() {

        if (
            waitingSecondTap
        ) {

            // ====================================================
            // SEGUNDO TOQUE
            // REINICIAR
            // ====================================================

            handler.removeCallbacks(
                singleTapRunnable
            )

            waitingSecondTap =
                false

            sendOverlayAction(
                ACTION_RESTART
            )

        } else {

            // ====================================================
            // PRIMEIRO TOQUE
            // AGUARDA SEGUNDO
            // ====================================================

            waitingSecondTap =
                true

            handler.postDelayed(
                singleTapRunnable,
                DOUBLE_TAP_DELAY
            )
        }
    }

    // ============================================================
    // ENVIAR COMANDO PARA MAINACTIVITY
    // ============================================================

    private fun sendOverlayAction(
        action: String
    ) {

        val intent =
            Intent(action).apply {

                setPackage(
                    packageName
                )
            }

        sendBroadcast(
            intent
        )
    }

    // ============================================================
    // ATUALIZAR UI
    // ============================================================

    private fun updateUi() {

        val elapsed =
            if (running) {

                baseElapsed +
                        (
                            SystemClock
                                .elapsedRealtime() -
                                    startedAt
                            )

            } else {

                baseElapsed
            }

        timerText?.text =
            formatTime(
                elapsed
            )

        currentText?.text =
            "▶ $current"

        nextText?.text =
            "Próximo: $next"
    }

    // ============================================================
    // FORMATAR TEMPO
    // ============================================================

    private fun formatTime(
        ms: Long
    ): String {

        val minutes =
            ms / 60000

        val seconds =
            (ms / 1000) % 60

        val centis =
            (ms % 1000) / 10

        return String.format(
            "%02d:%02d.%02d",
            minutes,
            seconds,
            centis
        )
    }

    // ============================================================
    // PARAR OVERLAY
    // ============================================================

    private fun stopOverlay() {

        handler.removeCallbacks(
            updater
        )

        handler.removeCallbacks(
            singleTapRunnable
        )

        overlayView?.let {

            try {

                windowManager.removeView(
                    it
                )

            } catch (
                _: Exception
            ) {
            }
        }

        overlayView =
            null

        stopForeground(
            STOP_FOREGROUND_REMOVE
        )

        stopSelf()
    }

    // ============================================================
    // NOTIFICATION CHANNEL
    // ============================================================

    private fun createNotificationChannel() {

        if (
            Build.VERSION.SDK_INT >=
            Build.VERSION_CODES.O
        ) {

            val manager =
                getSystemService(
                    NotificationManager::class.java
                )

            manager.createNotificationChannel(

                NotificationChannel(
                    CHANNEL_ID,
                    "SplitRunner Overlay",
                    NotificationManager.IMPORTANCE_LOW
                )
            )
        }
    }

    // ============================================================
    // NOTIFICAÇÃO
    // ============================================================

    private fun buildNotification():
        Notification {

        return if (
            Build.VERSION.SDK_INT >=
            Build.VERSION_CODES.O
        ) {

            Notification.Builder(
                this,
                CHANNEL_ID
            )
                .setContentTitle(
                    "SplitRunner"
                )
                .setContentText(
                    "Overlay ativo"
                )
                .setSmallIcon(
                    android.R.drawable
                        .ic_media_play
                )
                .setOngoing(
                    true
                )
                .build()

        } else {

            @Suppress("DEPRECATION")

            Notification.Builder(
                this
            )
                .setContentTitle(
                    "SplitRunner"
                )
                .setContentText(
                    "Overlay ativo"
                )
                .setSmallIcon(
                    android.R.drawable
                        .ic_media_play
                )
                .setOngoing(
                    true
                )
                .build()
        }
    }

    // ============================================================
    // DESTROY
    // ============================================================

    override fun onDestroy() {

        handler.removeCallbacks(
            updater
        )

        handler.removeCallbacks(
            singleTapRunnable
        )

        overlayView?.let {

            try {

                windowManager
                    .removeView(it)

            } catch (
                _: Exception
            ) {
            }
        }

        overlayView =
            null

        super.onDestroy()
    }

    // ============================================================
    // BIND
    // ============================================================

    override fun onBind(
        intent: Intent?
    ): IBinder? {

        return null
    }
}                                   
