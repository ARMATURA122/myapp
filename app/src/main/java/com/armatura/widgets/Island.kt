package com.armatura.widgets

import android.content.ComponentName
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.media.MediaMetadata
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.view.Gravity
import android.view.WindowManager
import android.widget.TextView

class Island : NotificationListenerService() {
    private val handler = Handler(Looper.getMainLooper())
    private var view: TextView? = null
    private val tick = object : Runnable {
        override fun run() {
            update()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onListenerConnected() {
        handler.removeCallbacks(tick)
        handler.post(tick)
    }

    override fun onListenerDisconnected() {
        stop()
    }

    override fun onDestroy() {
        stop()
        super.onDestroy()
    }

    private fun stop() {
        handler.removeCallbacks(tick)
        hide()
    }

    private fun hide() {
        view?.let { getSystemService(WindowManager::class.java).removeView(it) }
        view = null
    }

    private fun update() {
        val p = getSharedPreferences("style", MODE_PRIVATE)
        if (!p.getBoolean("island", false) || !Settings.canDrawOverlays(this)) return hide()
        val media = getSystemService(MediaSessionManager::class.java)
            .getActiveSessions(ComponentName(this, Island::class.java)).firstOrNull() ?: return hide()
        val title = media.metadata?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: return hide()
        val v = view ?: TextView(this).also {
            it.setPadding(40, 18, 40, 18)
            it.maxLines = 1
            val params = WindowManager.LayoutParams(-2, -2,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE, PixelFormat.TRANSLUCENT)
            params.gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            params.y = 10
            getSystemService(WindowManager::class.java).addView(it, params)
            view = it
        }
        val playing = media.playbackState?.state == PlaybackState.STATE_PLAYING
        v.text = (if (playing) "♫ " else "❚❚ ") + title.take(24)
        v.setTextColor(p.getInt("accent", -1))
        v.background = GradientDrawable().apply {
            setColor(p.getInt("bg", -16777216))
            cornerRadius = 100f
        }
        v.setOnClickListener {
            if (playing) media.transportControls.pause() else media.transportControls.play()
        }
    }
}
