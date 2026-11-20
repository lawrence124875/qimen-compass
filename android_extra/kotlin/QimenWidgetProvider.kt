package com.lclab.qimen_compass

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject

/** 小（2×1）：1 項。類別名稱沿用 1.0 起的版本，舊的小工具不用重放。 */
class QimenWidgetProvider : QimenWidgetBase(QimenWidgetRender.SMALL)

/** 中（4×2）：最多 3 項並排＋出行訣按鈕。 */
class QimenWidgetMediumProvider : QimenWidgetBase(QimenWidgetRender.MEDIUM)

/** 大（4×4）：迷你九宮時盤（訂閱）＋最多 2 項＋出行訣按鈕。 */
class QimenWidgetLargeProvider : QimenWidgetBase(QimenWidgetRender.LARGE)

open class QimenWidgetBase(private val size: Int) : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) QimenWidgetRender.render(context, appWidgetManager, id, size, widgetData)
        QimenWidgetRender.scheduleNext(context, javaClass, widgetData)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        QimenWidgetRender.removeConfig(context, appWidgetIds)
    }
}

/**
 * 桌面小工具繪製（HANDOFF §12 小工具自訂）。資料由 App 預算好（lib/features/widget/home_widget_sync.dart）：
 * `qm_w_items` 各項目的時段清單、`qm_w_board` 九宮盤、`qm_w_names` 介面文字、`qm_w_def` 各尺寸預設、`qm_w_cfg` 各小工具自訂。
 */
object QimenWidgetRender {
    const val SMALL = 0
    const val MEDIUM = 1
    const val LARGE = 2

    val ITEMS = listOf("door", "next", "color", "almanac", "msg", "term", "pdir", "pcolor")
    val PREMIUM = setOf("pdir", "pcolor")
    private val MAX = intArrayOf(1, 3, 2)
    private val DEFAULTS = arrayOf("door", "door,next,color", "door,next")
    private val CLASSES = arrayOf(
        QimenWidgetProvider::class.java,
        QimenWidgetMediumProvider::class.java,
        QimenWidgetLargeProvider::class.java,
    )
    private val CELL_IDS = intArrayOf(
        R.id.qm_w_p1, R.id.qm_w_p2, R.id.qm_w_p3, R.id.qm_w_p4, R.id.qm_w_p5,
        R.id.qm_w_p6, R.id.qm_w_p7, R.id.qm_w_p8, R.id.qm_w_p9,
    )

    fun max(size: Int) = MAX[size]

    fun prefs(context: Context): SharedPreferences = HomeWidgetPlugin.getData(context)

    fun sizeOf(context: Context, id: Int): Int {
        val cls = AppWidgetManager.getInstance(context).getAppWidgetInfo(id)?.provider?.className ?: return SMALL
        return CLASSES.indexOfFirst { it.name == cls }.takeIf { it >= 0 } ?: SMALL
    }

    private fun json(p: SharedPreferences, key: String): JSONObject =
        try {
            JSONObject(p.getString(key, null) ?: "{}")
        } catch (e: Exception) {
            JSONObject()
        }

    /** 這個小工具要顯示的項目與「點一下開出行訣」。 */
    fun config(p: SharedPreferences, id: Int, size: Int): Pair<List<String>, Boolean> {
        val own = json(p, "qm_w_cfg").optJSONObject(id.toString())
        val list = if (own != null && own.has("i")) {
            own.optString("i")
        } else {
            json(p, "qm_w_def").optString(size.toString(), DEFAULTS[size])
        }
        val items = list.split(',').filter { it in ITEMS }.distinct().take(MAX[size])
        return items to (own?.optBoolean("t", false) ?: false)
    }

    fun saveConfig(context: Context, id: Int, items: List<String>, tapTravel: Boolean) {
        val p = prefs(context)
        val all = json(p, "qm_w_cfg")
        all.put(id.toString(), JSONObject().put("i", items.joinToString(",")).put("t", tapTravel))
        p.edit().putString("qm_w_cfg", all.toString()).apply()
    }

    fun removeConfig(context: Context, ids: IntArray) {
        val p = prefs(context)
        val all = json(p, "qm_w_cfg")
        for (id in ids) all.remove(id.toString())
        p.edit().putString("qm_w_cfg", all.toString()).apply()
    }

    private fun launch(context: Context, uri: String) =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(uri))

    /** 找出目前時段的那一筆。 */
    private fun pick(arr: JSONArray?, now: Long): JSONObject? {
        if (arr == null) return null
        for (i in 0 until arr.length()) {
            val o = arr.optJSONObject(i) ?: continue
            if (now >= o.optLong("s") && now < o.optLong("e")) return o
        }
        return null
    }

    fun render(context: Context, mgr: AppWidgetManager, id: Int, size: Int, p: SharedPreferences = prefs(context)) {
        val now = System.currentTimeMillis()
        val pkg = context.packageName
        val names = json(p, "qm_w_names")
        val empty = names.optString("_empty", p.getString("qm_widget_empty", null) ?: "")
        val data = json(p, "qm_w_items")
        val (items, tapTravel) = config(p, id, size)
        val layout = when (size) {
            MEDIUM -> R.layout.qimen_widget_m
            LARGE -> R.layout.qimen_widget_l
            else -> R.layout.qimen_widget
        }
        val rowLayout = if (size == SMALL) R.layout.qimen_widget_row_big else R.layout.qimen_widget_col
        val views = RemoteViews(pkg, layout)
        views.removeAllViews(R.id.qm_w_rows)
        var shown = 0
        for (item in items) {
            val o = pick(data.optJSONArray(item), now) ?: continue
            val row = RemoteViews(pkg, rowLayout)
            row.setTextViewText(R.id.qm_w_label, o.optString("t"))
            row.setTextViewText(R.id.qm_w_main, o.optString("m"))
            val sub = o.optString("b")
            row.setTextViewText(R.id.qm_w_sub, sub)
            row.setViewVisibility(R.id.qm_w_sub, if (sub.isEmpty()) View.GONE else View.VISIBLE)
            val c = o.optLong("c", 0L)
            if (c > now && Build.VERSION.SDK_INT >= 24) {
                row.setChronometer(R.id.qm_w_cd, SystemClock.elapsedRealtime() + (c - now), names.optString("_left", "%s"), true)
                row.setChronometerCountDown(R.id.qm_w_cd, true)
                row.setViewVisibility(R.id.qm_w_cd, View.VISIBLE)
            } else {
                row.setViewVisibility(R.id.qm_w_cd, View.GONE)
            }
            val u = o.optString("u")
            if (u.isNotEmpty()) row.setOnClickPendingIntent(R.id.qm_w_row, launch(context, u))
            views.addView(R.id.qm_w_rows, row)
            shown++
        }
        if (shown == 0 && !(size == LARGE && items.isEmpty())) {
            val row = RemoteViews(pkg, rowLayout)
            row.setTextViewText(R.id.qm_w_label, "")
            row.setTextViewText(R.id.qm_w_main, empty)
            row.setViewVisibility(R.id.qm_w_sub, View.GONE)
            row.setViewVisibility(R.id.qm_w_cd, View.GONE)
            views.addView(R.id.qm_w_rows, row)
        }
        views.setOnClickPendingIntent(
            R.id.qm_widget_root,
            launch(context, if (tapTravel) "qimen://travel" else "qimen://open"),
        )
        if (size != SMALL) {
            views.setTextViewText(R.id.qm_w_travel, names.optString("_travel", "出行訣"))
            views.setOnClickPendingIntent(R.id.qm_w_travel, launch(context, "qimen://travel"))
        }
        if (size == LARGE) renderBoard(context, views, p, names, now)
        mgr.updateAppWidget(id, views)
    }

    private fun renderBoard(context: Context, views: RemoteViews, p: SharedPreferences, names: JSONObject, now: Long) {
        val premium = p.getBoolean("qm_w_premium", false)
        val b = if (premium) {
            try {
                pick(JSONArray(p.getString("qm_w_board", null) ?: "[]"), now)
            } catch (e: Exception) {
                null
            }
        } else {
            null
        }
        val cells = b?.optJSONArray("c")
        val hi = b?.optInt("h", 0) ?: 0
        for (i in 0 until 9) {
            val palace = i + 1
            val text = when {
                cells != null -> cells.optString(i)
                palace == 5 -> if (premium) names.optString("_empty") else names.optString("_boardLock")
                else -> ""
            }
            views.setTextViewText(CELL_IDS[i], text)
            views.setInt(
                CELL_IDS[i],
                "setBackgroundResource",
                if (palace == hi) R.drawable.qimen_widget_cell_hi else R.drawable.qimen_widget_cell,
            )
        }
        if (!premium) views.setOnClickPendingIntent(R.id.qm_w_board, launch(context, "qimen://paywall"))
    }

    /** 在下一個時段交界（最早結束的一筆）請系統再更新一次，讓時辰一換就跟著換。 */
    fun scheduleNext(context: Context, cls: Class<*>, p: SharedPreferences) {
        try {
            val now = System.currentTimeMillis()
            var next = Long.MAX_VALUE
            val data = json(p, "qm_w_items")
            for (key in ITEMS) {
                val o = pick(data.optJSONArray(key), now) ?: continue
                val e = o.optLong("e")
                if (e in (now + 1) until next) next = e
            }
            if (next == Long.MAX_VALUE) return
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, cls))
            if (ids.isEmpty()) return
            val intent = Intent(context, cls).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            var flags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= 23) flags = flags or PendingIntent.FLAG_IMMUTABLE
            val pi = PendingIntent.getBroadcast(context, cls.name.hashCode(), intent, flags)
            val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarm.set(AlarmManager.RTC, next + 5_000, pi)
        } catch (e: Exception) {
            // 排不到就等系統每 30 分鐘的例行更新
        }
    }

    /** 設定畫面改完後重畫這一個小工具。 */
    fun updateOne(context: Context, id: Int) {
        val size = sizeOf(context, id)
        render(context, AppWidgetManager.getInstance(context), id, size)
        scheduleNext(context, CLASSES[size], prefs(context))
    }
}
