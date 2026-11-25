package com.armatura.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.os.BatteryManager
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews

val FONTS = listOf("sans-serif", "sans-serif-thin", "sans-serif-light", "sans-serif-medium", "sans-serif-black", "sans-serif-condensed", "serif", "monospace", "cursive", "casual")
val NAMES = listOf("Обычный", "Тонкий", "Лёгкий", "Средний", "Жирный", "Узкий", "С засечками", "Моно", "Рукописный", "Casual")
val COLORS = intArrayOf(0xFFFFFFFF.toInt(), 0xFF00E5FF.toInt(), 0xFFFF3DF2.toInt(), 0xFF7DFF3A.toInt(), 0xFFFFD000.toInt(), 0xFFFF5252.toInt(), 0xFFB388FF.toInt(), 0xFF111111.toInt())
val IDS = intArrayOf(R.id.t0, R.id.t1, R.id.t2, R.id.t3, R.id.t4, R.id.t5, R.id.t6, R.id.t7, R.id.t8, R.id.t9)
val BAT = listOf("android.intent.action.ACTION_POWER_CONNECTED", "android.intent.action.ACTION_POWER_DISCONNECTED", "android.intent.action.BATTERY_LOW", "android.intent.action.BATTERY_OKAY")

fun prefs(c: Context) = c.getSharedPreferences("w", 0)

fun updateAll(c: Context) {
    val m = AppWidgetManager.getInstance(c)
    for (id in m.getAppWidgetIds(ComponentName(c, ClockWidget::class.java))) m.updateAppWidget(id, clockViews(c))
    for (id in m.getAppWidgetIds(ComponentName(c, BatteryWidget::class.java))) m.updateAppWidget(id, batteryViews(c))
}

fun clockViews(c: Context): RemoteViews {
    val p = prefs(c)
    val f = p.getInt("font", 0)
    val col = p.getInt("color", COLORS[0])
    val sz = p.getInt("size", 60)
    val rv = RemoteViews(c.packageName, R.layout.w_clock)
    IDS.forEachIndexed { i, id ->
        rv.setViewVisibility(id, if (i == f) View.VISIBLE else View.GONE)
        rv.setTextColor(id, col)
        rv.setTextViewTextSize(id, TypedValue.COMPLEX_UNIT_SP, sz.toFloat())
    }
    rv.setTextColor(R.id.d, col)
    return rv
}

fun batteryViews(c: Context): RemoteViews {
    val p = prefs(c)
    val col = p.getInt("color", COLORS[0])
    val f = p.getInt("font", 0)
    val lvl = (c.getSystemService(Context.BATTERY_SERVICE) as BatteryManager).getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
    val s = 300
    val bmp = Bitmap.createBitmap(s, s, Bitmap.Config.ARGB_8888)
    val cv = Canvas(bmp)
    val pt = Paint(Paint.ANTI_ALIAS_FLAG)
    pt.style = Paint.Style.STROKE
    pt.strokeWidth = 26f
    pt.strokeCap = Paint.Cap.ROUND
    val r = RectF(30f, 30f, s - 30f, s - 30f)
    pt.color = (col and 0x00FFFFFF) or 0x44000000
    cv.drawArc(r, 0f, 360f, false, pt)
    pt.color = col
    cv.drawArc(r, -90f, 360f * lvl / 100f, false, pt)
    pt.style = Paint.Style.FILL
    pt.textAlign = Paint.Align.CENTER
    pt.textSize = 90f
    pt.typeface = Typeface.create(FONTS[f], Typeface.NORMAL)
    cv.drawText("$lvl%", s / 2f, s / 2f + 32f, pt)
    val rv = RemoteViews(c.packageName, R.layout.w_battery)
    rv.setImageViewBitmap(R.id.img, bmp)
    return rv
}

class ClockWidget : AppWidgetProvider() {
    override fun onUpdate(c: Context, m: AppWidgetManager, ids: IntArray) {
        for (i in ids) m.updateAppWidget(i, clockViews(c))
    }
}

class BatteryWidget : AppWidgetProvider() {
    override fun onUpdate(c: Context, m: AppWidgetManager, ids: IntArray) {
        for (i in ids) m.updateAppWidget(i, batteryViews(c))
    }
    override fun onReceive(c: Context, i: Intent) {
        super.onReceive(c, i)
        if (i.action in BAT) updateAll(c)
    }
}
