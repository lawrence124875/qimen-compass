package com.lclab.qimen_compass.wear

import android.app.Activity
import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.WindowManager
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.Wearable
import org.json.JSONObject

/**
 * 手錶羅盤（HANDOFF §12 1.3.0）：只有羅盤、沒有地圖。資料由手機 App 經 Data Layer（/qm/slots）送來 36 個時辰，
 * 這裡依時間挑出此刻的八宮門與吉凶，八門盤隨手錶方位旋轉；轉到吉方（開休生等判為吉的方位）震動一下。
 */
class WearCompassActivity : Activity(), SensorEventListener, DataClient.OnDataChangedListener {
    private lateinit var view: CompassView
    private lateinit var sensors: SensorManager
    private var rotation: Sensor? = null
    private var data: WearData? = null
    private var smoothed = Float.NaN
    private var lastBuzzSector = -1

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        view = CompassView(this)
        setContentView(view)
        sensors = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        rotation = sensors.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
    }

    override fun onResume() {
        super.onResume()
        rotation?.let { sensors.registerListener(this, it, SensorManager.SENSOR_DELAY_UI) }
        try {
            val client = Wearable.getDataClient(this)
            client.addListener(this)
            client.dataItems.addOnSuccessListener { items ->
                for (item in items) if (item.uri.path == PATH) apply(DataMapItem.fromDataItem(item).dataMap.getString("data"))
                items.release()
            }
        } catch (e: Exception) {
            // 沒有 Play 服務：顯示「打開手機同步」
        }
        refresh()
    }

    override fun onPause() {
        super.onPause()
        sensors.unregisterListener(this)
        try {
            Wearable.getDataClient(this).removeListener(this)
        } catch (e: Exception) {
        }
    }

    override fun onDataChanged(events: DataEventBuffer) {
        for (e in events) if (e.dataItem.uri.path == PATH) apply(DataMapItem.fromDataItem(e.dataItem).dataMap.getString("data"))
    }

    private fun apply(json: String?) {
        if (json.isNullOrEmpty()) return
        data = try {
            WearData(JSONObject(json))
        } catch (e: Exception) {
            null
        }
        refresh()
    }

    private fun refresh() {
        view.data = data
        view.slot = data?.slotAt(System.currentTimeMillis())
        view.invalidate()
    }

    override fun onSensorChanged(event: SensorEvent) {
        val r = FloatArray(9)
        val o = FloatArray(3)
        SensorManager.getRotationMatrixFromVector(r, event.values)
        SensorManager.getOrientation(r, o)
        val deg = ((Math.toDegrees(o[0].toDouble()) + 360) % 360).toFloat()
        smoothed = if (smoothed.isNaN()) deg else {
            var d = deg - smoothed
            if (d > 180) d -= 360
            if (d < -180) d += 360
            (smoothed + d * 0.2f + 360) % 360
        }
        // 每分鐘左右換一次時辰檢查（便宜：只比對時間）
        val slot = data?.slotAt(System.currentTimeMillis())
        if (slot !== view.slot) view.slot = slot
        view.heading = smoothed
        val sector = (((smoothed + 22.5f) % 360) / 45f).toInt()
        val good = slot != null && slot.tones[sector] > 0
        if (good && sector != lastBuzzSector) buzz()
        lastBuzzSector = if (good) sector else -1
        view.invalidate()
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        view.lowAccuracy = accuracy == SensorManager.SENSOR_STATUS_UNRELIABLE
    }

    @Suppress("DEPRECATION")
    private fun buzz() {
        try {
            val v = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            v.vibrate(VibrationEffect.createOneShot(70, VibrationEffect.DEFAULT_AMPLITUDE))
        } catch (e: Exception) {
        }
    }

    companion object {
        const val PATH = "/qm/slots"
    }
}

/** 手機送來的資料（格式見 lib/features/wear/wear_sync.dart）。八宮順序：北、東北、東、東南、南、西南、西、西北。 */
class WearData(json: JSONObject) {
    val locked = json.optBoolean("locked", false)
    private val str = json.optJSONObject("str") ?: JSONObject()
    fun s(key: String) = str.optString(key, "")
    val doors: List<String> = json.optJSONArray("doors")?.let { a -> List(a.length()) { a.getString(it) } } ?: emptyList()
    val dirs: List<String> = json.optJSONArray("dirs")?.let { a -> List(a.length()) { a.getString(it) } } ?: emptyList()
    val slots: List<Slot> = json.optJSONArray("slots")?.let { a ->
        List(a.length()) { i ->
            val o = a.getJSONObject(i)
            val p = o.getJSONArray("p")
            Slot(
                start = o.getLong("s"),
                end = o.getLong("e"),
                doorIdx = IntArray(8) { p.getJSONArray(it).getInt(0) },
                tones = IntArray(8) { p.getJSONArray(it).getInt(1) },
                best = o.optInt("b", -1),
                range = o.optString("r", ""),
            )
        }
    } ?: emptyList()

    fun slotAt(now: Long): Slot? = slots.firstOrNull { now >= it.start && now < it.end }

    class Slot(val start: Long, val end: Long, val doorIdx: IntArray, val tones: IntArray, val best: Int, val range: String)
}
