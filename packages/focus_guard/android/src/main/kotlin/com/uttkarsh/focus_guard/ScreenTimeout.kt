package com.uttkarsh.focus_guard

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings

/**
 * Locks the phone soon after a flip without Accessibility or device admin,
 * which payment apps such as Paytm refuse to run beside. The screen timeout
 * is shortened until the screen goes off, then put back, and the phone locks
 * as it always does, so fingerprint unlock keeps working. Needs "Modify
 * system settings".
 */
object ScreenTimeout {
    private const val PREFS = "focus_guard_screen"
    private const val SAVED = "timeout"

    /** Android keeps the screen on at least this long whatever is set. */
    private const val SHORT_MS = 10_000

    /** Puts the timeout back even if the screen never went off. */
    private const val GIVE_UP_MS = 60_000L

    private val main = Handler(Looper.getMainLooper())
    private var app: Context? = null
    private var screenOff: BroadcastReceiver? = null
    private val giveUp = Runnable { app?.let { restore(it) } }

    fun granted(context: Context): Boolean = Settings.System.canWrite(context)

    /** Shortens the timeout. False without the grant, or with no timeout set. */
    fun shorten(context: Context): Boolean {
        val app = context.applicationContext
        if (!granted(app)) return false
        val resolver = app.contentResolver
        val current = Settings.System.getInt(resolver, Settings.System.SCREEN_OFF_TIMEOUT, -1)
        if (current <= 0) return false
        if (current <= SHORT_MS) return true
        val prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        // On disk, so it is put back even if the app is closed first.
        if (!prefs.contains(SAVED)) prefs.edit().putInt(SAVED, current).commit()
        try {
            Settings.System.putInt(resolver, Settings.System.SCREEN_OFF_TIMEOUT, SHORT_MS)
        } catch (e: SecurityException) {
            prefs.edit().remove(SAVED).commit()
            return false
        }
        watch(app)
        return true
    }

    /** Puts the user's own timeout back, if it was shortened. */
    fun restore(context: Context) {
        val app = context.applicationContext
        main.removeCallbacks(giveUp)
        screenOff?.let { runCatching { app.unregisterReceiver(it) } }
        screenOff = null
        val prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val saved = prefs.getInt(SAVED, -1)
        if (saved <= 0) return
        try {
            Settings.System.putInt(app.contentResolver, Settings.System.SCREEN_OFF_TIMEOUT, saved)
        } catch (e: SecurityException) {
            // The grant was taken back; nothing more can be done.
        }
        prefs.edit().remove(SAVED).commit()
    }

    /**
     * Puts back a timeout left short by an app closed before the screen went
     * off. Not while this process is still waiting for the screen to go off.
     */
    fun restoreIfLeft(context: Context) {
        if (screenOff == null) restore(context)
    }

    private fun watch(context: Context) {
        app = context
        if (screenOff == null) {
            val receiver = object : BroadcastReceiver() {
                override fun onReceive(c: Context, intent: Intent) = restore(c)
            }
            val filter = IntentFilter(Intent.ACTION_SCREEN_OFF)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                context.registerReceiver(receiver, filter)
            }
            screenOff = receiver
        }
        main.removeCallbacks(giveUp)
        main.postDelayed(giveUp, GIVE_UP_MS)
    }
}
