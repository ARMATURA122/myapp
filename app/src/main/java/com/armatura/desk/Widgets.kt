package com.armatura.desk

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.view.View

/** Кольцо с процентом использования ОЗУ. */
class RamRing(ctx: Context) : View(ctx) {
    var accent = 0xFFB388FF.toInt()
    private var pct = 0
    private var used = 0.0
    private var total = 0.0
    private val p = Paint(Paint.ANTI_ALIAS_FLAG)

    init {
        p.strokeCap = Paint.Cap.ROUND
    }

    fun set(percent: Int, usedGb: Double, totalGb: Double) {
        pct = percent.coerceIn(0, 100)
        used = usedGb
        total = totalGb
        invalidate()
    }

    override fun onDraw(c: Canvas) {
        val d = resources.displayMetrics.density
        val cx = width / 2f
        val cy = height / 2f
        val r = minOf(width, height) / 2f - 10f * d
        p.style = Paint.Style.STROKE
        p.strokeWidth = 7f * d
        p.color = 0x33FFFFFF
        c.drawCircle(cx, cy, r, p)
        p.color = accent
        c.drawArc(RectF(cx - r, cy - r, cx + r, cy + r), -90f, 360f * pct / 100f, false, p)
        p.style = Paint.Style.FILL
        p.color = 0xFFFFFFFF.toInt()
        p.textAlign = Paint.Align.CENTER
        p.textSize = 20f * d
        p.isFakeBoldText = true
        c.drawText("$pct%", cx, cy + 2f * d, p)
        p.isFakeBoldText = false
        p.textSize = 11f * d
        p.color = 0xCCFFFFFF.toInt()
        c.drawText("RAM", cx, cy - 18f * d, p)
        c.drawText(String.format("%.1f/%.1f", used, total), cx, cy + 20f * d, p)
    }
}
