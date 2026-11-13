package com.uttkarsh.study_reminder

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Channel study_reminder/updates: hands a downloaded APK to Android's
 *  installer, and opens a release page in the browser. */
class UpdateInstall(private val activity: Activity) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "install" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("bad_args", "No path", null)
                    return
                }
                result.success(install(File(path)))
            }
            // Whether "Install unknown apps" is allowed, without asking.
            "canInstall" -> result.success(activity.packageManager.canRequestPackageInstalls())
            "openUrl" -> {
                val url = call.argument<String>("url")
                try {
                    activity.startActivity(
                        Intent(Intent.ACTION_VIEW, Uri.parse(url))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                    result.success(null)
                } catch (e: Exception) {
                    result.error("no_browser", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    /** "started", or "needs_permission" after opening the "Install unknown
     *  apps" page for this app (the user allows it once). */
    private fun install(apk: File): String {
        if (!activity.packageManager.canRequestPackageInstalls()) {
            activity.startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:${activity.packageName}"),
                ),
            )
            return "needs_permission"
        }
        val uri = FileProvider.getUriForFile(
            activity,
            "${activity.packageName}.updates",
            apk,
        )
        activity.startActivity(
            Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        return "started"
    }
}
