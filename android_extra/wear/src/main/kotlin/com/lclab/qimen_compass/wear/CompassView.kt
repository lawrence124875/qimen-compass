package com.lclab.qimen_compass.wear

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.view.View
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

/** 圓形八門盤：外圈八個扇形（吉綠、平灰、凶紅），隨方位反向旋轉；上方固定指針，中央顯示前方的門與吉凶。 */
class CompassView(context: Context) : View(context) {
    var data: WearData? = null
    var slot: WearData.Slot? = null
    var heading = 0f
    var lowAccuracy = false

    private val gold = Color.rgb(0xC9, 0xA8, 0x6A)
    private val good = Color.rgb(0x5F, 0xB3, 0x7A)
    private val neutral = Color.rgb(0x8A, 0x8A, 0x8A)
    private val bad = Color.rgb(0xD0, 0x64, 0x5A)
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val text = Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.CENTER; color = Color.WHITE }

    private fun toneColor(t: Int) = when {
        t > 0 -> good
        t == 0 -> neutral
        else -> bad
    }

    override fun onDraw(canvas: Canvas) {
        canvas.drawColor(Color.BLACK)
        val cx = width / 2f
        val cy = height / 2f
        val r = min(cx, cy) * 0.96f
        val ring = r * 0.30f
        val d = data
        val s = slot

        if (d == null || d.locked || s == null) {
            text.textSize = r * 0.11f
            text.color = Color.WHITE
            val msg = when {
                d == null -> "Qimen"
                d.locked -> d.s("locked")
                else -> d.s("open")
            }
            drawLines(canvas, if (d == null) listOf(msg, "📱 → ⌚") else listOf(msg), cx, cy, r * 0.13f)
            return
        }

        // 外圈八宮扇形：宮 i 的方位角＝i×45°，畫面上方＝前方，所以角度要減去 heading
        val oval = RectF(cx - r, cy - r, cx + r, cy + r)
        for (i in 0 until 8) {
            val center = i * 45f - heading - 90f // Canvas 0° 在右邊
            fill.color = toneColor(s.tones[i])
            fill.alpha = if (i == s.best) 230 else 150
            canvas.drawArc(oval, center - 22f, 44f, true, fill)
        }
        fill.color = Color.BLACK
        fill.alpha = 255
        canvas.drawCircle(cx, cy, r - ring, fill)
        // 最佳吉方加金框
        if (s.best in 0..7) {
            stroke.color = gold
            stroke.strokeWidth = r * 0.035f
            val c = s.best * 45f - heading - 90f
            canvas.drawArc(RectF(cx - r + stroke.strokeWidth, cy - r + stroke.strokeWidth, cx + r - stroke.strokeWidth, cy + r - stroke.strokeWidth), c - 22f, 44f, false, stroke)
        }
        // 門名（直立）
        text.color = Color.WHITE
        text.textSize = ring * 0.42f
        val labelR = r - ring / 2f
        for (i in 0 until 8) {
            val a = Math.toRadians((i * 45f - heading - 90f).toDouble())
            val x = cx + labelR * cos(a).toFloat()
            val y = cy + labelR * sin(a).toFloat() + text.textSize * 0.35f
            val idx = s.doorIdx[i]
            canvas.drawText(if (idx in d.doors.indices) d.doors[idx] else "·", x, y, text)
        }
        // 北方記號
        val na = Math.toRadians((-heading - 90f).toDouble())
        fill.color = gold
        canvas.drawCircle(cx + (r - ring - r * 0.05f) * cos(na).toFloat(), cy + (r - ring - r * 0.05f) * sin(na).toFloat(), r * 0.025f, fill)
        // 上方固定指針
        val p = Path().apply {
            moveTo(cx, cy - r + ring + r * 0.02f)
            lineTo(cx - r * 0.06f, cy - r + ring + r * 0.13f)
            lineTo(cx + r * 0.06f, cy - r + ring + r * 0.13f)
            close()
        }
        canvas.drawPath(p, fill)

        // 中央：前方的門、吉凶、方位、時段
        val sector = (((heading + 22.5f) % 360) / 45f).toInt()
        val idx = s.doorIdx[sector]
        val tone = s.tones[sector]
        val door = if (idx in d.doors.indices) d.doors[idx] else "—"
        text.color = toneColor(tone)
        text.textSize = r * 0.20f
        canvas.drawText(door, cx, cy + text.textSize * 0.15f, text)
        text.textSize = r * 0.09f
        text.color = Color.WHITE
        val toneLabel = d.s(if (tone > 0) "good" else if (tone == 0) "neutral" else "bad")
        canvas.drawText("${d.s("front")} ${d.dirs.getOrElse(sector) { "" }}・$toneLabel", cx, cy - r * 0.20f, text)
        text.color = Color.LTGRAY
        text.textSize = r * 0.075f
        canvas.drawText(s.range, cx, cy + r * 0.24f, text)
        if (lowAccuracy) {
            text.textSize = r * 0.06f
            canvas.drawText(d.s("calib"), cx, cy + r * 0.36f, text)
        }
    }

    private fun drawLines(canvas: Canvas, lines: List<String>, cx: Float, cy: Float, lh: Float) {
        val wrapped = lines.flatMap { wrap(it, 12) }
        var y = cy - (wrapped.size - 1) * lh / 2f
        for (l in wrapped) {
            canvas.drawText(l, cx, y, text)
            y += lh
        }
    }

    private fun wrap(s: String, n: Int): List<String> {
        if (s.length <= n) return listOf(s)
        val out = mutableListOf<String>()
        var i = 0
        while (i < s.length) {
            out.add(s.substring(i, min(s.length, i + n)))
            i += n
        }
        return out
    }
}
