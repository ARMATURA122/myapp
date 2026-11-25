package com.armatura.widgets

import android.accessibilityservice.AccessibilityService
import android.app.KeyguardManager
import android.content.Context
import android.graphics.*
import android.os.PowerManager
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import kotlin.random.Random

class ScreenFx : AccessibilityService() {
    private var view: FxView? = null
    private val handler = Handler(Looper.getMainLooper())
    private val scan = Runnable {
        val found = mutableListOf<Rect>()
        collect(rootInActiveWindow, found, 0)
        view?.setLedges(found)
    }
    private val tick = object : Runnable {
        override fun run() {
            val on = getSystemService(PowerManager::class.java).isInteractive
            if (on) view?.invalidate()
            handler.postDelayed(this, if (on) 33L else 500L)
        }
    }

    private fun collect(n: AccessibilityNodeInfo?, out: MutableList<Rect>, depth: Int) {
        if (n == null || depth > 25 || out.size > 60) return
        val r = Rect()
        n.getBoundsInScreen(r)
        val m = resources.displayMetrics
        if (n.isVisibleToUser && n.isClickable && r.width() in 40..m.widthPixels / 2 &&
            r.height() in 40..m.heightPixels / 5) out.add(r)
        for (i in 0 until n.childCount) collect(n.getChild(i), out, depth + 1)
    }

    override fun onServiceConnected() {
        val v = FxView(this)
        val flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        getSystemService(WindowManager::class.java).addView(v, WindowManager.LayoutParams(-1, -1,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY, flags, PixelFormat.TRANSLUCENT))
        view = v
        handler.post(tick)
        handler.post(scan)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        view?.drop()
        handler.removeCallbacks(scan)
        handler.postDelayed(scan, 500)
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        view?.let { getSystemService(WindowManager::class.java).removeView(it) }
        view = null
        super.onDestroy()
    }
}

private class Dot(var x: Float, var y: Float, val r: Float)
private class Ledge(val rect: Rect, var snow: Float = 0f)

private class FxView(context: Context) : View(context) {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val dots = mutableListOf<Dot>()
    private var ledges = listOf<Ledge>()
    private var floor = 0f
    private val thin = Typeface.create("sans-serif-thin", Typeface.NORMAL)

    fun setLedges(r: List<Rect>) {
        ledges = r.map { n -> Ledge(n, ledges.find { it.rect == n }?.snow ?: 0f) }
    }

    // перелистнули: снег с иконок падает вниз
    fun drop() {
        for (l in ledges) {
            repeat((l.snow / 3).toInt()) {
                dots.add(Dot(l.rect.left + Random.nextFloat() * l.rect.width(), l.rect.top.toFloat(), 5f))
            }
        }
        ledges = emptyList()
    }

    override fun onDraw(c: Canvas) {
        val p = context.getSharedPreferences("style", Context.MODE_PRIVATE)
        val locked = context.getSystemService(KeyguardManager::class.java).isKeyguardLocked
        paint.color = Color.WHITE
        if (p.getBoolean("snow", true) && width > 0) {
            while (dots.size < 90) dots.add(Dot(Random.nextFloat() * width, -Random.nextFloat() * height, 3f + Random.nextFloat() * 5f))
            val it = dots.iterator()
            while (it.hasNext()) {
                val d = it.next()
                val old = d.y
                d.y += d.r * 0.7f
                d.x += Random.nextFloat() * 2f - 1f
                val hit = if (locked) null else ledges.find { l ->
                    d.x >= l.rect.left && d.x <= l.rect.right && old < l.rect.top - l.snow && d.y >= l.rect.top - l.snow
                }
                if (hit != null && hit.snow < 30f) {
                    hit.snow += 2f
                    it.remove()
                } else if (d.y >= height - floor) {
                    floor = (floor + 0.15f).coerceAtMost(90f)
                    it.remove()
                } else c.drawCircle(d.x, d.y, d.r, paint)
            }
            if (!locked) for (l in ledges) if (l.snow > 0) c.drawRoundRect(l.rect.left + 8f,
                l.rect.top - l.snow, l.rect.right - 8f, l.rect.top + 4f, 20f, 20f, paint)
            c.drawRect(0f, height - floor, width.toFloat(), height.toFloat(), paint)
        }
        if (locked && p.getBoolean("lock", false)) {
            val now = LocalDateTime.now()
            paint.color = p.getInt("accent", Color.WHITE)
            paint.textAlign = Paint.Align.CENTER
            paint.typeface = thin
            paint.setShadowLayer(12f, 0f, 0f, Color.BLACK)
            paint.textSize = width * 0.28f
            c.drawText(now.format(DateTimeFormatter.ofPattern("HH")), width / 2f, height * 0.28f, paint)
            c.drawText(now.format(DateTimeFormatter.ofPattern("mm")), width / 2f, height * 0.41f, paint)
            paint.textSize = width * 0.05f
            c.drawText(now.format(DateTimeFormatter.ofPattern("EEE, d MMMM")), width / 2f, height * 0.46f, paint)
            paint.clearShadowLayer()
        }
    }
}
