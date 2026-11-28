package com.armatura.guard

import android.app.Activity
import android.app.AlertDialog
import android.app.admin.DevicePolicyManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.widget.*
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

class Hit(val title: String, val id: String, val pkg: String?, val src: File?, val isFile: Boolean) {
    var score = 0
    var vt = -1
    val why = ArrayList<String>()
    fun add(p: Int, t: String) { score += p; why.add(t) }
}

class MainActivity : Activity() {
    private val RED = 0xFFFF4D6A.toInt()
    private val ORANGE = 0xFFFFA24D.toInt()
    private val GREEN = 0xFF4DFF9A.toInt()
    private val CARD = 0xFF1A0B2E.toInt()
    private val ACC = 0xFF8E5BFF.toInt()
    private lateinit var shield: TextView
    private lateinit var info: TextView
    private lateinit var bar: ProgressBar
    private lateinit var list: LinearLayout
    private lateinit var go: Button
    private lateinit var acc: Button
    private val sp: SharedPreferences get() = getSharedPreferences("g", 0)
    private val rootDir: File = Environment.getExternalStorageDirectory()
    private var dp = 1f
    private fun d(x: Int) = (x * dp).toInt()
    private fun toast(t: String) = Toast.makeText(this, t, Toast.LENGTH_SHORT).show()
    private val stores = setOf("com.android.vending", "com.sec.android.app.samsungapps", "com.xiaomi.mipicks", "com.huawei.appmarket", "com.amazon.venezia", "org.fdroid.fdroid")
    private val dbl = Regex(".*\\.(pdf|jpg|jpeg|png|doc|docx|xls|xlsx|mp3|mp4|txt|zip)\\.(apk|exe|bat|scr|sh|vbs)", RegexOption.IGNORE_CASE)

    private fun round(c: Int, r: Int = 28): GradientDrawable { val g = GradientDrawable(); g.cornerRadius = r.toFloat(); g.setColor(c); return g }

    private fun btn(t: String, c: Int): Button {
        val b = Button(this)
        b.text = t; b.setTextColor(Color.WHITE); b.isAllCaps = false; b.background = round(c, 40)
        return b
    }

    private fun tv(t: String, size: Float, c: Int, bold: Boolean = false): TextView {
        val v = TextView(this)
        v.text = t; v.textSize = size; v.setTextColor(c)
        if (bold) v.setTypeface(null, android.graphics.Typeface.BOLD)
        return v
    }

    override fun onCreate(s: Bundle?) {
        super.onCreate(s)
        dp = resources.displayMetrics.density
        val col = LinearLayout(this)
        col.orientation = LinearLayout.VERTICAL
        col.setPadding(d(16), d(44), d(16), d(24))
        col.setBackgroundColor(0xFF0B0614.toInt())
        col.addView(tv("Guard", 30f, Color.WHITE, true))
        shield = tv("🛡️\nГотов к проверке", 20f, Color.WHITE, true)
        shield.gravity = Gravity.CENTER
        shield.setPadding(d(16), d(28), d(16), d(28))
        shield.background = round(CARD)
        val sl = LinearLayout.LayoutParams(-1, -2)
        sl.topMargin = d(12)
        col.addView(shield, sl)
        bar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal)
        bar.isIndeterminate = true; bar.visibility = View.GONE
        col.addView(bar)
        info = tv("Проверяю установленные приложения и APK-файлы. Показываю только то, что похоже на вирус.", 13f, 0xFFB8B0CC.toInt())
        info.setPadding(0, d(10), 0, d(10))
        col.addView(info)
        val row = LinearLayout(this)
        go = btn("Сканировать", ACC)
        go.setOnClickListener { scan() }
        val key = btn("🔑", CARD)
        key.setOnClickListener { keyDialog() }
        row.addView(go, LinearLayout.LayoutParams(0, -2, 1f))
        row.addView(key, LinearLayout.LayoutParams(d(64), -2))
        col.addView(row)
        acc = btn("Разрешить доступ к файлам (для проверки APK)", CARD)
        acc.setOnClickListener { startActivity(Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, Uri.parse("package:$packageName"))) }
        col.addView(acc)
        list = LinearLayout(this)
        list.orientation = LinearLayout.VERTICAL
        col.addView(list)
        val sv = ScrollView(this)
        sv.addView(col)
        setContentView(sv)
    }

    override fun onResume() {
        super.onResume()
        acc.visibility = if (Environment.isExternalStorageManager()) View.GONE else View.VISIBLE
    }

    private fun keyDialog() {
        val e = EditText(this)
        e.hint = "Ключ API VirusTotal"
        e.setText(sp.getString("vt", ""))
        AlertDialog.Builder(this).setTitle("Ключ VirusTotal")
            .setMessage("Бесплатный ключ: virustotal.com, регистрация, профиль, API key. С ним можно определить «точно вирус».")
            .setView(e)
            .setPositiveButton("Сохранить") { _, _ -> sp.edit().putString("vt", e.text.toString().trim()).apply(); toast("Сохранено") }
            .setNegativeButton("Отмена", null).show()
    }

    private fun say(t: String) = runOnUiThread { info.text = t }

    private fun sha256(f: File): String? = try {
        val md = MessageDigest.getInstance("SHA-256")
        f.inputStream().use { i -> val b = ByteArray(65536); while (true) { val r = i.read(b); if (r < 0) break; md.update(b, 0, r) } }
        md.digest().joinToString("") { "%02x".format(it) }
    } catch (e: Exception) { null }

    private fun vt(hash: String, key: String): Int? = try {
        val c = URL("https://www.virustotal.com/api/v3/files/$hash").openConnection() as HttpURLConnection
        c.setRequestProperty("x-apikey", key)
        c.connectTimeout = 15000; c.readTimeout = 15000
        when (c.responseCode) {
            200 -> JSONObject(c.inputStream.bufferedReader().readText()).getJSONObject("data").getJSONObject("attributes").getJSONObject("last_analysis_stats").getInt("malicious")
            404 -> 0
            else -> null
        }
    } catch (e: Exception) { null }

    private fun perms(h: Hit, pi: PackageInfo) {
        val p = pi.requestedPermissions?.toSet() ?: emptySet()
        if (p.any { it.endsWith("READ_SMS") || it.endsWith("SEND_SMS") || it.endsWith("RECEIVE_SMS") }) h.add(2, "Доступ к SMS")
        if (p.any { it.endsWith("READ_CALL_LOG") }) h.add(1, "Читает журнал звонков")
        if (p.any { it.endsWith("REQUEST_INSTALL_PACKAGES") }) h.add(2, "Может устанавливать другие приложения")
        if (p.any { it.endsWith("SYSTEM_ALERT_WINDOW") }) h.add(1, "Рисует поверх других окон")
        if (p.any { it.endsWith("RECORD_AUDIO") } && p.any { it.endsWith("CAMERA") } && p.any { it.endsWith("ACCESS_FINE_LOCATION") }) h.add(1, "Микрофон, камера и точная геолокация")
        if (pi.services?.any { it.permission == "android.permission.BIND_ACCESSIBILITY_SERVICE" } == true) h.add(1, "Есть служба специальных возможностей")
    }

    private fun level(h: Hit): Int {
        if (h.vt >= 5 || (h.vt >= 2 && h.score >= 5)) return 2
        if (h.score >= 7 || h.vt >= 2 || (h.vt >= 1 && h.score >= 3)) return 1
        return 0
    }

    @Suppress("DEPRECATION")
    private fun scan() {
        go.isEnabled = false
        list.removeAllViews()
        bar.visibility = View.VISIBLE
        val key = sp.getString("vt", "") ?: ""
        Thread {
            val pm = packageManager
            val now = System.currentTimeMillis()
            val hits = ArrayList<Hit>()
            say("Проверяю приложения...")
            val accs = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: ""
            val nls = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: ""
            val admins: List<String> = try {
                (getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager).activeAdmins?.map { it.packageName } ?: emptyList()
            } catch (e: Exception) { emptyList() }
            var napps = 0
            for (pi in pm.getInstalledPackages(PackageManager.GET_PERMISSIONS or PackageManager.GET_SERVICES)) {
                val ai = pi.applicationInfo ?: continue
                val sys = (ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0 && (ai.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) == 0
                if (sys || pi.packageName == packageName) continue
                napps++
                val pkg = pi.packageName
                val h = Hit(pm.getApplicationLabel(ai).toString(), pkg, pkg, File(ai.sourceDir), false)
                val inst = try {
                    if (Build.VERSION.SDK_INT >= 30) pm.getInstallSourceInfo(pkg).installingPackageName else pm.getInstallerPackageName(pkg)
                } catch (e: Exception) { null }
                val store = inst in stores
                if (!store) h.add(2, "Установлено не из магазина приложений")
                perms(h, pi)
                if (accs.contains("$pkg/")) h.add(4, "Включена служба специальных возможностей")
                if (nls.contains("$pkg/")) h.add(3, "Читает все уведомления")
                if (pkg in admins) h.add(4, "Права администратора устройства")
                if (!store && pm.getLaunchIntentForPackage(pkg) == null) h.add(3, "Нет значка в меню (скрытое приложение)")
                if (!store && now - pi.firstInstallTime < 3 * 86400000L) h.add(1, "Установлено недавно")
                if (store) h.score -= 3
                hits.add(h)
            }
            var nfiles = 0
            if (Environment.isExternalStorageManager()) {
                say("Ищу APK-файлы...")
                rootDir.walkTopDown().onEnter { !(it.parentFile == rootDir && it.name == "Android") }
                    .filter { it.isFile && it.extension.equals("apk", true) }.take(150).forEach { f ->
                        val pi = pm.getPackageArchiveInfo(f.path, PackageManager.GET_PERMISSIONS or PackageManager.GET_SERVICES) ?: return@forEach
                        nfiles++
                        val h = Hit(f.name, f.path, null, f, true)
                        h.add(2, "Установочный файл лежит вне магазина")
                        perms(h, pi)
                        if (dbl.matches(f.name)) h.add(4, "Двойное расширение в имени файла")
                        hits.add(h)
                    }
            }
            var nvt = 0
            if (key.isNotEmpty()) {
                val cand = hits.filter { it.score >= 2 }.sortedByDescending { it.score }.take(12)
                for ((i, h) in cand.withIndex()) {
                    say("VirusTotal: ${i + 1} из ${cand.size} (около 16 секунд на файл)")
                    val hash = h.src?.let { sha256(it) } ?: continue
                    val r = vt(hash, key)
                    if (r != null) { h.vt = r; nvt++ }
                    if (i < cand.size - 1) Thread.sleep(16000)
                }
            }
            runOnUiThread { render(hits, napps, nfiles, nvt, key.isNotEmpty()) }
        }.start()
    }

    private fun render(hits: List<Hit>, napps: Int, nfiles: Int, nvt: Int, hasKey: Boolean) {
        val ign = sp.getStringSet("ign", emptySet()) ?: emptySet()
        val bad = hits.filter { level(it) > 0 && it.id !in ign }
            .sortedWith(compareByDescending<Hit> { level(it) }.thenByDescending { it.score })
        val sure = bad.count { level(it) == 2 }
        shield.text = if (bad.isEmpty()) "🛡️\nУгроз не найдено" else "⚠️\nТочно вирус: $sure\nВероятно вирус: ${bad.size - sure}"
        shield.setTextColor(if (bad.isEmpty()) GREEN else if (sure > 0) RED else ORANGE)
        info.text = "Проверено приложений: $napps, APK-файлов: $nfiles, через VirusTotal: $nvt." +
            (if (!hasKey) "\nБез ключа VirusTotal («🔑») «точно вирус» определить нельзя, только «вероятно»." else "")
        for (h in bad) list.addView(card(h))
        go.isEnabled = true
        bar.visibility = View.GONE
        acc.visibility = if (Environment.isExternalStorageManager()) View.GONE else View.VISIBLE
    }

    private fun card(h: Hit): View {
        val lv = level(h)
        val c = if (lv == 2) RED else ORANGE
        val row = LinearLayout(this)
        row.background = round(CARD)
        val strip = View(this)
        strip.setBackgroundColor(c)
        row.addView(strip, LinearLayout.LayoutParams(d(6), -1))
        val body = LinearLayout(this)
        body.orientation = LinearLayout.VERTICAL
        body.setPadding(d(14), d(12), d(14), d(12))
        body.addView(tv(if (lv == 2) "ТОЧНО ВИРУС" else "ВЕРОЯТНО ВИРУС", 12f, c, true))
        body.addView(tv(h.title, 17f, Color.WHITE, true))
        body.addView(tv(if (h.isFile) "Файл · " + h.id.removePrefix(rootDir.path) else "Приложение · " + h.id, 12f, 0xFF9A90B8.toInt()))
        val why = h.why.joinToString("\n") { "• $it" } + (if (h.vt >= 0) "\n• VirusTotal: опасным считают антивирусов: ${h.vt}" else "")
        val w = tv(why, 13f, 0xFFE0DCF0.toInt())
        w.setPadding(0, d(8), 0, d(8))
        body.addView(w)
        val bl = LinearLayout(this)
        val del = btn("Удалить", RED)
        val keep = btn("Оставить", 0xFF3A2A5E.toInt())
        del.setOnClickListener {
            if (h.isFile) AlertDialog.Builder(this).setMessage("Удалить файл?").setPositiveButton("Да") { _, _ ->
                if (h.src?.delete() == true) { list.removeView(row); toast("Удалено") } else toast("Не получилось")
            }.setNegativeButton("Нет", null).show()
            else startActivity(Intent(Intent.ACTION_DELETE, Uri.parse("package:${h.pkg}")))
        }
        keep.setOnClickListener {
            val s = HashSet(sp.getStringSet("ign", emptySet()) ?: emptySet())
            s.add(h.id)
            sp.edit().putStringSet("ign", s).apply()
            list.removeView(row)
        }
        bl.addView(del, LinearLayout.LayoutParams(0, -2, 1f))
        bl.addView(keep, LinearLayout.LayoutParams(0, -2, 1f))
        body.addView(bl)
        row.addView(body, LinearLayout.LayoutParams(0, -2, 1f))
        val lp = LinearLayout.LayoutParams(-1, -2)
        lp.topMargin = d(12)
        row.layoutParams = lp
        return row
    }
}
