package com.uttkarsh.focus_guard

import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.view.accessibility.AccessibilityEvent

/**
 * Accessibility, which Android requires before an app may lock the screen
 * the way the power button does, so fingerprint unlock keeps working. Used
 * only after a flip starts focus. It reads nothing: it asks for no events
 * and no window content.
 */
class FocusLockService : AccessibilityService() {
    override fun onServiceConnected() {
        running = this
    }

    override fun onUnbind(intent: Intent?): Boolean {
        running = null
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        running = null
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {}

    companion object {
        @Volatile
        private var running: FocusLockService? = null

        /** Whether the user has turned the service on in Accessibility. */
        fun granted(context: Context): Boolean {
            val on = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
            ) ?: return false
            val me = ComponentName(context, FocusLockService::class.java)
            return on.split(':').any { ComponentName.unflattenFromString(it) == me }
        }

        /** Locks the screen. False when the service is off, or before Android 9. */
        fun lock(): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return false
            return running?.performGlobalAction(AccessibilityService.GLOBAL_ACTION_LOCK_SCREEN) == true
        }
    }
}
