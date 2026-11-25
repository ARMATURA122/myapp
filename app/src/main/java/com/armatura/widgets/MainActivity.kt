package com.armatura.widgets

import android.app.WallpaperManager
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.time.LocalTime
import java.time.format.DateTimeFormatter

private class Look(val name: String, val bg: Long, val accent: Long)
private val looks = listOf(
    Look("Зима", 0xFF121E3A, 0xFFFFFFFF), Look("Мята", 0xFF073B3A, 0xFF7CF5C4),
    Look("Закат", 0xFF3D1635, 0xFFFFB26B), Look("Уголь", 0xFF000000, 0xFFE0E0E0))

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val p = getSharedPreferences("style", MODE_PRIVATE)
        val manager = AppWidgetManager.getInstance(this)
        val widget = ComponentName(this, ClockWidget::class.java)
        fun refresh() = ClockWidget().onUpdate(this, manager, manager.getAppWidgetIds(widget))
        setContent {
            var bg by remember { mutableIntStateOf(p.getInt("bg", looks[0].bg.toInt())) }
            var accent by remember { mutableIntStateOf(p.getInt("accent", -1)) }
            var code by remember { mutableStateOf(p.getString("code", "{time}")!!) }
            var island by remember { mutableStateOf(p.getBoolean("island", false)) }
            MaterialTheme(colorScheme = darkColorScheme(primary = Color(accent))) {
                Surface(Modifier.fillMaxSize()) {
                    Column(Modifier.safeDrawingPadding().verticalScroll(rememberScrollState()).padding(20.dp),
                        verticalArrangement = Arrangement.spacedBy(14.dp)) {
                        Box(Modifier.fillMaxWidth().height(170.dp)
                            .background(Color(bg), RoundedCornerShape(28.dp)), Alignment.Center) {
                            val now = LocalTime.now().format(DateTimeFormatter.ofPattern("HH:mm"))
                            Text(code.replace("{time}", now), color = Color(accent), fontSize = 40.sp)
                        }
                        Text("Темы", fontSize = 20.sp)
                        looks.chunked(2).forEach { row ->
                            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                row.forEach { l ->
                                    Button(onClick = {
                                        bg = l.bg.toInt()
                                        accent = l.accent.toInt()
                                        p.edit().putInt("bg", bg).putInt("accent", accent).apply()
                                        refresh()
                                    }, modifier = Modifier.weight(1f).height(64.dp),
                                        colors = ButtonDefaults.buttonColors(
                                            containerColor = Color(l.bg), contentColor = Color(l.accent))
                                    ) { Text(l.name) }
                                }
                            }
                        }
                        Text("Свой виджет", fontSize = 20.sp)
                        OutlinedTextField(code, { code = it }, Modifier.fillMaxWidth(),
                            label = { Text("Текст, {time} это часы") })
                        Button(onClick = {
                            p.edit().putString("code", code).apply()
                            refresh()
                            if (manager.isRequestPinAppWidgetSupported)
                                manager.requestPinAppWidget(widget, null, null)
                        }) { Text("Сохранить виджет") }
                        Button(onClick = {
                            manager.requestPinAppWidget(ComponentName(this@MainActivity, AnalogWidget::class.java), null, null)
                        }) { Text("Добавить круглые часы") }
                        listOf("snow" to "Снег на экране", "lock" to "Часы на блокировке").forEach { (key, name) ->
                            var on by remember { mutableStateOf(p.getBoolean(key, key == "snow")) }
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(name, Modifier.weight(1f), fontSize = 20.sp)
                                Switch(on, { on = it; p.edit().putBoolean(key, it).apply() })
                            }
                        }
                        OutlinedButton(onClick = {
                            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        }) { Text("Включить службу эффектов") }
                        Text("Снежные обои", fontSize = 20.sp)
                        Button(onClick = {
                            startActivity(Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER).putExtra(
                                WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT,
                                ComponentName(this@MainActivity, SnowWallpaper::class.java)))
                        }) { Text("Поставить обои со снегом") }
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text("Островок с музыкой", Modifier.weight(1f), fontSize = 20.sp)
                            Switch(island, { island = it; p.edit().putBoolean("island", it).apply() })
                        }
                        OutlinedButton(onClick = {
                            startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")))
                        }) { Text("1. Разрешить поверх окон") }
                        OutlinedButton(onClick = {
                            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        }) { Text("2. Доступ к уведомлениям") }
                    }
                }
            }
        }
    }
}
