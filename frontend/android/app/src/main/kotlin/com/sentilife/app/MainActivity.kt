package com.sentilife.app

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.sentilife.app/monitoring"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startForeground" -> {
                        val title = call.argument<String>("title") ?: "SentiLife"
                        val body = call.argument<String>("body") ?: "Monitorizando..."
                        val intent = Intent(this, MonitoringForegroundService::class.java).apply {
                            putExtra(MonitoringForegroundService.EXTRA_TITLE, title)
                            putExtra(MonitoringForegroundService.EXTRA_BODY, body)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    }
                    "stopForeground" -> {
                        stopService(Intent(this, MonitoringForegroundService::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
