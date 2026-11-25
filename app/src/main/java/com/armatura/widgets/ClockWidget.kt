package com.armatura.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

// превращает "Привет {time}" в формат TextClock
fun clockFormat(code: String): String =
    code.split("{time}").joinToString("HH:mm") {
        if (it.isEmpty()) "" else "'" + it.replace("'", "’") + "'"
    }

class ClockWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val p = context.getSharedPreferences("style", Context.MODE_PRIVATE)
        val format = clockFormat(p.getString("code", "{time}")!!)
        val v = RemoteViews(context.packageName, R.layout.clock)
        v.setCharSequence(R.id.clock, "setFormat12Hour", format)
        v.setCharSequence(R.id.clock, "setFormat24Hour", format)
        v.setTextColor(R.id.clock, p.getInt("accent", -1))
        v.setInt(R.id.clock, "setBackgroundColor", p.getInt("bg", 0xFF121E3A.toInt()))
        manager.updateAppWidget(ids, v)
    }
}
