package com.armatura.stalker

import android.app.Activity
import android.app.AlertDialog
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.LauncherActivityInfo
import android.content.pm.LauncherApps
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Process
import android.view.Gravity
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast

class MainActivity : Activity() {

    private class Part(val key: String, val title: String, val year: String)

    private val parts = listOf(
        Part("soc", "Тень Чернобыля", "2007"),
        Part("cs", "Чистое небо", "2008"),
        Part("cop", "Зов Припяти", "2010")
    )
    private lateinit var prefs: SharedPreferences
    private val subs = HashMap<String, TextView>()

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        prefs = getSharedPreferences("stalker", Context.MODE_PRIVATE)

        val root = LinearLayout(this)
        root.orientation = LinearLayout.VERTICAL
        root.gravity = Gravity.CENTER_HORIZONTAL
        root.setPadding(dp(24), dp(48), dp(24), dp(24))
        root.background = GradientDrawable(
            GradientDrawable.Orientation.TOP_BOTTOM,
            intArrayOf(0xFF2B2A1E.toInt(), 0xFF0B0B08.toInt())
        )

        val title = TextView(this)
        title.text = "S.T.A.L.K.E.R."
        title.setTextColor(0xFFE0A030.toInt())
        title.textSize = 34f
        title.typeface = Typeface.DEFAULT_BOLD
        title.letterSpacing = 0.15f
        title.gravity = Gravity.CENTER
        root.addView(title)

        val sub = TextView(this)
        sub.text = "ТРИЛОГИЯ"
        sub.setTextColor(0xFFA89868.toInt())
        sub.textSize = 14f
        sub.letterSpacing = 0.5f
        sub.gravity = Gravity.CENTER
        sub.setPadding(0, dp(4), 0, dp(32))
        root.addView(sub)

        for (p in parts) {
            root.addView(makeButton(p), buttonParams())
        }

        val hint = TextView(this)
        hint.text = "Первый раз: нажми на часть и выбери установленное приложение, которое её запускает (порт игры или Winlator). Выбор запоминается. Чтобы сменить, зажми кнопку."
        hint.setTextColor(0xFF8C8566.toInt())
        hint.textSize = 12f
        hint.gravity = Gravity.CENTER
        hint.setPadding(0, dp(24), 0, 0)
        root.addView(hint)

        setContentView(root)
        refresh()
    }

    private fun buttonParams(): LinearLayout.LayoutParams {
        val lp = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(104))
        lp.bottomMargin = dp(16)
        return lp
    }

    private fun makeButton(p: Part): LinearLayout {
        val b = LinearLayout(this)
        b.orientation = LinearLayout.VERTICAL
        b.gravity = Gravity.CENTER
        val bg = GradientDrawable()
        bg.setColor(0xFF1A1A12.toInt())
        bg.setStroke(dp(2), 0xFFE0A030.toInt())
        bg.cornerRadius = dp(10).toFloat()
        b.background = bg

        val t = TextView(this)
        t.text = p.title.uppercase() + "  (" + p.year + ")"
        t.setTextColor(0xFFE0A030.toInt())
        t.textSize = 20f
        t.typeface = Typeface.DEFAULT_BOLD
        t.gravity = Gravity.CENTER
        b.addView(t)

        val s = TextView(this)
        s.setTextColor(0xFFA89868.toInt())
        s.textSize = 12f
        s.gravity = Gravity.CENTER
        s.setPadding(dp(8), dp(6), dp(8), 0)
        b.addView(s)
        subs[p.key] = s

        b.setOnClickListener { launch(p) }
        b.setOnLongClickListener {
            choose(p)
            true
        }
        return b
    }

    private fun refresh() {
        for (p in parts) {
            val name = prefs.getString("n_" + p.key, null)
            val tv = subs[p.key] ?: continue
            tv.text = if (name == null) "не выбрано: нажми, чтобы выбрать приложение" else "Запуск: $name"
        }
    }

    private fun launch(p: Part) {
        val saved = prefs.getString("c_" + p.key, null)
        if (saved == null) {
            choose(p)
            return
        }
        val comp = ComponentName.unflattenFromString(saved)
        if (comp == null) {
            choose(p)
            return
        }
        try {
            val la = getSystemService(Context.LAUNCHER_APPS_SERVICE) as LauncherApps
            la.startMainActivity(comp, Process.myUserHandle(), null, null)
        } catch (e: Exception) {
            Toast.makeText(this, "Приложение не найдено. Выбери заново.", Toast.LENGTH_LONG).show()
            choose(p)
        }
    }

    private fun looksLikeStalker(a: LauncherActivityInfo): Boolean {
        val t = (a.label.toString() + " " + a.applicationInfo.packageName).lowercase()
        val words = listOf("stalker", "сталкер", "сталк", "xray", "x-ray", "winlator")
        return words.any { t.contains(it) }
    }

    private fun choose(p: Part) {
        val la = getSystemService(Context.LAUNCHER_APPS_SERVICE) as LauncherApps
        val list = la.getActivityList(null, Process.myUserHandle())
            .filter { it.applicationInfo.packageName != packageName }
            .sortedWith(compareBy<LauncherActivityInfo>({ !looksLikeStalker(it) }, { it.label.toString().lowercase() }))
        val labels = list.map { it.label.toString() }.toTypedArray()
        AlertDialog.Builder(this)
            .setTitle("Что запускать: " + p.title)
            .setItems(labels) { _, i ->
                prefs.edit()
                    .putString("c_" + p.key, list[i].componentName.flattenToString())
                    .putString("n_" + p.key, labels[i])
                    .apply()
                refresh()
            }
            .setNegativeButton("Отмена", null)
            .show()
    }
}
