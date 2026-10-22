package com.uttkarsh.study_reminder

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (openedByNotification(intent)) showOverLockScreen(true)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (openedByNotification(intent)) showOverLockScreen(true)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "study_reminder/lock_screen")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "release" -> {
                        showOverLockScreen(false)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "study_reminder/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // What paired devices call this phone, for example "Google Pixel 8".
                    "name" -> {
                        val maker = Build.MANUFACTURER.replaceFirstChar { it.uppercase() }
                        val model = Build.MODEL
                        result.success(
                            if (model.startsWith(maker, ignoreCase = true)) model else "$maker $model"
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // A ringing alarm opens the app through its full-screen intent, which can
    // happen while the phone is locked. Taps on notifications reach the app
    // only after an unlock, so allowing this for both is safe. Dart releases it
    // as soon as the launch is not an alarm, or the alarm page closes.
    private fun openedByNotification(intent: Intent?) =
        intent?.action == "SELECT_NOTIFICATION"

    private fun showOverLockScreen(on: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(on)
            setTurnScreenOn(on)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (on) window.addFlags(flags) else window.clearFlags(flags)
        }
    }
}
