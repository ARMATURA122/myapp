package com.armatura.iconstyle

import android.app.Activity
import android.app.AlertDialog
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.LauncherActivityInfo
import android.content.pm.LauncherApps
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.Icon
import android.os.Bundle
import android.os.Process
import android.text.TextUtils
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.BaseAdapter
import android.widget.GridView
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import java.io.File
import java.io.FileOutputStream

class MainActivity : Activity() {

    private class AppEntry(val label: String, val pkg: String, val component: ComponentName, val icon: Bitmap?)

    private val items = ArrayList<AppEntry>()
    private lateinit var grid: GridView
    private lateinit var adapter: Adapter
    private var pendingPkg: String? = null

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()

    private fun customFile(pkg: String): File = File(File(filesDir, "custom"), "$pkg.png")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val root = LinearLayout(this)
        root.orientation = LinearLayout.VERTICAL
        root.setBackgroundColor(Color.BLACK)

        val hint = TextView(this)
        hint.text = "Нажми на иконку, и она добавится на рабочий стол. Старую иконку потом убери с рабочего стола (зажать, Убрать). Долгое нажатие: своя картинка."
        hint.setTextColor(0xFFCCCCCC.toInt())
        hint.textSize = 13f
        hint.setPadding(dp(16), dp(40), dp(16), dp(8))
        root.addView(hint, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))

        grid = GridView(this)
        grid.numColumns = 4
        grid.stretchMode = GridView.STRETCH_COLUMN_WIDTH
        grid.verticalSpacing = dp(6)
        grid.selector = ColorDrawable(Color.TRANSPARENT)
        grid.setPadding(dp(10), dp(8), dp(10), dp(24))
        grid.clipToPadding = false
        grid.isVerticalScrollBarEnabled = false
        adapter = Adapter()
        grid.adapter = adapter
        grid.setOnItemClickListener { _, _, pos, _ -> pin(items[pos]) }
        grid.setOnItemLongClickListener { _, _, pos, _ ->
            showMenu(items[pos])
            true
        }
        root.addView(grid, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))
        setContentView(root)
        reload()
    }

    private fun reload() {
        Thread {
            val la = getSystemService(Context.LAUNCHER_APPS_SERVICE) as LauncherApps
            val acts: List<LauncherActivityInfo> = la.getActivityList(null, Process.myUserHandle())
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
                res.add(AppEntry(ai.label.toString(), pkg, ai.componentName, bmp))
            }
            runOnUiThread {
                items.clear()
                items.addAll(res)
                adapter.notifyDataSetChanged()
            }
        }.start()
    }

    /** Добавляет на рабочий стол ярлык со стилизованной иконкой. */
    private fun pin(e: AppEntry) {
        val bmp = e.icon ?: return
        val sm = getSystemService(ShortcutManager::class.java)
        if (sm == null || !sm.isRequestPinShortcutSupported) {
            Toast.makeText(this, "Твой рабочий стол не поддерживает добавление ярлыков", Toast.LENGTH_LONG).show()
            return
        }
        val i = Intent(Intent.ACTION_MAIN)
        i.addCategory(Intent.CATEGORY_LAUNCHER)
        i.component = e.component
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        val info = ShortcutInfo.Builder(this, "ic_" + e.pkg + "_" + System.currentTimeMillis())
            .setShortLabel(e.label)
            .setLongLabel(e.label)
            .setIcon(Icon.createWithBitmap(bmp))
            .setIntent(i)
            .build()
        sm.requestPinShortcut(info, null)
    }

    private fun showMenu(e: AppEntry) {
        val opts = arrayOf("Добавить на рабочий стол", "Своя картинка вместо иконки", "Сбросить иконку")
        AlertDialog.Builder(this)
            .setTitle(e.label)
            .setItems(opts) { _, which ->
                when (which) {
                    0 -> pin(e)
                    1 -> {
                        pendingPkg = e.pkg
                        val pick = Intent(Intent.ACTION_GET_CONTENT).setType("image/*")
                        startActivityForResult(Intent.createChooser(pick, "Выбери картинку"), REQ_PICK)
                    }
                    2 -> {
                        customFile(e.pkg).delete()
                        reload()
                    }
                }
            }
            .show()
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_PICK || resultCode != RESULT_OK) return
        val uri = data?.data ?: return
        val pkg = pendingPkg ?: return
        try {
            val src = contentResolver.openInputStream(uri).use { BitmapFactory.decodeStream(it) } ?: return
            val bmp = IconStyler.custom(src, ICON_PX)
            val f = customFile(pkg)
            f.parentFile?.mkdirs()
            FileOutputStream(f).use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
            reload()
        } catch (ex: Exception) {
            Toast.makeText(this, "Не получилось загрузить картинку", Toast.LENGTH_SHORT).show()
        }
    }

    private inner class Adapter : BaseAdapter() {
        override fun getCount(): Int = items.size
        override fun getItem(position: Int): Any = items[position]
        override fun getItemId(position: Int): Long = position.toLong()

        override fun getView(position: Int, convertView: View?, parent: ViewGroup?): View {
            val row = convertView ?: makeCell()
            val e = items[position]
            val ll = row as LinearLayout
            (ll.getChildAt(0) as ImageView).setImageBitmap(e.icon)
            (ll.getChildAt(1) as TextView).text = e.label
            return row
        }

        private fun makeCell(): View {
            val ll = LinearLayout(this@MainActivity)
            ll.orientation = LinearLayout.VERTICAL
            ll.gravity = Gravity.CENTER_HORIZONTAL
            ll.setPadding(0, dp(8), 0, dp(8))
            val iv = ImageView(this@MainActivity)
            iv.layoutParams = LinearLayout.LayoutParams(dp(64), dp(64))
            iv.scaleType = ImageView.ScaleType.FIT_CENTER
            ll.addView(iv)
            val tv = TextView(this@MainActivity)
            tv.setTextColor(0xFFE6E6E6.toInt())
            tv.textSize = 11f
            tv.maxLines = 1
            tv.ellipsize = TextUtils.TruncateAt.END
            tv.gravity = Gravity.CENTER
            tv.setPadding(dp(2), dp(4), dp(2), 0)
            ll.addView(tv)
            return ll
        }
    }

    companion object {
        private const val ICON_PX = 192
        private const val REQ_PICK = 1
    }
}
