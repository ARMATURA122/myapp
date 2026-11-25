package com.armatura.iconstyle

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.view.MotionEvent
import android.view.View
import android.widget.HorizontalScrollView

/** Горизонтальный пейджер с примагничиванием к страницам. */
class Pager(ctx: Context) : HorizontalScrollView(ctx) {
    var page = 0
    var pageW = 1
    var pageCount = 1
    var onPage: ((Int) -> Unit)? = null
    private var startScroll = 0

    init {
        overScrollMode = OVER_SCROLL_NEVER
        isHorizontalScrollBarEnabled = false
    }

    override fun onInterceptTouchEvent(ev: MotionEvent): Boolean {
        if (ev.actionMasked == MotionEvent.ACTION_DOWN) startScroll = scrollX
        return super.onInterceptTouchEvent(ev)
    }

    override fun onTouchEvent(ev: MotionEvent): Boolean {
        val r = super.onTouchEvent(ev)
        if (ev.actionMasked == MotionEvent.ACTION_UP || ev.actionMasked == MotionEvent.ACTION_CANCEL) {
            val dx = scrollX - startScroll
            var t = page
            if (dx > pageW / 6) {
                t = page + 1
            } else if (dx < -pageW / 6) {
                t = page - 1
            }
            goTo(t)
        }
        return r
    }

    fun goTo(p: Int) {
        page = p.coerceIn(0, pageCount - 1)
        post { smoothScrollTo(page * pageW, 0) }
        onPage?.invoke(page)
    }
}

/** Виджет заряда: кольцо и проценты. */
class BatteryCard(ctx: Context) : View(ctx) {
    private var level = 100
    private var charging = false
    private val ring = Paint(Paint.ANTI_ALIAS_FLAG)
    private val txt = Paint(Paint.ANTI_ALIAS_FLAG)

    init {
        ring.style = Paint.Style.STROKE
        ring.strokeCap = Paint.Cap.ROUND
    }

    fun set(lvl: Int, chg: Boolean) {
        level = lvl.coerceIn(0, 100)
        charging = chg
        invalidate()
    }

    override fun onDraw(c: Canvas) {
        val d = resources.displayMetrics.density
        val cy = height / 2f
        val rad = 26f * d
        val cx = 28f * d + rad
        ring.strokeWidth = 6f * d
        ring.color = 0x33FFFFFF
        c.drawCircle(cx, cy, rad, ring)
        ring.color = 0xFFFFFFFF.toInt()
        c.drawArc(RectF(cx - rad, cy - rad, cx + rad, cy + rad), -90f, 360f * level / 100f, false, ring)
        txt.color = 0xFFFFFFFF.toInt()
        txt.textSize = 28f * d
        txt.isFakeBoldText = true
        c.drawText("$level%", cx + rad + 24f * d, cy + 10f * d, txt)
        txt.isFakeBoldText = false
        txt.color = 0xAAFFFFFF.toInt()
        txt.textSize = 13f * d
        c.drawText(if (charging) "Заряжается" else "Батарея", cx + rad + 24f * d, cy - 22f * d, txt)
    }
}
