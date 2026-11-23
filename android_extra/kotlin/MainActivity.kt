package com.lclab.qimen_compass

import android.content.Intent
import android.os.Bundle
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 取代 flutter create 產生的 MainActivity：加上手錶羅盤同步頻道 `qm/wear`（HANDOFF §12 1.3.0）。
 * Dart 端 lib/features/wear/wear_sync.dart 送 JSON → Wearable Data Layer `/qm/slots`；回傳已連線手錶數，失敗 -1。
 */
class MainActivity : FlutterActivity() {
    /** 從 Google 地圖分享進來的文字：冷啟動時先存著，Dart 呼叫 `initial` 取走；App 已開時直接送 `shared`。 */
    private var pendingShare: String? = null
    private var shareChannel: MethodChannel? = null

    private fun sharedText(i: Intent?): String? =
        if (i?.action == Intent.ACTION_SEND && i.type?.startsWith("text/") == true) i.getStringExtra(Intent.EXTRA_TEXT) else null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) sharedText(intent)?.let { pendingShare = it }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val t = sharedText(intent) ?: return
        val ch = shareChannel
        if (ch != null) ch.invokeMethod("shared", t) else pendingShare = t
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "qm/share").apply {
            setMethodCallHandler { call, result ->
                if (call.method == "initial") {
                    result.success(pendingShare)
                    pendingShare = null
                } else {
                    result.notImplemented()
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "qm/wear").setMethodCallHandler { call, result ->
            if (call.method != "sync") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            var done = false
            fun reply(n: Int) {
                if (!done) {
                    done = true
                    result.success(n)
                }
            }
            try {
                val req = PutDataMapRequest.create("/qm/slots").apply {
                    dataMap.putString("data", call.argument<String>("data") ?: "")
                    dataMap.putLong("t", System.currentTimeMillis())
                }.asPutDataRequest().setUrgent()
                Wearable.getDataClient(this).putDataItem(req)
                    .addOnSuccessListener {
                        Wearable.getNodeClient(this).connectedNodes
                            .addOnSuccessListener { nodes -> reply(nodes.size) }
                            .addOnFailureListener { reply(0) }
                    }
                    .addOnFailureListener { reply(-1) }
            } catch (e: Exception) {
                reply(-1)
            }
        }
    }
}
