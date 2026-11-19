package com.lclab.qimen_compass

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
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
