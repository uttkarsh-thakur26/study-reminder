package com.uttkarsh.study_widget

import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * The home screen widget for Dart. Registered in every Flutter engine,
 * including the background sync task's, so the widget can be brought up to
 * date while the app is closed.
 */
class StudyWidgetPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    PluginRegistry.NewIntentListener {
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private var binding: ActivityPluginBinding? = null

    // What the user asked for from the widget, until Dart takes it.
    private var request: String? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "study_widget")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        attach(binding)
        read(binding.activity.intent)
    }

    override fun onDetachedFromActivityForConfigChanges() = detach()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = attach(binding)

    override fun onDetachedFromActivity() = detach()

    override fun onNewIntent(intent: Intent): Boolean {
        // The app is running: tell Dart there is a request to take.
        if (read(intent)) channel.invokeMethod("request", null)
        return false
    }

    private fun attach(binding: ActivityPluginBinding) {
        this.binding = binding
        binding.addOnNewIntentListener(this)
    }

    private fun detach() {
        binding?.removeOnNewIntentListener(this)
        binding = null
    }

    /**
     * Keeps a request from the widget's "+", once. Android hands the same
     * intent back when the app is reopened from Recents or after its process
     * was stopped, so a tap already taken is ignored.
     */
    private fun read(intent: Intent?): Boolean {
        if (intent == null) return false
        val wanted: String = intent.getStringExtra(StudyWidgetRenderer.EXTRA_REQUEST) ?: return false
        val token: Long = intent.getLongExtra(StudyWidgetRenderer.EXTRA_TOKEN, 0L)
        intent.removeExtra(StudyWidgetRenderer.EXTRA_REQUEST)
        intent.removeExtra(StudyWidgetRenderer.EXTRA_TOKEN)
        if ((intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0) return false
        if (!StudyWidgetStore.take(context, token)) return false
        request = wanted
        // Hands the button a new token for the next tap.
        StudyWidgetRenderer.renderAll(context)
        return true
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "update" -> {
                StudyWidgetStore.save(context, call.argument<String>("json") ?: "")
                StudyWidgetRenderer.renderAll(context)
                result.success(null)
            }
            "takeRequest" -> {
                val taken = request
                request = null
                result.success(taken)
            }
            else -> result.notImplemented()
        }
    }
}
