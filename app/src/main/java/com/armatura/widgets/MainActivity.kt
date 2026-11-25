package com.armatura.widgets

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.widget.*

class MainActivity : Activity() {
    override fun onCreate(b: Bundle?) {
        super.onCreate(b)
        val p = prefs(this)
        val dp = resources.displayMetrics.density
        fun d(x: Int) = (x * dp).toInt()
        val root = LinearLayout(this)
        root.orientation = LinearLayout.VERTICAL
        root.setPadding(d(16), d(28), d(16), d(24))
        root.setBackgroundColor(0xFF0B0B14.toInt())
        fun tv(t: String): TextView {
            val v = TextView(this)
            v.text = t; v.setTextColor(Color.WHITE); v.textSize = 16f
            v.setPadding(0, d(16), 0, d(6))
            return v
        }
        val pv = TextView(this)
        pv.text = "12:34"; pv.gravity = Gravity.CENTER
        pv.setBackgroundColor(0xFF2A2A40.toInt())
        fun refresh() {
            pv.typeface = Typeface.create(FONTS[p.getInt("font", 0)], Typeface.NORMAL)
            pv.setTextColor(p.getInt("color", COLORS[0]))
            pv.textSize = p.getInt("size", 60).toFloat()
            updateAll(this)
        }
        root.addView(pv)
        root.addView(tv("Шрифт"))
        val fr = LinearLayout(this)
        NAMES.forEachIndexed { i, n ->
            val bt = Button(this)
            bt.text = n
            bt.typeface = Typeface.create(FONTS[i], Typeface.NORMAL)
            bt.setOnClickListener { p.edit().putInt("font", i).apply(); refresh() }
            fr.addView(bt)
        }
        val fs = HorizontalScrollView(this)
        fs.addView(fr)
        root.addView(fs)
        root.addView(tv("Цвет"))
        val cr = LinearLayout(this)
        COLORS.forEach { c ->
            val v = View(this)
            val g = GradientDrawable()
            g.shape = GradientDrawable.OVAL
            g.setColor(c)
            g.setStroke(d(2), Color.GRAY)
            v.background = g
            val lp = LinearLayout.LayoutParams(d(44), d(44))
            lp.setMargins(0, 0, d(10), 0)
            v.layoutParams = lp
            v.setOnClickListener { p.edit().putInt("color", c).apply(); refresh() }
            cr.addView(v)
        }
        val cs = HorizontalScrollView(this)
        cs.addView(cr)
        root.addView(cs)
        root.addView(tv("Размер часов"))
        val sb = SeekBar(this)
        sb.max = 60
        sb.progress = p.getInt("size", 60) - 30
        sb.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(s: SeekBar?, v: Int, u: Boolean) {
                p.edit().putInt("size", 30 + v).apply(); refresh()
            }
            override fun onStartTrackingTouch(s: SeekBar?) {}
            override fun onStopTrackingTouch(s: SeekBar?) {}
        })
        root.addView(sb)
        fun pin(cls: Class<*>) {
            val m = AppWidgetManager.getInstance(this)
            if (m.isRequestPinAppWidgetSupported) m.requestPinAppWidget(ComponentName(this, cls), null, null)
            else Toast.makeText(this, "Долгий тап на рабочем столе, Виджеты", Toast.LENGTH_LONG).show()
        }
        val b1 = Button(this)
        b1.text = "Добавить часы на экран"
        b1.setOnClickListener { pin(ClockWidget::class.java) }
        val b2 = Button(this)
        b2.text = "Добавить батарею на экран"
        b2.setOnClickListener { pin(BatteryWidget::class.java) }
        root.addView(b1)
        root.addView(b2)
        val sv = ScrollView(this)
        sv.addView(root)
        setContentView(sv)
        refresh()
    }
}
