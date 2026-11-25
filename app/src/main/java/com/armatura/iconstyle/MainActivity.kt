package com.armatura.iconstyle

import android.app.Activity
import android.app.AlertDialog
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
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

    private class AppEntry(val label: String, val pkg: String, val cls: String, val icon: Bitmap?)

    private val items = ArrayList<AppEntry>()
    private lateinit var grid: GridView
    private lateinit var adapter: Adapter
    private var pendingPkg: String? = null

    private val pkgReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            reload()
        }
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()

    private fun customFile(pkg: String): File = File(File(filesDir, "custom"), "$pkg.png")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        grid = GridView(this)
        grid.numColumns = 4
        grid.stretchMode = GridView.STRETCH_COLUMN_WIDTH
        grid.verticalSpacing = dp(6)
        grid.selector = ColorDrawable(Color.TRANSPARENT)
        grid.setBackgroundColor(Color.BLACK)
        grid.setPadding(dp(10), dp(48), dp(10), dp(32))
        grid.clipToPadding = false
        grid.isVerticalScrollBarEnabled = false
        adapter = Adapter()
        grid.adapter = adapter
        grid.setOnItemClickListener { _, _, pos, _ -> launch(items[pos]) }
        grid.setOnItemLongClickListener { _, _, pos, _ ->
            showMenu(items[pos])
            true
        }
        setContentView(grid)

        val f = IntentFilter()
        f.addAction(Intent.ACTION_PACKAGE_ADDED)
        f.addAction(Intent.ACTION_PACKAGE_REMOVED)
        f.addDataScheme("package")
        registerReceiver(pkgReceiver, f)
        reload()
    }

    override fun onDestroy() {
        unregisterReceiver(pkgReceiver)
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        grid.smoothScrollToPosition(0)
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // лаунчер: назад ничего не делает
    }

    private fun reload() {
        Thread {
            val pm = packageManager
            val q = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
            val list = pm.queryIntentActivities(q, 0)
                .filter { it.activityInfo.packageName != packageName }
                .sortedBy { it.loadLabel(pm).toString().lowercase() }
            val res = ArrayList<AppEntry>()
            for (ri in list) {
                val pkg = ri.activityInfo.packageName
                var bmp: Bitmap? = null
                val cf = customFile(pkg)
                if (cf.exists()) {
                    bmp = BitmapFactory.decodeFile(cf.absolutePath)
                }
                if (bmp == null) {
                    bmp = try {
                        IconStyler.style(ri.loadIcon(pm), ICON_PX)
                    } catch (e: Exception) {
                        null
                    }
                }
                res.add(AppEntry(ri.loadLabel(pm).toString(), pkg, ri.activityInfo.name, bmp))
            }
            runOnUiThread {
                items.clear()
                items.addAll(res)
                adapter.notifyDataSetChanged()
            }
        }.start()
    }

    private fun launch(e: AppEntry) {
        val i = Intent(Intent.ACTION_MAIN)
        i.addCategory(Intent.CATEGORY_LAUNCHER)
        i.component = ComponentName(e.pkg, e.cls)
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        try {
            startActivity(i)
        } catch (ex: Exception) {
            Toast.makeText(this, "Не удалось открыть", Toast.LENGTH_SHORT).show()
        }
    }

    private fun showMenu(e: AppEntry) {
        val opts = arrayOf("Сменить иконку (из галереи)", "Сбросить иконку", "О приложении", "Сделать лаунчером по умолчанию")
        AlertDialog.Builder(this)
            .setTitle(e.label)
            .setItems(opts) { _, which ->
                when (which) {
                    0 -> {
                        pendingPkg = e.pkg
                        val pick = Intent(Intent.ACTION_GET_CONTENT).setType("image/*")
                        startActivityForResult(Intent.createChooser(pick, "Выбери картинку"), REQ_PICK)
                    }
                    1 -> {
                        customFile(e.pkg).delete()
                        reload()
                    }
                    2 -> {
                        val i = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        i.data = Uri.parse("package:" + e.pkg)
                        startActivity(i)
                    }
                    3 -> startActivity(Intent(Settings.ACTION_HOME_SETTINGS))
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
