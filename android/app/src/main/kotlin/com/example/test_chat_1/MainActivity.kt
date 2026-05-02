package com.example.test_chat_1

import android.app.NotificationManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.test_chat_1/notifications"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "cancelConversationNotifications" -> {
                        val tag = call.argument<String>("tag")
                        if (tag != null) {
                            cancelNotificationsWithTag(tag)
                            result.success(null)
                        } else {
                            result.error("bad_args", "missing tag", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun cancelNotificationsWithTag(tag: String) {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            for (status in nm.activeNotifications) {
                if (status.tag == tag) {
                    nm.cancel(status.tag, status.id)
                }
            }
        } else {
            @Suppress("DEPRECATION")
            nm.cancel(tag, 0)
        }
    }
}
