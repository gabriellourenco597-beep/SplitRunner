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
        const val ACTION_START = "splitrunner.START"
        const val ACTION_UPDATE = "splitrunner.UPDATE"
        const val ACTION_STOP = "splitrunner.STOP"

        private const val CHANNEL_ID = "splitrunner_overlay"
        private const val NOTIFICATION_ID = 2211

        // Tempo máximo entre dois toques para considerar double tap
        private const val DOUBLE_TAP_TIMEOUT = 300L

        // Distância máxima para considerar toque em vez de arrasto
        private const val TOUCH_SLOP = 20f
    }

    private lateinit var windowManager: WindowManager

    private var overlayView: LinearLayout? = null
    private var timerText: TextView? = null
    private var currentText: TextView? = null
    private var nextText: TextView? = null

    private val handler = Handler(Looper.getMainLooper())

    private var baseElapsed = 0L
    private var startedAt = 0L
    private var running = false

    private var current = "Início"
    private var next = "FINAL"

    private var params: WindowManager.LayoutParams? = null

    // ============================================================
    // CONTROLE DE TOQUES
    // ============================================================

    private var lastTapTime = 0L

    private var tapDownX = 0f
    private var tapDownY = 0f

    private var isDragging = false

    private val singleTapRunnable = Runnable {
        if (!isDragging) {
            toggleTimer()
        }
    }

    // ============================================================
    // ATUALIZAÇÃO DO TIMER
    // ============================================================

    private val updater = object : Runnable {
        override fun run() {
            updateUi()
            handler.postDelayed(this, 50)
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
            getSystemService(WINDOW_SERVICE) as WindowManager
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
            // INICIAR OVERLAY
            // ----------------------------------------------------

            ACTION_START -> {

                baseElapsed =
                    intent
                        .getIntExtra("elapsedMs", 0)
                        .toLong()

                running =
                    intent.getBooleanExtra(
                        "running",
                        false
                    )

                current =
                    intent.getStringExtra("current")
                        ?: "Início"

                next =
                    intent.getStringExtra("next")
                        ?: "FINAL"

                startedAt =
                    SystemClock.elapsedRealtime()

                showOverlay()
            }

            // ----------------------------------------------------
            // ATUALIZAR OVERLAY
            // ----------------------------------------------------

            ACTION_UPDATE -> {

                baseElapsed =
                    intent
                        .getIntExtra("elapsedMs", 0)
                        .toLong()

                running =
                    intent.getBooleanExtra(
                        "running",
                        false
                    )

                current =
                    intent.getStringExtra("current")
                        ?: current

                next =
                    intent.getStringExtra("next")
                        ?: next

                startedAt =
                    SystemClock.elapsedRealtime()

                updateUi()
            }

            // ----------------------------------------------------
            // PARAR OVERLAY
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

        if (!Settings.canDrawOverlays(this)) {
            return
        }

        if (overlayView != null) {
            return
        }

        // --------------------------------------------------------
        // CONTAINER
        // --------------------------------------------------------

        val root = LinearLayout(this).apply {

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

        // --------------------------------------------------------
        // TIMER
        // --------------------------------------------------------

        timerText =
            TextView(this).apply {

                text = "00:00.00"

                setTextColor(
                    Color.WHITE
                )

                textSize = 28f

                setTypeface(
                    typeface,
                    android.graphics.Typeface.BOLD
                )
            }

        // --------------------------------------------------------
        // SPLIT ATUAL
        // --------------------------------------------------------

        currentText =
            TextView(this).apply {

                setTextColor(
                    Color.GREEN
                )

                textSize = 15f
            }

        // --------------------------------------------------------
        // PRÓXIMO SPLIT
        // --------------------------------------------------------

        nextText =
            TextView(this).apply {

                setTextColor(
                    Color.LTGRAY
                )

                textSize = 13f
            }

        root.addView(timerText)
        root.addView(currentText)
        root.addView(nextText)

        // ========================================================
        // TIPO DA JANELA
        // ========================================================

        val type =
            if (Build.VERSION.SDK_INT >=
                Build.VERSION_CODES.O
            ) {

                WindowManager.LayoutParams
                    .TYPE_APPLICATION_OVERLAY

            } else {

                @Suppress("DEPRECATION")

                WindowManager.LayoutParams
                    .TYPE_PHONE
            }

        // ========================================================
        // PARÂMETROS
        // ========================================================

        params =
            WindowManager.LayoutParams(

                WindowManager.LayoutParams.WRAP_CONTENT,

                WindowManager.LayoutParams.WRAP_CONTENT,

                type,

                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,

                PixelFormat.TRANSLUCENT

            ).apply {

                gravity =
                    Gravity.TOP or
                            Gravity.START

                x = 20
                y = 100
            }

        // ========================================================
        // CONTROLE DE TOQUE
        // ========================================================

        var downX = 0f
        var downY = 0f

        var startX = 0
        var startY = 0

        root.setOnTouchListener { view, event ->

            when (event.actionMasked) {

                // =================================================
                // TOQUE INICIAL
                // =================================================

                MotionEvent.ACTION_DOWN -> {

                    downX = event.rawX
                    downY = event.rawY

                    tapDownX = event.rawX
                    tapDownY = event.rawY

                    startX =
                        params?.x ?: 0

                    startY =
                        params?.y ?: 0

                    isDragging = false

                    true
                }

                // =================================================
                // MOVIMENTO
                // =================================================

                MotionEvent.ACTION_MOVE -> {

                    val dx =
                        event.rawX - downX

                    val dy =
                        event.rawY - downY

                    // Verifica se realmente está arrastando
                    if (
                        kotlin.math.abs(dx) > TOUCH_SLOP ||
                        kotlin.math.abs(dy) > TOUCH_SLOP
                    ) {

                        isDragging = true

                        // Cancela possível toque simples
                        handler.removeCallbacks(
                            singleTapRunnable
                        )

                        params?.let { p ->

                            p.x =
                                startX +
                                        dx.toInt()

                            p.y =
                                startY +
                                        dy.toInt()

                            try {

                                windowManager
                                    .updateViewLayout(
                                        view,
                                        p
                                    )

                            } catch (_: Exception) {
                            }
                        }
                    }

                    true
                }

                // =================================================
                // TOQUE SOLTO
                // =================================================

                MotionEvent.ACTION_UP -> {

                    val dx =
                        event.rawX - tapDownX

                    val dy =
                        event.rawY - tapDownY

                    val moved =
                        kotlin.math.abs(dx) > TOUCH_SLOP ||
                                kotlin.math.abs(dy) > TOUCH_SLOP

                    // ------------------------------------------------
                    // SE FOI ARRASTO
                    // ------------------------------------------------

                    if (
                        moved ||
                        isDragging
                    ) {

                        isDragging = false

                        return@setOnTouchListener true
                    }

                    // ------------------------------------------------
                    // TOQUE
                    // ------------------------------------------------

                    val now =
                        SystemClock.elapsedRealtime()

                    val timeSinceLastTap =
                        now - lastTapTime

                    if (
                        lastTapTime != 0L &&
                        timeSinceLastTap <=
                        DOUBLE_TAP_TIMEOUT
                    ) {

                        // =================================================
                        // DOIS TOQUES = RESET
                        // =================================================

                        handler.removeCallbacks(
                            singleTapRunnable
                        )

                        lastTapTime = 0L

                        resetTimer()

                    } else {

                        // =================================================
                        // PRIMEIRO TOQUE
                        // =================================================

                        lastTapTime = now

                        handler.removeCallbacks(
                            singleTapRunnable
                        )

                        handler.postDelayed(
                            singleTapRunnable,
                            DOUBLE_TAP_TIMEOUT
                        )
                    }

                    true
                }

                // =================================================
                // CANCELAMENTO
                // =================================================

                MotionEvent.ACTION_CANCEL -> {

                    handler.removeCallbacks(
                        singleTapRunnable
                    )

                    isDragging = false

                    true
                }

                else -> true
            }
        }

        // ========================================================
        // MOSTRAR OVERLAY
        // ========================================================

        overlayView = root

        windowManager.addView(
            root,
            params
        )

        handler.removeCallbacks(
            updater
        )

        handler.post(updater)

        updateUi()
    }

    // ============================================================
    // TOQUE ÚNICO
    // INICIAR / PAUSAR
    // ============================================================

    private fun toggleTimer() {

        if (running) {

            // ----------------------------------------------------
            // PAUSAR
            // ----------------------------------------------------

            val currentElapsed =
                baseElapsed +
                        (
                            SystemClock.elapsedRealtime() -
                                    startedAt
                            )

            baseElapsed =
                currentElapsed

            running = false

        } else {

            // ----------------------------------------------------
            // INICIAR
            // ----------------------------------------------------

            startedAt =
                SystemClock.elapsedRealtime()

            running = true
        }

        updateUi()
    }

    // ============================================================
    // DOIS TOQUES
    // RESET
    // ============================================================

    private fun resetTimer() {

        running = false

        baseElapsed = 0L

        startedAt =
            SystemClock.elapsedRealtime()

        current = "Início"
        next = "FINAL"

        updateUi()
    }

    // ============================================================
    // ATUALIZAR INTERFACE
    // ============================================================

    private fun updateUi() {

        val elapsed: Long

        if (running) {

            elapsed =
                baseElapsed +
                        (
                            SystemClock.elapsedRealtime() -
                                    startedAt
                            )

        } else {

            elapsed =
                baseElapsed
        }

        timerText?.text =
            formatTime(elapsed)

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

            } catch (_: Exception) {
            }
        }

        overlayView = null

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

    private fun buildNotification(): Notification {

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
                    android.R.drawable.ic_media_play
                )
                .setOngoing(true)
                .build()

        } else {

            @Suppress("DEPRECATION")

            Notification.Builder(this)
                .setContentTitle(
                    "SplitRunner"
                )
                .setContentText(
                    "Overlay ativo"
                )
                .setSmallIcon(
                    android.R.drawable.ic_media_play
                )
                .setOngoing(true)
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

                windowManager.removeView(
                    it
                )

            } catch (_: Exception) {
            }
        }

        overlayView = null

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
