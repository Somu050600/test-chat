package com.example.test_chat_1

import android.app.NotificationManager
import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val notificationsChannel = "com.example.test_chat_1/notifications"
    private val launcherChannel = "com.example.test_chat_1/launcher"

    private val prefsName = "FlutterSharedPreferences"
    /** Must match SharedPreferences key used from Dart (`flutter.` prefix is added by the plugin). */
    private val keyAlias = "flutter.selected_launcher_alias"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notificationsChannel)
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, launcherChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setLauncherAlias" -> {
                        val alias = call.argument<String>("alias")
                        if (alias != null) {
                            setLauncherAlias(alias)
                            result.success(null)
                        } else {
                            result.error("bad_args", "missing alias", null)
                        }
                    }
                    "getLauncherAlias" -> {
                        result.success(readSavedAlias())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun readSavedAlias(): String {
        val prefs = getSharedPreferences(prefsName, MODE_PRIVATE)
        return prefs.getString(keyAlias, "default") ?: "default"
    }

    private fun setLauncherAlias(aliasId: String) {
        val pm = packageManager
        val pkg = packageName
        val aliases = mapOf(
            "default" to ComponentName(pkg, "$pkg.LauncherDefault"),
            "notes" to ComponentName(pkg, "$pkg.LauncherNotes"),
            "work" to ComponentName(pkg, "$pkg.LauncherWork"),
            "private" to ComponentName(pkg, "$pkg.LauncherPrivate"),
        )
        for ((id, component) in aliases) {
            val enabled = id == aliasId
            pm.setComponentEnabledSetting(
                component,
                if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
        getSharedPreferences(prefsName, MODE_PRIVATE).edit()
            .putString(keyAlias, aliasId)
            .apply()
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
