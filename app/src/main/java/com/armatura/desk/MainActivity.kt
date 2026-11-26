package com.armatura.desk

import android.app.Activity
import android.app.ActivityManager
import android.app.AlertDialog
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.content.pm.LauncherApps
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.SurfaceTexture
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.media.MediaPlayer
import android.net.Uri
import android.os.BatteryManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.UserHandle
import android.provider.Settings
import android.view.Gravity
import android.view.Surface
import android.view.TextureView
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextClock
import android.widget.TextView
import android.widget.Toast
import java.io.File
import java.io.FileOutputStream

class MainActivity : Activity() {

    private class AppEntry(val label: String, val comp: ComponentName, val user: UserHandle, val icon: Bitmap)

    private val MATCH = ViewGroup.LayoutParams.MATCH_PARENT
    private val WRAP = ViewGroup.LayoutParams.WRAP_CONTENT

    private val entries = ArrayList<AppEntry>()
    private lateinit var prefs: SharedPreferences
    private lateinit var root: FrameLayout
    private lateinit var wallHolder: FrameLayout
    private var content: FrameLayout? = null
    private var ram: RamRing? = null
    private var status: TextView? = null
    private var player: MediaPlayer? = null
    private val handler = Handler(Looper.getMainLooper())
    private val tick = object : Runnable {
        override fun run() {
            updateStats()
            handler.postDelayed(this, 2000)
        }
    }

    private val accents = intArrayOf(0xFFB388FF.toInt(), 0xFFFFFFFF.toInt(), 0xFF9E9EA8.toInt())
    private val accentNames = arrayOf("Фиолетовый", "Чёрно-белый", "Графит")

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()
    private fun accent(): Int = accents[prefs.getInt("accent", 0).coerceIn(0, 2)]
    private fun panelColor(): Int = if (prefs.getInt("accent", 0) == 0) 0xAA1B1030.toInt() else 0xAA101010.toInt()

    private fun glass(radiusDp: Int): GradientDrawable {
        val g = GradientDrawable()
        g.setColor(panelColor())
        g.cornerRadius = dp(radiusDp).toFloat()
        g.setStroke(dp(1), (accent() and 0x00FFFFFF) or 0x66000000)
        return g
    }

    // ------------------------------------------------------------ жизненный цикл
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        prefs = getSharedPreferences("desk", Context.MODE_PRIVATE)
        root = FrameLayout(this)
        root.setBackgroundColor(Color.BLACK)
        wallHolder = FrameLayout(this)
        root.addView(wallHolder, FrameLayout.LayoutParams(MATCH, MATCH))
        val dim = View(this)
        dim.setBackgroundColor(0x33000000)
        root.addView(dim, FrameLayout.LayoutParams(MATCH, MATCH))
        setContentView(root)
        applyWallpaper()
        buildDesktop()
        loadApps()
    }

    override fun onResume() {
        super.onResume()
        handler.post(tick)
        player?.start()
    }

    override fun onPause() {
        handler.removeCallbacks(tick)
        player?.pause()
        super.onPause()
    }

    override fun onDestroy() {
        player?.release()
        player = null
        super.onDestroy()
    }

    // ------------------------------------------------------------ приложения
    private fun bitmapOf(d: Drawable, size: Int): Bitmap {
        val b = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val c = Canvas(b)
        d.setBounds(0, 0, size, size)
        d.draw(c)
        return b
    }

    private fun loadApps() {
        Thread {
            val la = getSystemService(Context.LAUNCHER_APPS_SERVICE) as LauncherApps
            val me = Process.myUserHandle()
            val list = la.getActivityList(null, me)
                .filter { it.applicationInfo.packageName != packageName }
                .sortedBy { it.label.toString().lowercase() }
            val res = ArrayList<AppEntry>()
            for (ai in list) {
                try {
                    res.add(AppEntry(ai.label.toString(), ai.componentName, me, bitmapOf(ai.getIcon(0), 128)))
                } catch (e: Exception) {
                    // пропускаем проблемную иконку
                }
            }
            runOnUiThread {
                entries.clear()
                entries.addAll(res)
                buildDesktop()
            }
        }.start()
    }

    private fun launch(e: AppEntry) {
        try {
            val la = getSystemService(Context.LAUNCHER_APPS_SERVICE) as LauncherApps
            la.startMainActivity(e.comp, e.user, null, null)
        } catch (ex: Exception) {
            Toast.makeText(this, "Не удалось открыть", Toast.LENGTH_SHORT).show()
        }
    }

    private fun chosenGames(): List<AppEntry> {
        val sel = prefs.getStringSet("games", emptySet()) ?: emptySet()
        return entries.filter { sel.contains(it.comp.flattenToString()) }
    }

    // ------------------------------------------------------------ рабочий стол
    private fun buildDesktop() {
        content?.let { root.removeView(it) }
        val c = FrameLayout(this)
        content = c
        root.addView(c, FrameLayout.LayoutParams(MATCH, MATCH))
        val games = chosenGames()

        // большие часы по центру сверху
        val clockBox = LinearLayout(this)
        clockBox.orientation = LinearLayout.VERTICAL
        clockBox.gravity = Gravity.CENTER_HORIZONTAL
        val big = TextClock(this)
        big.format24Hour = "HH:mm:ss"
        big.format12Hour = "HH:mm:ss"
        big.textSize = 56f
        big.typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.NORMAL)
        big.setTextColor(Color.WHITE)
        big.setShadowLayer(8f, 0f, 2f, 0x99000000.toInt())
        clockBox.addView(big)
        val day = TextClock(this)
        day.format24Hour = "EEEE, d MMMM"
        day.format12Hour = "EEEE, d MMMM"
        day.textSize = 20f
        day.setTextColor(0xFFE6DAFF.toInt())
        day.setShadowLayer(8f, 0f, 2f, 0x99000000.toInt())
        clockBox.addView(day)
        val clp = FrameLayout.LayoutParams(WRAP, WRAP, Gravity.TOP or Gravity.CENTER_HORIZONTAL)
        clp.topMargin = dp(60)
        c.addView(clockBox, clp)

        // иконки на рабочем столе слева
        val col = LinearLayout(this)
        col.orientation = LinearLayout.VERTICAL
        for (e in games) {
            col.addView(iconCell(e, true, 56), LinearLayout.LayoutParams(dp(92), WRAP))
        }
        val sv = ScrollView(this)
        sv.isVerticalScrollBarEnabled = false
        sv.addView(col)
        val slp = FrameLayout.LayoutParams(dp(96), MATCH, Gravity.START)
        slp.topMargin = dp(48)
        slp.bottomMargin = dp(220)
        c.addView(sv, slp)

        if (games.isEmpty()) {
            val hint = TextView(this)
            hint.text = "Нажми «Игры» сверху слева и отметь свои игры"
            hint.setTextColor(0xCCFFFFFF.toInt())
            hint.textSize = 14f
            hint.gravity = Gravity.CENTER
            hint.setPadding(dp(110), 0, dp(20), 0)
            c.addView(hint, FrameLayout.LayoutParams(MATCH, MATCH))
        }

        // кольцо ОЗУ
        val r = RamRing(this)
        r.accent = accent()
        ram = r
        val rlp = FrameLayout.LayoutParams(dp(110), dp(110), Gravity.BOTTOM or Gravity.END)
        rlp.setMargins(0, 0, dp(16), dp(110))
        c.addView(r, rlp)

        // нижний док
        val dock = LinearLayout(this)
        dock.orientation = LinearLayout.HORIZONTAL
        dock.gravity = Gravity.CENTER_VERTICAL
        dock.background = glass(28)
        dock.setPadding(dp(10), dp(6), dp(10), dp(6))
        for (e in games.take(7)) {
            dock.addView(iconCell(e, false, 46), LinearLayout.LayoutParams(dp(58), dp(58)))
        }
        val more = TextView(this)
        more.text = "Игры"
        more.setTextColor(accent())
        more.textSize = 13f
        more.gravity = Gravity.CENTER
        more.typeface = Typeface.DEFAULT_BOLD
        more.setOnClickListener { pickGames() }
        dock.addView(more, LinearLayout.LayoutParams(dp(58), dp(58)))
        val dlp = FrameLayout.LayoutParams(WRAP, WRAP, Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL)
        dlp.bottomMargin = dp(14)
        c.addView(dock, dlp)

        // верхняя панель
        val bar = FrameLayout(this)
        bar.setBackgroundColor(0xCC0B0714.toInt())
        val left = TextView(this)
        left.text = "  Игры  "
        left.setTextColor(accent())
        left.typeface = Typeface.DEFAULT_BOLD
        left.textSize = 14f
        left.gravity = Gravity.CENTER_VERTICAL
        left.setOnClickListener { pickGames() }
        bar.addView(left, FrameLayout.LayoutParams(WRAP, MATCH, Gravity.START))
        val mid = TextClock(this)
        mid.format24Hour = "EEE, d MMM   HH:mm"
        mid.format12Hour = "EEE, d MMM   HH:mm"
        mid.setTextColor(Color.WHITE)
        mid.textSize = 14f
        mid.gravity = Gravity.CENTER
        bar.addView(mid, FrameLayout.LayoutParams(WRAP, MATCH, Gravity.CENTER))
        val right = LinearLayout(this)
        right.orientation = LinearLayout.HORIZONTAL
        right.gravity = Gravity.CENTER_VERTICAL
        val st = TextView(this)
        st.setTextColor(0xFFE6DAFF.toInt())
        st.textSize = 12f
        status = st
        right.addView(st)
        val gear = TextView(this)
        gear.text = "   Настройки  "
        gear.setTextColor(accent())
        gear.typeface = Typeface.DEFAULT_BOLD
        gear.textSize = 14f
        gear.setOnClickListener { showSettings() }
        right.addView(gear)
        bar.addView(right, FrameLayout.LayoutParams(WRAP, MATCH, Gravity.END))
        c.addView(bar, FrameLayout.LayoutParams(MATCH, dp(38), Gravity.TOP))
        updateStats()
    }

    private fun iconCell(e: AppEntry, label: Boolean, sizeDp: Int): View {
        val ll = LinearLayout(this)
        ll.orientation = LinearLayout.VERTICAL
        ll.gravity = Gravity.CENTER
        ll.setPadding(0, dp(6), 0, dp(6))
        val iv = ImageView(this)
        iv.setImageBitmap(e.icon)
        ll.addView(iv, LinearLayout.LayoutParams(dp(sizeDp), dp(sizeDp)))
        if (label) {
            val tv = TextView(this)
            tv.text = e.label
            tv.setTextColor(Color.WHITE)
            tv.setShadowLayer(6f, 0f, 1f, 0xCC000000.toInt())
            tv.textSize = 11f
            tv.maxLines = 2
            tv.gravity = Gravity.CENTER
            tv.setPadding(dp(2), dp(3), dp(2), 0)
            ll.addView(tv, LinearLayout.LayoutParams(MATCH, WRAP))
        }
        ll.setOnClickListener { launch(e) }
        return ll
    }

    // ------------------------------------------------------------ статистика
    private fun battery(): Int {
        val i = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED)) ?: return 0
        val lvl = i.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = i.getIntExtra(BatteryManager.EXTRA_SCALE, 100)
        return if (lvl >= 0 && scale > 0) lvl * 100 / scale else 0
    }

    private fun updateStats() {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val mi = ActivityManager.MemoryInfo()
        am.getMemoryInfo(mi)
        val total = mi.totalMem.toDouble()
        val used = total - mi.availMem
        val pct = (used / total * 100).toInt()
        ram?.set(pct, used / 1e9, total / 1e9)
        status?.text = "RAM $pct%   BAT ${battery()}%"
    }

    // ------------------------------------------------------------ выбор игр и настройки
    private fun pickGames() {
        if (entries.isEmpty()) {
            Toast.makeText(this, "Список приложений ещё грузится", Toast.LENGTH_SHORT).show()
            return
        }
        val labels = entries.map { it.label }.toTypedArray()
        val sel = HashSet<String>(prefs.getStringSet("games", emptySet()) ?: emptySet())
        val checked = BooleanArray(entries.size) { sel.contains(entries[it].comp.flattenToString()) }
        AlertDialog.Builder(this)
            .setTitle("Мои игры")
            .setMultiChoiceItems(labels, checked) { _, i, on ->
                val k = entries[i].comp.flattenToString()
                if (on) sel.add(k) else sel.remove(k)
            }
            .setPositiveButton("Готово") { _, _ ->
                prefs.edit().putStringSet("games", HashSet(sel)).apply()
                buildDesktop()
            }
            .setNegativeButton("Отмена", null)
            .show()
    }

    private fun serviceEnabled(): Boolean {
        val s = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: return false
        return s.contains("$packageName/")
    }

    private fun openServiceSettings() {
        Toast.makeText(this, "Найди Purple Desk в списке и включи", Toast.LENGTH_LONG).show()
        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
    }

    private fun toggleOverlay(key: String) {
        val now = !prefs.getBoolean(key, false)
        prefs.edit().putBoolean(key, now).apply()
        if (now && !serviceEnabled()) openServiceSettings()
    }

    private fun showSettings() {
        val stats = prefs.getBoolean("ov_stats", false)
        val keys = prefs.getBoolean("ov_keys", false)
        val opts = arrayOf(
            "Обои: фото из галереи",
            "Обои: видео (живые обои)",
            "Сбросить обои",
            "Цвет: " + accentNames[prefs.getInt("accent", 0).coerceIn(0, 2)],
            "RAM и батарея поверх игр: " + (if (stats) "вкл" else "выкл"),
            "Показ нажатых клавиш: " + (if (keys) "вкл" else "выкл"),
            "Включить службу оверлея"
        )
        AlertDialog.Builder(this)
            .setTitle("Настройки")
            .setItems(opts) { _, which ->
                when (which) {
                    0 -> pick("image/*", REQ_PHOTO)
                    1 -> pick("video/*", REQ_VIDEO)
                    2 -> {
                        prefs.edit().putString("wall_type", "none").apply()
                        applyWallpaper()
                    }
                    3 -> {
                        prefs.edit().putInt("accent", (prefs.getInt("accent", 0) + 1) % 3).apply()
                        buildDesktop()
                    }
                    4 -> toggleOverlay("ov_stats")
                    5 -> toggleOverlay("ov_keys")
                    6 -> openServiceSettings()
                }
            }
            .show()
    }

    // ------------------------------------------------------------ обои
    private fun pick(type: String, req: Int) {
        val i = Intent(Intent.ACTION_GET_CONTENT).setType(type)
        startActivityForResult(Intent.createChooser(i, "Выбери файл"), req)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (resultCode != RESULT_OK) return
        val uri = data?.data ?: return
        val isVideo = requestCode == REQ_VIDEO
        if (requestCode != REQ_PHOTO && !isVideo) return
        Toast.makeText(this, "Загружаю обои...", Toast.LENGTH_SHORT).show()
        Thread {
            try {
                if (isVideo) {
                    val f = File(filesDir, "wall.mp4")
                    contentResolver.openInputStream(uri)?.use { input ->
                        FileOutputStream(f).use { out -> input.copyTo(out) }
                    }
                } else {
                    val src = contentResolver.openInputStream(uri).use { BitmapFactory.decodeStream(it) }
                    if (src != null) {
                        val s = 1600f / maxOf(src.width, src.height)
                        val bmp = if (s < 1f) {
                            Bitmap.createScaledBitmap(src, (src.width * s).toInt(), (src.height * s).toInt(), true)
                        } else {
                            src
                        }
                        FileOutputStream(File(filesDir, "wall.img")).use { bmp.compress(Bitmap.CompressFormat.JPEG, 90, it) }
                    }
                }
                prefs.edit().putString("wall_type", if (isVideo) "video" else "photo").apply()
                runOnUiThread { applyWallpaper() }
            } catch (e: Exception) {
                runOnUiThread { Toast.makeText(this, "Не получилось загрузить файл", Toast.LENGTH_SHORT).show() }
            }
        }.start()
    }

    private fun applyWallpaper() {
        player?.release()
        player = null
        wallHolder.removeAllViews()
        val type = prefs.getString("wall_type", "none")
        val img = File(filesDir, "wall.img")
        val vid = File(filesDir, "wall.mp4")
        if (type == "photo" && img.exists()) {
            val iv = ImageView(this)
            iv.scaleType = ImageView.ScaleType.CENTER_CROP
            iv.setImageBitmap(BitmapFactory.decodeFile(img.absolutePath))
            wallHolder.addView(iv, FrameLayout.LayoutParams(MATCH, MATCH))
        } else if (type == "video" && vid.exists()) {
            showVideo(vid)
        } else {
            val v = View(this)
            v.background = GradientDrawable(
                GradientDrawable.Orientation.TL_BR,
                intArrayOf(0xFF4A3478.toInt(), 0xFF1B1030.toInt(), 0xFF07050C.toInt())
            )
            wallHolder.addView(v, FrameLayout.LayoutParams(MATCH, MATCH))
        }
    }

    private fun showVideo(file: File) {
        val tv = TextureView(this)
        tv.surfaceTextureListener = object : TextureView.SurfaceTextureListener {
            override fun onSurfaceTextureAvailable(st: SurfaceTexture, w: Int, h: Int) {
                try {
                    val mp = MediaPlayer()
                    mp.setDataSource(file.absolutePath)
                    mp.setSurface(Surface(st))
                    mp.isLooping = true
                    mp.setVolume(0f, 0f)
                    mp.setOnVideoSizeChangedListener { _, vw, vh -> fitVideo(tv, vw, vh) }
                    mp.setOnPreparedListener { it.start() }
                    mp.prepareAsync()
                    player = mp
                } catch (e: Exception) {
                    // оставляем чёрный фон
                }
            }

            override fun onSurfaceTextureSizeChanged(st: SurfaceTexture, w: Int, h: Int) {
            }

            override fun onSurfaceTextureDestroyed(st: SurfaceTexture): Boolean = true

            override fun onSurfaceTextureUpdated(st: SurfaceTexture) {
            }
        }
        wallHolder.addView(tv, FrameLayout.LayoutParams(MATCH, MATCH))
    }

    /** Растягиваем видео на весь экран с обрезкой краёв. */
    private fun fitVideo(tv: TextureView, vw: Int, vh: Int) {
        val w = resources.displayMetrics.widthPixels.toFloat()
        val h = resources.displayMetrics.heightPixels.toFloat()
        if (vw <= 0 || vh <= 0) return
        val s = maxOf(w / vw, h / vh)
        val m = Matrix()
        m.setScale(vw * s / w, vh * s / h, w / 2f, h / 2f)
        tv.setTransform(m)
    }

    companion object {
        private const val REQ_PHOTO = 1
        private const val REQ_VIDEO = 2
    }
}
