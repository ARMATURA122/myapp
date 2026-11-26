package com.armatura.desk

import android.accessibilityservice.AccessibilityService
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.BatteryManager
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.TextView

/** Рисует поверх игр: RAM/батарею и нажатые клавиши клавиатуры. */
class DeskService : AccessibilityService() {

    private val prefs by lazy { getSharedPreferences("desk", Context.MODE_PRIVATE) }
    private var wm: WindowManager? = null
    private var statsView: TextView? = null
    private var keysView: TextView? = null
    private val held = LinkedHashSet<Int>()
    private val handler = Handler(Looper.getMainLooper())
    private val tick = object : Runnable {
        override fun run() {
            update()
            handler.postDelayed(this, 1000)
        }
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()

    override fun onServiceConnected() {
        super.onServiceConnected()
        wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        handler.post(tick)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // события окон не нужны
    }

    override fun onInterrupt() {
    }

    override fun onKeyEvent(event: KeyEvent): Boolean {
        if (prefs.getBoolean("ov_keys", false)) {
            if (event.action == KeyEvent.ACTION_DOWN) {
                held.add(event.keyCode)
            } else if (event.action == KeyEvent.ACTION_UP) {
                held.remove(event.keyCode)
            }
            refreshKeys()
        }
        return false
    }

    private fun makeLabel(): TextView {
        val t = TextView(this)
        t.setTextColor(Color.WHITE)
        t.textSize = 14f
        t.setPadding(dp(12), dp(6), dp(12), dp(6))
        val g = GradientDrawable()
        g.setColor(0xCC1A0F2E.toInt())
        g.cornerRadius = dp(10).toFloat()
        g.setStroke(dp(1), 0x66B388FF)
        t.background = g
        return t
    }

    private fun addOverlay(v: View, gravity: Int, x: Int, y: Int) {
        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        )
        lp.gravity = gravity
        lp.x = x
        lp.y = y
        wm?.addView(v, lp)
    }

    private fun removeView(v: View?) {
        if (v == null) return
        try {
            wm?.removeView(v)
        } catch (e: Exception) {
            // уже убран
        }
    }

    private fun update() {
        val show = prefs.getBoolean("ov_stats", false)
        if (show) {
            if (statsView == null) {
                val t = makeLabel()
                statsView = t
                addOverlay(t, Gravity.TOP or Gravity.START, dp(12), dp(40))
            }
            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val mi = ActivityManager.MemoryInfo()
            am.getMemoryInfo(mi)
            val total = mi.totalMem.toDouble()
            val used = total - mi.availMem
            val bi: Intent? = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            val lvl = bi?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale = bi?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
            val bat = if (lvl >= 0 && scale > 0) lvl * 100 / scale else 0
            statsView?.text = String.format("RAM %.1f/%.1f ГБ   BAT %d%%", used / 1e9, total / 1e9, bat)
        } else if (statsView != null) {
            removeView(statsView)
            statsView = null
        }
        if (!prefs.getBoolean("ov_keys", false) && keysView != null) {
            removeView(keysView)
            keysView = null
            held.clear()
        }
    }

    private fun refreshKeys() {
        if (keysView == null) {
            val t = makeLabel()
            t.textSize = 18f
            keysView = t
            addOverlay(t, Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL, 0, dp(110))
        }
        val names = held.map { KeyEvent.keyCodeToString(it).removePrefix("KEYCODE_") }
        keysView?.text = names.joinToString("   ")
        keysView?.visibility = if (held.isEmpty()) View.GONE else View.VISIBLE
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        removeView(statsView)
        removeView(keysView)
        statsView = null
        keysView = null
        super.onDestroy()
    }
}
