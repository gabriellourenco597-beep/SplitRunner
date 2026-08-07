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
import android.view.View
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

    private val updater = object : Runnable {
        override fun run() {
            updateUi()
            handler.postDelayed(this, 50)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                baseElapsed = intent.getIntExtra("elapsedMs", 0).toLong()
                running = intent.getBooleanExtra("running", false)
                current = intent.getStringExtra("current") ?: "Início"
                next = intent.getStringExtra("next") ?: "FINAL"
                startedAt = SystemClock.elapsedRealtime()
                showOverlay()
            }
            ACTION_UPDATE -> {
                baseElapsed = intent.getIntExtra("elapsedMs", 0).toLong()
                running = intent.getBooleanExtra("running", false)
                current = intent.getStringExtra("current") ?: current
                next = intent.getStringExtra("next") ?: next
                startedAt = SystemClock.elapsedRealtime()
                updateUi()
            }
            ACTION_STOP -> stopOverlay()
        }
        return START_STICKY
    }

    private fun showOverlay() {
        if (!Settings.canDrawOverlays(this)) return
        if (overlayView != null) return

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(18, 12, 18, 12)
            setBackgroundColor(Color.argb(220, 15, 17, 20))
        }

        timerText = TextView(this).apply {
            text = "00:00.00"
            setTextColor(Color.WHITE)
            textSize = 28f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        }
        currentText = TextView(this).apply { setTextColor(Color.GREEN); textSize = 15f }
        nextText = TextView(this).apply { setTextColor(Color.LTGRAY); textSize = 13f }

        root.addView(timerText)
        root.addView(currentText)
        root.addView(nextText)

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 20
            y = 100
        }

        var downX = 0f
        var downY = 0f
        var startX = 0
        var startY = 0
        root.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downX = event.rawX
                    downY = event.rawY
                    startX = params!!.x
                    startY = params!!.y
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    params!!.x = startX + (event.rawX - downX).toInt()
                    params!!.y = startY + (event.rawY - downY).toInt()
                    windowManager.updateViewLayout(root, params)
                    true
                }
                else -> true
            }
        }

        overlayView = root
        windowManager.addView(root, params)
        handler.removeCallbacks(updater)
        handler.post(updater)
        updateUi()
    }

    private fun updateUi() {
        if (running) {
            val elapsed = baseElapsed + (SystemClock.elapsedRealtime() - startedAt)
            timerText?.text = formatTime(elapsed)
        } else {
            timerText?.text = formatTime(baseElapsed)
        }
        currentText?.text = "▶ $current"
        nextText?.text = "Próximo: $next"
    }

    private fun formatTime(ms: Long): String {
        val minutes = ms / 60000
        val seconds = (ms / 1000) % 60
        val centis = (ms % 1000) / 10
        return String.format("%02d:%02d.%02d", minutes, seconds, centis)
    }

    private fun stopOverlay() {
        handler.removeCallbacks(updater)
        overlayView?.let {
            try { windowManager.removeView(it) } catch (_: Exception) {}
        }
        overlayView = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "SplitRunner Overlay", NotificationManager.IMPORTANCE_LOW)
            )
        }
    }

    private fun buildNotification(): Notification {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("SplitRunner")
                .setContentText("Overlay ativo")
                .setSmallIcon(android.R.drawable.ic_media_play)
                .setOngoing(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("SplitRunner")
                .setContentText("Overlay ativo")
                .setSmallIcon(android.R.drawable.ic_media_play)
                .setOngoing(true)
                .build()
        }
    }

    override fun onDestroy() {
        handler.removeCallbacks(updater)
        overlayView?.let { try { windowManager.removeView(it) } catch (_: Exception) {} }
        overlayView = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
