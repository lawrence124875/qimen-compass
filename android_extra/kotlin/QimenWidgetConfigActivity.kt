package com.lclab.qimen_compass

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.util.TypedValue
import android.view.ViewGroup
import android.widget.Button
import android.widget.CheckBox
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import org.json.JSONObject

/**
 * 小工具設定畫面：放小工具時（Android 11 以下）或長按小工具「重新設定」（Android 12 以上）開啟。
 * 依勾選順序決定顯示項目（小 1 項、中 3 項、大 2 項），小尺寸可設定點一下開出行訣。文字來自 App 存的 `qm_w_names`。
 */
class QimenWidgetConfigActivity : Activity() {
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private val selected = mutableListOf<String>()
    private val boxes = mutableMapOf<String, CheckBox>()
    private var updating = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        widgetId = intent?.extras?.getInt(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            ?: AppWidgetManager.INVALID_APPWIDGET_ID
        val result = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
        setResult(RESULT_CANCELED, result)
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        val p = QimenWidgetRender.prefs(this)
        val names = try {
            JSONObject(p.getString("qm_w_names", null) ?: "{}")
        } catch (e: Exception) {
            JSONObject()
        }
        val size = QimenWidgetRender.sizeOf(this, widgetId)
        val max = QimenWidgetRender.max(size)
        val (items, tapTravel) = QimenWidgetRender.config(p, widgetId, size)
        // App 還沒開過（沒有文字與資料）：用預設內容放上去
        if (names.length() == 0) {
            QimenWidgetRender.updateOne(this, widgetId)
            setResult(RESULT_OK, result)
            finish()
            return
        }
        selected.addAll(items)
        val premium = p.getBoolean("qm_w_premium", false)

        fun dp(v: Int) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics).toInt()
        val gold = Color.parseColor("#C9A45C")
        val col = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(16), dp(20), dp(12))
        }
        col.addView(TextView(this).apply {
            text = names.optString("_title")
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            setTextColor(gold)
        })
        col.addView(TextView(this).apply {
            text = names.optString("_hint$size")
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            setPadding(0, dp(4), 0, dp(8))
        })
        for (item in QimenWidgetRender.ITEMS) {
            val box = CheckBox(this).apply {
                isChecked = item in selected
                setOnCheckedChangeListener { _, on ->
                    if (updating) return@setOnCheckedChangeListener
                    if (on) {
                        if (selected.size >= max) selected.removeAt(0)
                        selected.add(item)
                    } else {
                        selected.remove(item)
                    }
                    refresh(names, premium)
                }
            }
            boxes[item] = box
            col.addView(box)
        }
        var tap = tapTravel
        if (size == QimenWidgetRender.SMALL) {
            col.addView(CheckBox(this).apply {
                text = names.optString("_tap")
                isChecked = tapTravel
                setTextColor(gold)
                setOnCheckedChangeListener { _, on -> tap = on }
            })
        }
        col.addView(Button(this).apply {
            text = names.optString("_done", "OK")
            setOnClickListener {
                QimenWidgetRender.saveConfig(this@QimenWidgetConfigActivity, widgetId, selected.toList(), tap)
                QimenWidgetRender.updateOne(this@QimenWidgetConfigActivity, widgetId)
                setResult(RESULT_OK, result)
                finish()
            }
        }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = dp(12)
        })
        refresh(names, premium)
        setContentView(ScrollView(this).apply { addView(col) })
    }

    /** 勾選的項目前面標上順序；免費版的訂閱項目標上「訂閱」。 */
    private fun refresh(names: JSONObject, premium: Boolean) {
        updating = true
        for ((item, box) in boxes) {
            val i = selected.indexOf(item)
            val lock = if (!premium && item in QimenWidgetRender.PREMIUM) " · ${names.optString("_lock")}" else ""
            box.text = (if (i >= 0) "${i + 1}. " else "") + names.optString(item, item) + lock
            box.isChecked = i >= 0
        }
        updating = false
    }
}
