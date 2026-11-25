package com.armatura.iconstyle

import android.graphics.AdaptiveIconDrawable
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.drawable.Drawable
import android.os.Build

/** Рисует иконку в стиле "тёмное стекло + светлый серый значок". */
object IconStyler {

    fun style(src: Drawable, size: Int): Bitmap {
        val out = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val c = Canvas(out)
        val s = size.toFloat()
        val r = s * 0.26f
        val rect = RectF(2f, 2f, s - 2f, s - 2f)
        val p = Paint(Paint.ANTI_ALIAS_FLAG)

        // тёмная стеклянная плитка
        p.shader = LinearGradient(0f, 0f, 0f, s, 0xFF222224.toInt(), 0xFF050506.toInt(), Shader.TileMode.CLAMP)
        c.drawRoundRect(rect, r, r, p)
        // блик сверху
        p.shader = LinearGradient(0f, 0f, 0f, s * 0.5f, 0x2AFFFFFF, 0x00FFFFFF, Shader.TileMode.CLAMP)
        c.drawRoundRect(rect, r, r, p)
        // тонкая светлая рамка
        p.shader = null
        p.style = Paint.Style.STROKE
        p.strokeWidth = s * 0.012f
        p.color = 0x55FFFFFF
        c.drawRoundRect(rect, r, r, p)

        c.drawBitmap(glyph(src, size), 0f, 0f, null)
        return out
    }

    /** Своя картинка из галереи: обрезаем по центру и скругляем. */
    fun custom(src: Bitmap, size: Int): Bitmap {
        val side = minOf(src.width, src.height)
        val sq = Bitmap.createBitmap(src, (src.width - side) / 2, (src.height - side) / 2, side, side)
        val scaled = Bitmap.createScaledBitmap(sq, size, size, true)
        val out = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val c = Canvas(out)
        val r = size * 0.26f
        val path = Path()
        path.addRoundRect(RectF(0f, 0f, size.toFloat(), size.toFloat()), r, r, Path.Direction.CW)
        c.clipPath(path)
        c.drawBitmap(scaled, 0f, 0f, null)
        return out
    }

    private fun glyph(src: Drawable, size: Int): Bitmap {
        val raw = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val rc = Canvas(raw)
        var d: Drawable = src
        var box = (size * 0.58f).toInt()
        var mono = false
        var legacy = true
        if (src is AdaptiveIconDrawable) {
            val m = if (Build.VERSION.SDK_INT >= 33) src.monochrome else null
            val f = src.foreground
            if (m != null) {
                d = m
                mono = true
                legacy = false
                box = (size * 0.98f).toInt()
            } else if (f != null) {
                d = f
                legacy = false
                box = (size * 0.98f).toInt()
            }
        }
        val off = (size - box) / 2
        d.setBounds(off, off, off + box, off + box)
        if (legacy) {
            rc.save()
            val path = Path()
            val rr = box * 0.22f
            path.addRoundRect(RectF(off.toFloat(), off.toFloat(), (off + box).toFloat(), (off + box).toFloat()), rr, rr, Path.Direction.CW)
            rc.clipPath(path)
            d.draw(rc)
            rc.restore()
        } else {
            d.draw(rc)
        }

        val out = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val oc = Canvas(out)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        if (mono) {
            // монохромный слой: просто заливаем светлым цветом по форме
            oc.drawBitmap(raw, 0f, 0f, null)
            val fill = Paint(Paint.ANTI_ALIAS_FLAG)
            fill.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
            fill.color = 0xFFF2F2F2.toInt()
            oc.drawRect(0f, 0f, size.toFloat(), size.toFloat(), fill)
        } else {
            val avg = avgLuma(raw)
            val cm = ColorMatrix()
            cm.setSaturation(0f)
            if (avg < 0.4f) {
                cm.postConcat(ColorMatrix(floatArrayOf(
                    -1f, 0f, 0f, 0f, 255f,
                    0f, -1f, 0f, 0f, 255f,
                    0f, 0f, -1f, 0f, 255f,
                    0f, 0f, 0f, 1f, 0f)))
            }
            cm.postConcat(ColorMatrix(floatArrayOf(
                1.2f, 0f, 0f, 0f, 35f,
                0f, 1.2f, 0f, 0f, 35f,
                0f, 0f, 1.2f, 0f, 35f,
                0f, 0f, 0f, 1f, 0f)))
            paint.colorFilter = ColorMatrixColorFilter(cm)
            oc.drawBitmap(raw, 0f, 0f, paint)
        }

        // затемнение книзу: градиент белый -> серый
        val shade = Paint(Paint.ANTI_ALIAS_FLAG)
        shade.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_ATOP)
        shade.shader = LinearGradient(0f, off.toFloat(), 0f, (off + box).toFloat(), 0x00000000, 0x99000000.toInt(), Shader.TileMode.CLAMP)
        oc.drawRect(0f, 0f, size.toFloat(), size.toFloat(), shade)
        return out
    }

    private fun avgLuma(b: Bitmap): Float {
        val small = Bitmap.createScaledBitmap(b, 32, 32, true)
        var sum = 0f
        var n = 0
        for (y in 0 until 32) {
            for (x in 0 until 32) {
                val px = small.getPixel(x, y)
                if (Color.alpha(px) > 128) {
                    sum += (0.299f * Color.red(px) + 0.587f * Color.green(px) + 0.114f * Color.blue(px)) / 255f
                    n++
                }
            }
        }
        return if (n > 0) sum / n else 1f
    }
}
