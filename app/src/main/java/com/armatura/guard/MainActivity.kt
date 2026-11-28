package com.armatura.guard

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import android.widget.*
import java.io.File
import java.security.MessageDigest

class F(val f: File, val size: Long, val mod: Long)

class MainActivity : Activity() {
    private lateinit var info: TextView
    private lateinit var box: LinearLayout
    private lateinit var go: Button
    private val res = LinkedHashMap<String, MutableList<F>>()
    private val days = 180
    private val bad = setOf("apk", "apks", "xapk", "dex", "jar", "sh", "exe", "bat", "scr", "msi", "vbs")
    private val dbl = Regex(".*\\.(pdf|jpg|jpeg|png|doc|docx|xls|xlsx|mp3|mp4|txt|zip)\\.(apk|exe|bat|scr|sh|vbs)", RegexOption.IGNORE_CASE)
    private val rootDir: File = Environment.getExternalStorageDirectory()

    private fun toast(t: String) = Toast.makeText(this, t, Toast.LENGTH_SHORT).show()

    private fun button(t: String): Button {
        val b = Button(this)
        b.text = t; b.setTextColor(Color.WHITE); b.isAllCaps = false
        val g = GradientDrawable()
        g.cornerRadius = 36f; g.setColor(0xFF3A1A6E.toInt()); g.setStroke(2, 0xFF8E5BFF.toInt())
        b.background = g
        return b
    }

    override fun onCreate(s: Bundle?) {
        super.onCreate(s)
        val d = resources.displayMetrics.density
        val col = LinearLayout(this)
        col.orientation = LinearLayout.VERTICAL
        col.setPadding((16 * d).toInt(), (48 * d).toInt(), (16 * d).toInt(), (24 * d).toInt())
        col.setBackgroundColor(0xFF0B0614.toInt())
        val h = TextView(this)
        h.text = "Guard"; h.textSize = 30f; h.setTextColor(Color.WHITE)
        info = TextView(this)
        info.text = "Проверка всех файлов телефона: старые, большие, дубликаты, подозрительные."
        info.setTextColor(0xFFCCCCDD.toInt()); info.setPadding(0, (8 * d).toInt(), 0, (12 * d).toInt())
        go = button("Сканировать телефон")
        go.setOnClickListener { start() }
        box = LinearLayout(this)
        box.orientation = LinearLayout.VERTICAL
        col.addView(h); col.addView(info); col.addView(go); col.addView(box)
        val sv = ScrollView(this)
        sv.addView(col)
        setContentView(sv)
    }

    private fun start() {
        if (!Environment.isExternalStorageManager()) {
            toast("Разреши доступ ко всем файлам и вернись")
            startActivity(Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, Uri.parse("package:$packageName")))
            return
        }
        scan()
    }

    private fun hash(f: File): String = try {
        val md = MessageDigest.getInstance("MD5")
        f.inputStream().use { val b = ByteArray(262144); val r = it.read(b); if (r > 0) md.update(b, 0, r) }
        md.digest().joinToString("") { "%02x".format(it) }
    } catch (e: Exception) { f.path }

    private fun scan() {
        go.isEnabled = false
        box.removeAllViews()
        res.clear()
        Thread {
            val now = System.currentTimeMillis()
            val sus = ArrayList<F>(); val old = ArrayList<F>(); val big = ArrayList<F>()
            val tmp = ArrayList<F>(); val emp = ArrayList<F>(); val dup = ArrayList<F>()
            val sizes = HashMap<Long, MutableList<File>>()
            var n = 0
            rootDir.walkTopDown().onEnter { !(it.parentFile == rootDir && it.name == "Android") }.forEach { f ->
                if (!f.isFile) return@forEach
                n++
                if (n % 200 == 0) runOnUiThread { info.text = "Проверено файлов: $n" }
                val s = f.length(); val m = f.lastModified(); val ext = f.extension.lowercase(); val x = F(f, s, m)
                if (ext in bad || dbl.matches(f.name)) sus.add(x)
                if (s == 0L) emp.add(x)
                if (s > 100L * 1024 * 1024) big.add(x)
                if (now - m > days * 86400000L) old.add(x)
                if (ext in setOf("tmp", "log", "bak", "temp") || f.name.endsWith("~") || f.path.contains("/.thumbnails/")) tmp.add(x)
                if (s > 1024 * 1024) sizes.getOrPut(s) { ArrayList() }.add(f)
            }
            runOnUiThread { info.text = "Ищу дубликаты..." }
            for ((s, l) in sizes) if (l.size > 1) {
                val g = HashMap<String, MutableList<File>>()
                for (f in l) g.getOrPut(hash(f)) { ArrayList() }.add(f)
                for (x in g.values) if (x.size > 1) x.sortedBy { it.lastModified() }.drop(1).forEach { dup.add(F(it, s, it.lastModified())) }
            }
            runOnUiThread {
                res["Подозрительные (APK, скрипты, exe)"] = sus
                res["Старые файлы (больше $days дней)"] = old
                res["Большие файлы (больше 100 МБ)"] = big
                res["Вероятные дубликаты"] = dup
                res["Временные и мусорные"] = tmp
                res["Пустые файлы"] = emp
                info.text = "Готово. Проверено файлов: $n. Нажми на категорию, отметь файлы и удали."
                go.isEnabled = true
                show()
            }
        }.start()
    }

    private fun fmt(b: Long): String = when {
        b >= 1_000_000_000L -> "%.1f ГБ".format(b / 1e9)
        b >= 1_000_000L -> "%.1f МБ".format(b / 1e6)
        else -> "%d КБ".format(b / 1000)
    }

    private fun age(m: Long): String {
        val dd = (System.currentTimeMillis() - m) / 86400000L
        return if (dd >= 365) "${dd / 365} г." else "$dd дн."
    }

    private fun show() {
        box.removeAllViews()
        for ((k, l) in res) {
            val b = button("$k\n${l.size} шт, ${fmt(l.sumOf { it.size })}")
            b.isEnabled = l.isNotEmpty()
            b.alpha = if (l.isEmpty()) .4f else 1f
            b.setOnClickListener { dlg(k) }
            val lp = LinearLayout.LayoutParams(-1, -2)
            lp.topMargin = 16
            box.addView(b, lp)
        }
    }

    private fun dlg(k: String) {
        val l = res[k]!!.sortedByDescending { it.size }.take(300)
        val names = l.map { "${it.f.name}\n${fmt(it.size)} · ${age(it.mod)} · ${it.f.parent?.removePrefix(rootDir.path)}" }.toTypedArray()
        val sel = BooleanArray(l.size)
        AlertDialog.Builder(this).setTitle(k)
            .setMultiChoiceItems(names, sel) { _, i, c -> sel[i] = c }
            .setPositiveButton("Удалить выбранные") { _, _ ->
                var n = 0
                l.forEachIndexed { i, x -> if (sel[i] && x.f.delete()) { res[k]!!.remove(x); n++ } }
                toast("Удалено файлов: $n")
                show()
            }
            .setNegativeButton("Закрыть", null)
            .show()
    }
}
