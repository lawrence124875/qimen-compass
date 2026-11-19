package com.lclab.qimen_compass

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

/** 桌面小工具：此刻吉門方位。資料由 App 預先算好 7 天（qm_widget_slots），這裡只依時間挑選。 */
class QimenWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val now = System.currentTimeMillis()
        val title = widgetData.getString("qm_widget_title", null) ?: "Qimen"
        var line1 = widgetData.getString("qm_widget_empty", null) ?: ""
        var line2 = ""
        try {
            val arr = JSONArray(widgetData.getString("qm_widget_slots", null) ?: "[]")
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                if (now >= o.getLong("s") && now < o.getLong("e")) {
                    line1 = o.getString("a")
                    line2 = o.getString("b")
                    break
                }
            }
        } catch (e: Exception) {
            // 資料壞掉時顯示「打開 App 更新」
        }
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.qimen_widget).apply {
                setTextViewText(R.id.qm_widget_title, title)
                setTextViewText(R.id.qm_widget_line1, line1)
                setTextViewText(R.id.qm_widget_line2, line2)
                setOnClickPendingIntent(
                    R.id.qm_widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
