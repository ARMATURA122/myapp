package com.armatura.stalker

import android.app.Activity
import android.app.AlertDialog
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.LauncherActivityInfo
import android.content.pm.LauncherApps
import android.graphics.BitmapFactory
import android.graphics.Outline
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Bundle
import android.os.Process
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.ViewOutlineProvider
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

class MainActivity : Activity() {

    private class Part(val key: String, val title: String, val year: String, val appId: Int)

    private val parts = listOf(
        Part("soc", "Тень Чернобыля", "2007", 4500),
        Part("cs", "Чистое небо", "2008", 20510),
        Part("cop", "Зов Припяти", "2010", 41700)
    )
    private lateinit var prefs: SharedPreferences
    private val subs = HashMap<String, TextView>()

    private val MATCH = ViewGroup.LayoutParams.MATCH_PARENT
    private val WRAP = ViewGroup.LayoutParams.WRAP_CONTENT

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        prefs = getSharedPreferences("stalker", Context.MODE_PRIVATE)

        val col = LinearLayout(this)
        col.orientation = LinearLayout.VERTICAL
        col.setPadding(dp(20), dp(52), dp(20), dp(28))

        val title = TextView(this)
        title.text = "S.T.A.L.K.E.R."
        title.setTextColor(0xFFEDE7FF.toInt())
        title.textSize = 30f
        title.typeface = Typeface.DEFAULT_BOLD
        title.letterSpacing = 0.12f
        title.gravity = Gravity.CENTER
        col.addView(title, LinearLayout.LayoutParams(MATCH, WRAP))

        val sub = TextView(this)
        sub.text = "ТРИЛОГИЯ"
        sub.setTextColor(0xFFB69CFF.toInt())
        sub.textSize = 13f
        sub.letterSpacing = 0.5f
        sub.gravity = Gravity.CENTER
        sub.setPadding(0, dp(4), 0, dp(24))
        col.addView(sub, LinearLayout.LayoutParams(MATCH, WRAP))

        for (p in parts) {
            val lp = LinearLayout.LayoutParams(MATCH, dp(170))
            lp.bottomMargin = dp(16)
            col.addView(makeCard(p), lp)
        }

        val hint = TextView(this)
        hint.text = "Нажми на карточку и выбери установленное приложение, которое запускает эту часть. Выбор запоминается, сменить можно долгим нажатием. Кнопка «Трейлер» открывает страницу игры в Steam."
        hint.setTextColor(0xFF8B7DB0.toInt())
        hint.textSize = 12f
        hint.gravity = Gravity.CENTER
        hint.setPadding(dp(4), dp(8), dp(4), 0)
        col.addView(hint, LinearLayout.LayoutParams(MATCH, WRAP))

        val scroll = ScrollView(this)
        scroll.isVerticalScrollBarEnabled = false
        scroll.background = GradientDrawable(
            GradientDrawable.Orientation.TOP_BOTTOM,
            intArrayOf(0xFF211238.toInt(), 0xFF0B0714.toInt())
        )
        scroll.addView(col, FrameLayout.LayoutParams(MATCH, WRAP))
        setContentView(scroll)
        refresh()
    }

    private fun makeCard(p: Part): View {
        val f = FrameLayout(this)
        f.background = GradientDrawable().apply { setColor(0xFF2A1B4A.toInt()) }
        f.outlineProvider = object : ViewOutlineProvider() {
            override fun getOutline(view: View, outline: Outline) {
                outline.setRoundRect(0, 0, view.width, view.height, dp(22).toFloat())
            }
        }
        f.clipToOutline = true

        val iv = ImageView(this)
        iv.scaleType = ImageView.ScaleType.CENTER_CROP
        f.addView(iv, FrameLayout.LayoutParams(MATCH, MATCH))
        loadArt(p, iv)

        val shade = View(this)
        shade.background = GradientDrawable(
            GradientDrawable.Orientation.TOP_BOTTOM,
            intArrayOf(0x22120A22, 0xE6120A22.toInt())
        )
        f.addView(shade, FrameLayout.LayoutParams(MATCH, MATCH))

        val text = LinearLayout(this)
        text.orientation = LinearLayout.VERTICAL
        text.gravity = Gravity.BOTTOM
        text.setPadding(dp(18), dp(12), dp(18), dp(16))
        val t = TextView(this)
        t.text = p.title + "  (" + p.year + ")"
        t.setTextColor(0xFFEDE7FF.toInt())
        t.textSize = 20f
        t.typeface = Typeface.DEFAULT_BOLD
        text.addView(t)
        val s = TextView(this)
        s.setTextColor(0xFFC9B8F5.toInt())
        s.textSize = 12f
        s.setPadding(0, dp(4), 0, 0)
        text.addView(s)
        subs[p.key] = s
        f.addView(text, FrameLayout.LayoutParams(MATCH, MATCH))

        val tr = TextView(this)
        tr.text = "Трейлер"
        tr.setTextColor(0xFFEDE7FF.toInt())
        tr.textSize = 12f
        tr.setPadding(dp(14), dp(8), dp(14), dp(8))
        tr.background = GradientDrawable().apply {
            setColor(0x88B69CFF.toInt())
            cornerRadius = dp(20).toFloat()
        }
        val trp = FrameLayout.LayoutParams(WRAP, WRAP, Gravity.TOP or Gravity.END)
        trp.setMargins(0, dp(12), dp(12), 0)
        tr.setOnClickListener { openTrailer(p) }
        f.addView(tr, trp)

        f.setOnClickListener { launch(p) }
        f.setOnLongClickListener {
            choose(p)
            true
        }
        return f
    }

    private fun loadArt(p: Part, iv: ImageView) {
        val cache = File(cacheDir, "art_" + p.appId + ".jpg")
        if (cache.exists()) {
            iv.setImageBitmap(BitmapFactory.decodeFile(cache.absolutePath))
            return
        }
        Thread {
            val id = p.appId
            val urls = listOf(
                "https://cdn.akamai.steamstatic.com/steam/apps/$id/library_hero.jpg",
                "https://cdn.akamai.steamstatic.com/steam/apps/$id/header.jpg",
                "https://cdn.cloudflare.steamstatic.com/steam/apps/$id/header.jpg"
            )
            for (u in urls) {
                try {
                    val c = URL(u).openConnection() as HttpURLConnection
                    c.connectTimeout = 8000
                    c.readTimeout = 8000
                    if (c.responseCode != 200) {
                        c.disconnect()
                        continue
                    }
                    val bytes = c.inputStream.use { it.readBytes() }
                    c.disconnect()
                    val bmp = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: continue
                    cache.writeBytes(bytes)
                    runOnUiThread { iv.setImageBitmap(bmp) }
                    return@Thread
                } catch (e: Exception) {
                    // пробуем следующий адрес
                }
            }
        }.start()
    }

    private fun openTrailer(p: Part) {
        try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://store.steampowered.com/app/" + p.appId + "/")))
        } catch (e: Exception) {
            Toast.makeText(this, "Не удалось открыть страницу Steam", Toast.LENGTH_SHORT).show()
        }
    }

    private fun refresh() {
        for (p in parts) {
            val name = prefs.getString("n_" + p.key, null)
            val tv = subs[p.key] ?: continue
            tv.text = if (name == null) "Нажми, чтобы выбрать приложение" else "Запуск: $name"
        }
    }

    private fun launch(p: Part) {
        val saved = prefs.getString("c_" + p.key, null)
        val comp = if (saved == null) null else ComponentName.unflattenFromString(saved)
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
