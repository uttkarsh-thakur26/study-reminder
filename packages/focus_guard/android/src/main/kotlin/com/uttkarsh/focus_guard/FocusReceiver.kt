package com.uttkarsh.focus_guard

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * The end-of-session alarm, the alarm between rounds and breaks, the retry
 * alarm, and restoring after a reboot.
 */
class FocusReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            FocusController.ACTION_END -> {
                val state = FocusState.load(context) ?: return
                // An alarm left from before the session was extended.
                if (state.endsAt > System.currentTimeMillis() + 1000) return
                FocusController.finish(context, done = true)
            }
            FocusController.ACTION_PHASE -> {
                // Kept alive until Do Not Disturb has followed the new phase.
                val pending = goAsync()
                FocusController.phaseChanged(context) { pending.finish() }
            }
            FocusController.ACTION_START -> {
                val state = FocusState.load(context) ?: return
                if (state.isOver()) {
                    FocusController.finish(context, done = true)
                } else {
                    FocusController.startService(context, state, retry = false)
                }
            }
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED ->
                FocusController.restore(context)
        }
    }
}
