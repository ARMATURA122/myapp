package com.armatura.iconstyle

import android.app.Activity
import android.app.AlertDialog
import android.app.role.RoleManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.content.pm.LauncherActivityInfo
import android.content.pm.LauncherApps
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Outline
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.UserHandle
import android.provider.MediaStore
import android.provider.Settings
import android.text.TextUtils
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.ViewOutlineProvider
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextClock
import android.widget.TextView
import android.widget.Toast
import java.io.File
import java.io.FileOutputStream

class MainActivity : Activity() {

    private class AppEntry(
        val label: String,
        val pkg: String,
        val component: ComponentName,
        val user: UserHandle,
        val icon: Bitmap?
    )

    private val MATCH = ViewGroup.LayoutParams.MATCH_PARENT
    private val WRAP = ViewGroup.LayoutParams.WRAP_CONTENT

    private val entries = ArrayList<AppEntry>()
    private lateinit var root: FrameLayout
    private lateinit var bg: ImageView
    private lateinit var pager: Pager
    private lateinit var dots: LinearLayout
    private lateinit var dock: LinearLayout
    private lateinit var prefs: SharedPreferences
    private var batteryCard: BatteryCard? = null
    private var pendingPkg: String? = null
    private var pendingPhoto = 0

    private val pkgReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            reload()
        }
    }
    private val batteryReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            updateBattery()
        }
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()

    private fun customFile(pkg: String): File = File(File(filesDir, "custom"), "$pkg.png")

    private fun glass(radiusDp: Int): GradientDrawable {
        val g = GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM, intArrayOf(0x44FFFFFF, 0x18FFFFFF))
        g.cornerRadius = dp(radiusDp).toFloat()
        g.setStroke(dp(1), 0x33FFFFFF)
        return g
    }

    private fun roundOutline(r: Int): ViewOutlineProvider = object : ViewOutlineProvider() {
        override fun getOutline(view: View, outline: Outline) {
            outline.setRoundRect(0, 0, view.width, view.height, dp(r).toFloat())
        }
    }

    // ------------------------------------------------------------ жизненный цикл
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        prefs = getSharedPreferences("p", Context.MODE_PRIVATE)

        root = FrameLayout(this)
        root.setBackgroundColor(Color.BLACK)
        bg = ImageView(this)
        bg.scaleType = ImageView.ScaleType.CENTER_CROP
        root.addView(bg, FrameLayout.LayoutParams(MATCH, MATCH))
        pager = Pager(this)
        pager.onPage = { setDot(it) }
        root.addView(pager, FrameLayout.LayoutParams(MATCH, MATCH))

        dots = LinearLayout(this)
        dots.orientation = LinearLayout.HORIZONTAL
        val olp = FrameLayout.LayoutParams(WRAP, WRAP)
        olp.gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
        olp.bottomMargin = dp(124)
        root.addView(dots, olp)

        dock = LinearLayout(this)
        dock.orientation = LinearLayout.HORIZONTAL
        dock.gravity = Gravity.CENTER_VERTICAL
        dock.background = glass(32)
        dock.setPadding(dp(8), 0, dp(8), 0)
        val dlp = FrameLayout.LayoutParams(MATCH, dp(84))
        dlp.gravity = Gravity.BOTTOM
        dlp.setMargins(dp(12), 0, dp(12), dp(28))
        root.addView(dock, dlp)

        setContentView(root)
        applyWallpaper()

        val f = IntentFilter()
        f.addAction(Intent.ACTION_PACKAGE_ADDED)
        f.addAction(Intent.ACTION_PACKAGE_REMOVED)
        f.addDataScheme("package")
        registerReceiver(pkgReceiver, f)
        registerReceiver(batteryReceiver, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        reload()

        if (!isDefaultHome() && !prefs.getBoolean("asked", false)) {
            prefs.edit().putBoolean("asked", true).apply()
            AlertDialog.Builder(this)
                .setTitle("Главный экран")
                .setMessage("Чтобы стилизованные иконки были на телефоне вместо обычных, сделай IconStyle главным экраном.")
                .setPositiveButton("Сделать") { _, _ -> askDefault() }
                .setNegativeButton("Позже", null)
                .show()
        }
    }

    override fun onDestroy() {
        unregisterReceiver(pkgReceiver)
        unregisterReceiver(batteryReceiver)
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        pager.goTo(0)
    }

    override fun onResume() {
        super.onResume()
        updateBattery()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // лаунчер: назад ничего не делает
    }

    // ------------------------------------------------------------ главный экран по умолчанию
    private fun isDefaultHome(): Boolean {
        if (Build.VERSION.SDK_INT >= 29) {
            val rm = getSystemService(Context.ROLE_SERVICE) as RoleManager
            return rm.isRoleHeld(RoleManager.ROLE_HOME)
        }
        return false
    }

    private fun askDefault() {
        if (Build.VERSION.SDK_INT >= 29) {
            val rm = getSystemService(Context.ROLE_SERVICE) as RoleManager
            if (rm.isRoleAvailable(RoleManager.ROLE_HOME) && !rm.isRoleHeld(RoleManager.ROLE_HOME)) {
                startActivityForResult(rm.createRequestRoleIntent(RoleManager.ROLE_HOME), REQ_ROLE)
                return
            }
        }
        startActivity(Intent(Settings.ACTION_HOME_SETTINGS))
    }

    // ------------------------------------------------------------ загрузка приложений
    private fun reload() {
        Thread {
            val la = getSystemService(Context.LAUNCHER_APPS_SERVICE) as LauncherApps
            val acts = ArrayList<LauncherActivityInfo>()
            for (u in la.profiles) {
                acts.addAll(la.getActivityList(null, u))
            }
            val list = acts
                .filter { it.applicationInfo.packageName != packageName }
                .sortedBy { it.label.toString().lowercase() }
            val res = ArrayList<AppEntry>()
            for (ai in list) {
                val pkg = ai.applicationInfo.packageName
                var bmp: Bitmap? = null
                val cf = customFile(pkg)
                if (cf.exists()) {
                    bmp = BitmapFactory.decodeFile(cf.absolutePath)
                }
                if (bmp == null) {
                    bmp = try {
                        IconStyler.style(ai.getIcon(0), ICON_PX)
                    } catch (e: Exception) {
                        null
                    }
                }
                res.add(AppEntry(ai.label.toString(), pkg, ai.componentName, ai.user, bmp))
            }
            runOnUiThread {
                entries.clear()
                entries.addAll(res)
                buildUi()
            }
        }.start()
    }

    private fun launch(e: AppEntry) {
        try {
            val la = getSystemService(Context.LAUNCHER_APPS_SERVICE) as LauncherApps
            la.startMainActivity(e.component, e.user, null, null)
        } catch (ex: Exception) {
            Toast.makeText(this, "Не удалось открыть", Toast.LENGTH_SHORT).show()
        }
    }

    // ------------------------------------------------------------ сборка экранов
    private fun buildUi() {
        val keep = pager.page
        pager.removeAllViews()
        val sw = resources.displayMetrics.widthPixels
        val sh = resources.displayMetrics.heightPixels
        val strip = LinearLayout(this)
        strip.orientation = LinearLayout.HORIZONTAL
        strip.addView(widgetPage(sw), LinearLayout.LayoutParams(sw, MATCH))
        val rows = ((sh - dp(56 + 190)) / dp(92)).coerceIn(3, 7)
        val chunks = entries.chunked(rows * 4)
        for (chunk in chunks) {
            strip.addView(appPage(chunk, rows), LinearLayout.LayoutParams(sw, MATCH))
        }
        pager.addView(strip, FrameLayout.LayoutParams(WRAP, MATCH))
        pager.pageW = sw
        pager.pageCount = 1 + chunks.size
        pager.page = keep.coerceIn(0, pager.pageCount - 1)
        pager.post { pager.scrollTo(pager.page * sw, 0) }
        buildDots()
        buildDock()
    }

    private fun widgetPage(sw: Int): View {
        val p = LinearLayout(this)
        p.orientation = LinearLayout.VERTICAL
        p.setPadding(dp(14), dp(56), dp(14), dp(190))
        p.isLongClickable = true
        p.setOnLongClickListener {
            showHomeMenu()
            true
        }

        val bc = BatteryCard(this)
        bc.background = glass(28)
        batteryCard = bc
        p.addView(bc, LinearLayout.LayoutParams(MATCH, dp(96)))
        updateBattery()

        val half = (sw - dp(28) - dp(12)) / 2
        val row = LinearLayout(this)
        row.orientation = LinearLayout.HORIZONTAL
        row.addView(clockCard(), LinearLayout.LayoutParams(half, half))
        val lp2 = LinearLayout.LayoutParams(half, half)
        lp2.leftMargin = dp(12)
        row.addView(photoTile(1), lp2)
        val rlp = LinearLayout.LayoutParams(MATCH, half)
        rlp.topMargin = dp(12)
        p.addView(row, rlp)

        val wlp = LinearLayout.LayoutParams(MATCH, dp(140))
        wlp.topMargin = dp(12)
        p.addView(photoTile(2), wlp)

        val dlp = LinearLayout.LayoutParams(MATCH, dp(96))
        dlp.topMargin = dp(12)
        p.addView(dateCard(), dlp)
        return p
    }

    private fun clockCard(): View {
        val f = FrameLayout(this)
        f.background = glass(28)
        val t = TextClock(this)
        t.format24Hour = "HH:mm"
        t.format12Hour = "HH:mm"
        t.textSize = 40f
        t.typeface = Typeface.DEFAULT_BOLD
        t.setTextColor(0xFFF2F2F2.toInt())
        f.addView(t, FrameLayout.LayoutParams(WRAP, WRAP, Gravity.CENTER))
        return f
    }

    private fun dateCard(): View {
        val f = FrameLayout(this)
        f.background = glass(28)
        val col = LinearLayout(this)
        col.orientation = LinearLayout.VERTICAL
        val day = TextClock(this)
        day.format24Hour = "EEEE"
        day.format12Hour = "EEEE"
        day.textSize = 28f
        day.typeface = Typeface.create(Typeface.SERIF, Typeface.BOLD_ITALIC)
        day.setTextColor(Color.WHITE)
        col.addView(day)
        val date = TextClock(this)
        date.format24Hour = "d MMMM"
        date.format12Hour = "d MMMM"
        date.textSize = 16f
        date.setTextColor(0xCCFFFFFF.toInt())
        col.addView(date)
        f.addView(col, FrameLayout.LayoutParams(WRAP, WRAP, Gravity.CENTER_VERTICAL or Gravity.START))
        col.setPadding(dp(20), 0, 0, 0)
        return f
    }

    private fun photoTile(id: Int): View {
        val f = FrameLayout(this)
        f.background = glass(28)
        f.outlineProvider = roundOutline(28)
        f.clipToOutline = true
        val file = File(filesDir, "w$id.img")
        if (file.exists()) {
            val iv = ImageView(this)
            iv.scaleType = ImageView.ScaleType.CENTER_CROP
            iv.setImageBitmap(BitmapFactory.decodeFile(file.absolutePath))
            f.addView(iv, FrameLayout.LayoutParams(MATCH, MATCH))
        } else {
            val tv = TextView(this)
            tv.text = "Нажми, чтобы добавить фото"
            tv.setTextColor(0xAAFFFFFF.toInt())
            tv.textSize = 13f
            tv.gravity = Gravity.CENTER
            f.addView(tv, FrameLayout.LayoutParams(MATCH, MATCH))
        }
        f.setOnClickListener {
            pendingPhoto = id
            pickImage(REQ_PHOTO)
        }
        f.setOnLongClickListener {
            file.delete()
            buildUi()
            true
        }
        return f
    }

    private fun appPage(chunk: List<AppEntry>, rows: Int): View {
        val p = LinearLayout(this)
        p.orientation = LinearLayout.VERTICAL
        p.setPadding(dp(10), dp(56), dp(10), dp(190))
        p.isLongClickable = true
        p.setOnLongClickListener {
            showHomeMenu()
            true
        }
        var i = 0
        for (r in 0 until rows) {
            val row = LinearLayout(this)
            row.orientation = LinearLayout.HORIZONTAL
            for (c in 0 until 4) {
                val e = chunk.getOrNull(i)
                i++
                val cell: View = if (e != null) appCell(e, true) else View(this)
                row.addView(cell, LinearLayout.LayoutParams(0, MATCH, 1f))
            }
            p.addView(row, LinearLayout.LayoutParams(MATCH, dp(92)))
        }
        return p
    }

    private fun appCell(e: AppEntry, withLabel: Boolean): View {
        val ll = LinearLayout(this)
        ll.orientation = LinearLayout.VERTICAL
        ll.gravity = if (withLabel) Gravity.CENTER_HORIZONTAL else Gravity.CENTER
        ll.setPadding(0, dp(8), 0, dp(4))
        val iv = ImageView(this)
        iv.setImageBitmap(e.icon)
        ll.addView(iv, LinearLayout.LayoutParams(dp(62), dp(62)))
        if (withLabel) {
            val tv = TextView(this)
            tv.text = e.label
            tv.setTextColor(0xFFE6E6E6.toInt())
            tv.textSize = 11f
            tv.maxLines = 1
            tv.ellipsize = TextUtils.TruncateAt.END
            tv.gravity = Gravity.CENTER
            tv.setPadding(dp(2), dp(4), dp(2), 0)
            ll.addView(tv, LinearLayout.LayoutParams(WRAP, WRAP))
        }
        ll.setOnClickListener { launch(e) }
        ll.setOnLongClickListener {
            showMenu(e)
            true
        }
        return ll
    }

    // ------------------------------------------------------------ док и точки
    private fun dockEntries(): List<AppEntry> {
        val saved = prefs.getString("dock", null)
        if (saved != null) {
            val pk = saved.split(",").filter { it.isNotEmpty() }
            return pk.mapNotNull { p -> entries.firstOrNull { it.pkg == p } }.take(4)
        }
        val pm = packageManager
        val probes = listOf(
            Intent(Intent.ACTION_DIAL),
            Intent(Intent.ACTION_VIEW, Uri.parse("http://example.com")).addCategory(Intent.CATEGORY_BROWSABLE),
            Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:")),
            Intent(MediaStore.ACTION_IMAGE_CAPTURE)
        )
        val res = ArrayList<AppEntry>()
        for (pr in probes) {
            val pkg = pm.resolveActivity(pr, PackageManager.MATCH_DEFAULT_ONLY)?.activityInfo?.packageName
            val e = entries.firstOrNull { it.pkg == pkg }
            if (e != null && res.none { it.pkg == e.pkg }) res.add(e)
        }
        for (e in entries) {
            if (res.size >= 4) break
            if (res.none { it.pkg == e.pkg }) res.add(e)
        }
        return res.take(4)
    }

    private fun buildDock() {
        dock.removeAllViews()
        for (e in dockEntries()) {
            dock.addView(appCell(e, false), LinearLayout.LayoutParams(0, MATCH, 1f))
        }
    }

    private fun toggleDock(pkg: String) {
        val cur = dockEntries().map { it.pkg }.toMutableList()
        if (cur.contains(pkg)) {
            cur.remove(pkg)
        } else {
            cur.add(pkg)
            while (cur.size > 4) cur.removeAt(0)
        }
        prefs.edit().putString("dock", cur.joinToString(",")).apply()
        buildDock()
    }

    private fun buildDots() {
        dots.removeAllViews()
        for (i in 0 until pager.pageCount) {
            val v = View(this)
            val g = GradientDrawable()
            g.shape = GradientDrawable.OVAL
            g.setColor(Color.WHITE)
            v.background = g
            val lp = LinearLayout.LayoutParams(dp(7), dp(7))
            lp.setMargins(dp(4), 0, dp(4), 0)
            dots.addView(v, lp)
        }
        setDot(pager.page)
    }

    private fun setDot(p: Int) {
        for (i in 0 until dots.childCount) {
            dots.getChildAt(i).alpha = if (i == p) 1f else 0.35f
        }
    }

    // ------------------------------------------------------------ батарея, обои, картинки
    private fun updateBattery() {
        val i = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED)) ?: return
        val lvl = i.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = i.getIntExtra(BatteryManager.EXTRA_SCALE, 100)
        val status = i.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
        val charging = status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL
        if (lvl >= 0 && scale > 0) {
            batteryCard?.set(lvl * 100 / scale, charging)
        }
    }

    private fun applyWallpaper() {
        val f = File(filesDir, "wall.img")
        if (f.exists()) {
            bg.setImageBitmap(BitmapFactory.decodeFile(f.absolutePath))
        } else {
            bg.setImageDrawable(GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM, intArrayOf(0xFF2A2A2C.toInt(), 0xFF000000.toInt())))
        }
    }

    private fun pickImage(req: Int) {
        val pick = Intent(Intent.ACTION_GET_CONTENT).setType("image/*")
        startActivityForResult(Intent.createChooser(pick, "Выбери картинку"), req)
    }

    private fun saveScaled(uri: Uri, file: File, maxSide: Int) {
        val src = contentResolver.openInputStream(uri).use { BitmapFactory.decodeStream(it) } ?: return
        val s = maxSide.toFloat() / maxOf(src.width, src.height)
        val bmp = if (s < 1f) {
            Bitmap.createScaledBitmap(src, (src.width * s).toInt(), (src.height * s).toInt(), true)
        } else {
            src
        }
        FileOutputStream(file).use { bmp.compress(Bitmap.CompressFormat.JPEG, 90, it) }
    }

    // ------------------------------------------------------------ меню
    private fun showHomeMenu() {
        val opts = arrayOf("Обои из галереи", "Сбросить обои", "Сделать главным экраном")
        AlertDialog.Builder(this)
            .setTitle("Главный экран")
            .setItems(opts) { _, which ->
                when (which) {
                    0 -> pickImage(REQ_WALL)
                    1 -> {
                        File(filesDir, "wall.img").delete()
                        applyWallpaper()
                    }
                    2 -> askDefault()
                }
            }
            .show()
    }

    private fun showMenu(e: AppEntry) {
        val inDock = dockEntries().any { it.pkg == e.pkg }
        val opts = arrayOf(
            "Сменить иконку (из галереи)",
            "Сбросить иконку",
            if (inDock) "Убрать из дока" else "В док",
            "О приложении"
        )
        AlertDialog.Builder(this)
            .setTitle(e.label)
            .setItems(opts) { _, which ->
                when (which) {
                    0 -> {
                        pendingPkg = e.pkg
                        pickImage(REQ_PICK)
                    }
                    1 -> {
                        customFile(e.pkg).delete()
                        reload()
                    }
                    2 -> toggleDock(e.pkg)
                    3 -> {
                        val i = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        i.data = Uri.parse("package:" + e.pkg)
                        startActivity(i)
                    }
                }
            }
            .show()
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (resultCode != RESULT_OK) return
        val uri = data?.data ?: return
        try {
            when (requestCode) {
                REQ_PICK -> {
                    val pkg = pendingPkg ?: return
                    val src = contentResolver.openInputStream(uri).use { BitmapFactory.decodeStream(it) } ?: return
                    val bmp = IconStyler.custom(src, ICON_PX)
                    val f = customFile(pkg)
                    f.parentFile?.mkdirs()
                    FileOutputStream(f).use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
                    reload()
                }
                REQ_PHOTO -> {
                    saveScaled(uri, File(filesDir, "w$pendingPhoto.img"), 1200)
                    buildUi()
                }
                REQ_WALL -> {
                    saveScaled(uri, File(filesDir, "wall.img"), 1600)
                    applyWallpaper()
                }
            }
        } catch (ex: Exception) {
            Toast.makeText(this, "Не получилось загрузить картинку", Toast.LENGTH_SHORT).show()
        }
    }

    companion object {
        private const val ICON_PX = 192
        private const val REQ_PICK = 1
        private const val REQ_ROLE = 2
        private const val REQ_PHOTO = 3
        private const val REQ_WALL = 4
    }
}
