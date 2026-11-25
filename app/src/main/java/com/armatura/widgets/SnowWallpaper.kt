package com.armatura.widgets

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.os.Handler
import android.os.Looper
import android.service.wallpaper.WallpaperService
import android.view.SurfaceHolder
import kotlin.math.abs
import kotlin.random.Random

class SnowWallpaper : WallpaperService() {
    override fun onCreateEngine(): Engine = SnowEngine()

    private class Flake(var x: Float, var y: Float, val r: Float)

    inner class SnowEngine : Engine() {
        private val handler = Handler(Looper.getMainLooper())
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
        private val flakes = mutableListOf<Flake>()
        private val pile = FloatArray(60)
        private var w = 0f
        private var h = 0f
        private var lastOffset = 0f
        private var wind = 0f
        private var shown = false
        private val frame = Runnable { draw() }

        override fun onSurfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
            w = width.toFloat()
            h = height.toFloat()
            flakes.clear()
            repeat(150) {
                flakes.add(Flake(Random.nextFloat() * w, Random.nextFloat() * h, 3f + Random.nextFloat() * 6f))
            }
        }

        // перелистывание: ветер и осыпание сугроба
        override fun onOffsetsChanged(x: Float, y: Float, xs: Float, ys: Float, xp: Int, yp: Int) {
            val d = x - lastOffset
            lastOffset = x
            wind = (-d * 200f).coerceIn(-15f, 15f)
            for (i in pile.indices) pile[i] *= 1f - abs(d).coerceAtMost(0.3f)
        }

        override fun onVisibilityChanged(visible: Boolean) {
            shown = visible
            handler.removeCallbacks(frame)
            if (visible) draw()
        }

        override fun onSurfaceDestroyed(holder: SurfaceHolder) {
            shown = false
            handler.removeCallbacks(frame)
        }

        private fun draw() {
            var c: Canvas? = null
            try {
                c = surfaceHolder.lockCanvas()
                if (c != null && w > 0) {
                    c.drawColor(getSharedPreferences("style", MODE_PRIVATE).getInt("bg", Color.rgb(18, 30, 58)))
                    val col = w / pile.size
                    for (f in flakes) {
                        f.y += f.r * 0.5f
                        f.x = (f.x + wind + Random.nextFloat() * 2f - 1f + w) % w
                        val i = (f.x / col).toInt().coerceIn(0, pile.size - 1)
                        if (f.y >= h - pile[i]) {
                            if (pile[i] < h * 0.15f) {
                                pile[i] += f.r * 0.6f
                                if (i > 0) pile[i - 1] += f.r * 0.2f
                                if (i < pile.size - 1) pile[i + 1] += f.r * 0.2f
                            }
                            f.y = -f.r
                            f.x = Random.nextFloat() * w
                        }
                        c.drawCircle(f.x, f.y, f.r, paint)
                    }
                    for (i in pile.indices) c.drawRect(i * col, h - pile[i], (i + 1) * col + 1, h, paint)
                    wind *= 0.92f
                }
            } finally {
                if (c != null) surfaceHolder.unlockCanvasAndPost(c)
            }
            handler.removeCallbacks(frame)
            if (shown) handler.postDelayed(frame, 33)
        }
    }
}
