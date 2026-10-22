package com.uttkarsh.focus_guard

import android.app.Activity
import android.app.AppOpsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.Process
import android.provider.Settings
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.ByteArrayOutputStream

/**
 * Focus mode for Dart. Registered in every Flutter engine, including the
 * background sync task's, so a session started on another device can be
 * enforced without the app open.
 */
class FocusGuardPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    PluginRegistry.NewIntentListener {
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private lateinit var flips: EventChannel
    private var activity: Activity? = null
    private var binding: ActivityPluginBinding? = null

    // A session the user asked for from a notification, until Dart takes it.
    private var focusUntil = 0L
    private var flipDetector: FlipDetector? = null
    private val main = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "focus_guard")
        channel.setMethodCallHandler(this)
        flips = EventChannel(binding.binaryMessenger, "focus_guard/flip")
        flips.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                flipDetector?.stop()
                val detector = FlipDetector(context) { main.post { events.success("faceDown") } }
                flipDetector = detector
                if (!detector.start()) events.endOfStream()
            }

            override fun onCancel(arguments: Any?) {
                flipDetector?.stop()
                flipDetector = null
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        flips.setStreamHandler(null)
        flipDetector?.stop()
        flipDetector = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        attach(binding)
        read(binding.activity.intent)
    }

    override fun onDetachedFromActivityForConfigChanges() = detach()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = attach(binding)

    override fun onDetachedFromActivity() = detach()

    override fun onNewIntent(intent: Intent): Boolean {
        read(intent)
        return false
    }

    private fun attach(binding: ActivityPluginBinding) {
        this.binding = binding
        activity = binding.activity
        binding.addOnNewIntentListener(this)
    }

    private fun detach() {
        binding?.removeOnNewIntentListener(this)
        binding = null
        activity = null
    }

    /**
     * Keeps a request from the notification, once. Android hands the same
     * intent back when the app is reopened from Recents or after its process
     * was stopped, so a request already taken is remembered and ignored.
     */
    private fun read(intent: Intent?) {
        if (intent == null) return
        val until = intent.getLongExtra(FocusController.EXTRA_FOCUS_UNTIL, 0L)
        if (until == 0L) return
        intent.removeExtra(FocusController.EXTRA_FOCUS_UNTIL)
        if ((intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0) return
        if (!FocusState.takeRequest(context, until)) return
        focusUntil = until
        FocusController.notifications(context).cancel(FocusController.LEFT_NOTIFICATION)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "apply" -> {
                val session = call.argument<Map<String, Any?>>("session")
                FocusController.apply(
                    context,
                    call.argument<String>("version") ?: "",
                    session?.let { stateFrom(it) },
                    pushed = false,
                )
                result.success(null)
            }
            "isRunning" -> result.success(FocusController.isRunning(context))
            "setBlocklist" -> {
                FocusState.saveBlocklist(
                    context,
                    call.argument<List<String>>("packages")?.toSet() ?: emptySet(),
                    call.argument<Boolean>("blockGames") == true,
                )
                result.success(null)
            }
            "pushToken" -> pushToken(result)
            "takeFocusRequest" -> {
                val until = focusUntil
                focusUntil = 0L
                result.success(if (until == 0L) null else until)
            }
            "access" -> result.success(access())
            "open" -> result.success(open(call.argument<String>("page") ?: ""))
            "apps" -> inBackground(result) { launcherApps() }
            "icon" -> inBackground(result) { icon(call.argument<String>("package") ?: "") }
            else -> result.notImplemented()
        }
    }

    private fun stateFrom(m: Map<String, Any?>) = FocusState(
        startedAt = (m["startedAt"] as? Number)?.toLong() ?: System.currentTimeMillis(),
        endsAt = (m["endsAt"] as? Number)?.toLong() ?: 0L,
        blockApps = m["blockApps"] == true,
        quiet = m["quiet"] == true,
        strict = m["strict"] == true,
        blockGames = m["blockGames"] == true,
        packages = (m["packages"] as? List<*>)?.filterIsInstance<String>()?.toSet() ?: emptySet(),
        startedBy = m["startedBy"] as? String ?: "",
    )

    /** This phone's Firebase token, or null when there is none to be had. */
    private fun pushToken(result: MethodChannel.Result) {
        if (!FocusRemote.available(context)) {
            result.success(null)
            return
        }
        FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
            result.success(if (task.isSuccessful) task.result else null)
        }
    }

    /** Which of the grants Focus mode uses the user has given. */
    private fun access(): Map<String, Boolean> {
        val nm = FocusController.notifications(context)
        val power = context.getSystemService(PowerManager::class.java)
        return mapOf(
            "usage" to hasUsageAccess(),
            "overlay" to Settings.canDrawOverlays(context),
            "media" to MediaGuard.granted(context),
            "quiet" to nm.isNotificationPolicyAccessGranted,
            "notifications" to nm.areNotificationsEnabled(),
            "battery" to power.isIgnoringBatteryOptimizations(context.packageName),
        )
    }

    private fun hasUsageAccess(): Boolean {
        val ops = context.getSystemService(AppOpsManager::class.java)
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        } else {
            @Suppress("DEPRECATION")
            ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        }
        return if (mode == AppOpsManager.MODE_DEFAULT) {
            context.checkCallingOrSelfPermission(android.Manifest.permission.PACKAGE_USAGE_STATS) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            mode == AppOpsManager.MODE_ALLOWED
        }
    }

    /** Opens the system page where the user grants [page]. */
    private fun open(page: String): Boolean {
        val pkg = Uri.parse("package:${context.packageName}")
        val candidates = when (page) {
            "usage" -> listOf(
                Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS, pkg),
                Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS),
            )
            "overlay" -> listOf(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, pkg))
            "media" -> buildList {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    val listener = ComponentName(context, FocusMediaListener::class.java)
                    add(
                        Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS).putExtra(
                            Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                            listener.flattenToString(),
                        ),
                    )
                }
                add(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
            }
            "quiet" -> listOf(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
            "battery" -> listOf(
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, pkg),
                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
            )
            "appInfo" -> listOf(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkg))
            else -> emptyList()
        }
        for (intent in candidates) {
            try {
                val from = activity
                if (from != null) {
                    from.startActivity(intent)
                } else {
                    context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                }
                return true
            } catch (e: Exception) {
                // This phone has no such page; try the next one.
            }
        }
        return false
    }

    /** Apps with a launcher icon, except this one, sorted by name. */
    private fun launcherApps(): List<Map<String, Any>> {
        val pm = context.packageManager
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return pm.queryIntentActivities(launcher, 0)
            .map { it.activityInfo.packageName to it.loadLabel(pm).toString() }
            .filter { it.first != context.packageName }
            .distinctBy { it.first }
            .sortedBy { it.second.lowercase() }
            .map { (pkg, label) ->
                mapOf("package" to pkg, "label" to label, "game" to FocusService.isGame(pm, pkg))
            }
    }

    /** The app's icon as a 96 px PNG, or null. */
    private fun icon(pkg: String): ByteArray? {
        val drawable = try {
            context.packageManager.getApplicationIcon(pkg)
        } catch (e: PackageManager.NameNotFoundException) {
            return null
        }
        val size = 96
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, size, size)
        drawable.draw(canvas)
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        bitmap.recycle()
        return out.toByteArray()
    }

    private fun inBackground(result: MethodChannel.Result, work: () -> Any?) {
        Thread {
            var value: Any? = null
            var failure: Exception? = null
            try {
                value = work()
            } catch (e: Exception) {
                failure = e
            }
            main.post {
                val error = failure
                if (error == null) result.success(value) else result.error("focus_guard", error.message, null)
            }
        }.start()
    }
}
