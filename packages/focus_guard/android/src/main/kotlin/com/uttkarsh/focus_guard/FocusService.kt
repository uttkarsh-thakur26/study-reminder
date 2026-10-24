package com.uttkarsh.focus_guard

import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings

/**
 * Runs while a session is on. Shows the countdown notification and, when the
 * session blocks apps, checks about once a second which app is in front and
 * covers a blocked one with [BlockActivity], and keeps blocked apps from
 * playing in the background ([MediaGuard]).
 */
class FocusService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var state: FocusState? = null

    // The app in front, kept up to date from usage events since the last check.
    private var foreground: String? = null
    private var checkedUntil = 0L
    private var lastBlocked: String? = null
    private var lastBlockedAt = 0L
    private val games = HashMap<String, Boolean>()
    private var neverBlock: Set<String> = emptySet()
    private var wasOnBreak = false
    private val media by lazy {
        MediaGuard(this, handler) { app ->
            state?.let { it.blockApps && !it.phaseAt().onBreak && isBlocked(it, app) } == true
        }
    }

    private val tick = object : Runnable {
        override fun run() {
            check()
            handler.postDelayed(this, CHECK_EVERY_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val current = FocusState.load(this)
        // Must come first: Android stops an app whose service never does.
        val notification = if (current != null) {
            FocusController.sessionNotification(this, current)
        } else {
            FocusController.sessionNotification(
                this,
                FocusState(0, System.currentTimeMillis(), false, false, false, false, emptySet(), ""),
            )
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                FocusController.SESSION_NOTIFICATION,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(FocusController.SESSION_NOTIFICATION, notification)
        }
        FocusController.serviceRequestedAt = 0L
        if (current == null || current.isOver()) {
            if (current != null) FocusController.finish(this, done = true)
            stopSelf()
            return START_NOT_STICKY
        }
        if (state?.packages != current.packages || state?.blockGames != current.blockGames) {
            games.clear()
        }
        state = current
        neverBlock = protectedPackages()
        if (current.blockApps) {
            media.start()
            media.recheck()
        } else {
            media.stop()
        }
        if (checkedUntil == 0L) checkedUntil = System.currentTimeMillis() - LOOK_BACK_MS
        handler.removeCallbacks(tick)
        handler.post(tick)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        media.stop()
        super.onDestroy()
    }

    private fun check() {
        val s = state ?: return
        if (s.isOver()) {
            handler.removeCallbacks(tick)
            FocusController.finish(this, done = true)
            stopSelf()
            return
        }
        if (!s.blockApps) return
        // Nothing is blocked during a break. Once it ends, whatever blocked
        // app is playing is paused again.
        val onBreak = s.phaseAt().onBreak
        if (onBreak != wasOnBreak) {
            wasOnBreak = onBreak
            if (!onBreak) media.recheck()
        }
        if (onBreak) return
        // Notification access may have been given or taken back since the
        // session began. Media plays with the screen off too.
        media.start()
        val power = getSystemService(PowerManager::class.java)
        if (!power.isInteractive) return
        val app = currentApp() ?: return
        if (app == packageName || app in neverBlock || !isBlocked(s, app)) return
        val now = System.currentTimeMillis()
        if (app == lastBlocked && now - lastBlockedAt < 1500) return
        if (!Settings.canDrawOverlays(this)) return
        lastBlocked = app
        lastBlockedAt = now
        // The block screen comes to the front, so the next events name this app.
        foreground = packageName
        startActivity(
            Intent(this, BlockActivity::class.java)
                // Not as if the user left the app: then video apps would carry
                // on in a floating window above the block screen.
                .addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_NO_USER_ACTION,
                )
                .putExtra(BlockActivity.EXTRA_APP, label(app))
                .putExtra(BlockActivity.EXTRA_PACKAGE, app)
                .putExtra(BlockActivity.EXTRA_ENDS_AT, phase(s).endsAt)
                .putExtra(BlockActivity.EXTRA_BREAK_NEXT, phase(s).round < phase(s).rounds)
                .putExtra(BlockActivity.EXTRA_STRICT, s.strict),
        )
    }

    private fun phase(s: FocusState) = s.phaseAt()

    /** The package of the activity in front, from usage events. */
    private fun currentApp(): String? {
        val usage = getSystemService(UsageStatsManager::class.java) ?: return foreground
        val now = System.currentTimeMillis()
        // A little overlap, because events can be recorded a moment late.
        val events = try {
            usage.queryEvents(checkedUntil - 2000, now)
        } catch (e: SecurityException) {
            null
        } ?: return foreground
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            // ACTIVITY_RESUMED has the value MOVE_TO_FOREGROUND had before Android 10.
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) foreground = event.packageName
        }
        checkedUntil = now
        return foreground
    }

    private fun isBlocked(s: FocusState, app: String): Boolean {
        if (app in s.packages) return true
        if (!s.blockGames) return false
        return games.getOrPut(app) { isGame(packageManager, app) }
    }

    /** The launcher and system screens are never covered. */
    private fun protectedPackages(): Set<String> {
        val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val launchers = packageManager.queryIntentActivities(home, 0)
            .map { it.activityInfo.packageName }
        return (launchers + listOf("com.android.systemui", "android")).toSet()
    }

    private fun label(app: String): String =
        try {
            packageManager.getApplicationLabel(packageManager.getApplicationInfo(app, 0)).toString()
        } catch (e: PackageManager.NameNotFoundException) {
            app
        }

    companion object {
        private const val CHECK_EVERY_MS = 800L
        private const val LOOK_BACK_MS = 5 * 60 * 1000L

        fun isGame(pm: PackageManager, app: String): Boolean =
            try {
                pm.getApplicationInfo(app, 0).category == ApplicationInfo.CATEGORY_GAME
            } catch (e: PackageManager.NameNotFoundException) {
                false
            }
    }
}
