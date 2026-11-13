package com.uttkarsh.focus_guard

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log

/**
 * Sound and vibration sent as an alarm, which Do Not Disturb, silent mode
 * and the phone's per-app notification settings let through. A plain
 * notification was too easy to miss as a break began: the session's own Do
 * Not Disturb could still be on as it posted, and some phones show new
 * apps' notifications without sound or a pop-up.
 */
object Chime {
    private const val TAG = "FocusGuard"

    private val main = Handler(Looper.getMainLooper())
    private var playing: Ringtone? = null

    private val alarm: AudioAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ALARM)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()

    /** Two strong pulses, as a flip starts focus. */
    fun buzz(context: Context) {
        vibrate(context, longArrayOf(0L, 220L, 140L, 220L))
    }

    /**
     * As a break begins (three pulses) or a round begins again (two), with
     * the notification sound played on the alarm volume for up to [soundMs].
     */
    fun phase(context: Context, onBreak: Boolean, soundMs: Long) {
        vibrate(
            context,
            if (onBreak) {
                longArrayOf(0L, 400L, 200L, 400L, 200L, 400L)
            } else {
                longArrayOf(0L, 300L, 200L, 300L)
            },
        )
        sound(context, soundMs)
    }

    private fun sound(context: Context, soundMs: Long) {
        val audio = context.getSystemService(AudioManager::class.java)
        if (audio != null && audio.getStreamVolume(AudioManager.STREAM_ALARM) == 0) return
        // The notification sound, or the alarm sound when that is set to
        // None. The symbolic default would stay silent then.
        val uri = RingtoneManager.getActualDefaultRingtoneUri(context, RingtoneManager.TYPE_NOTIFICATION)
            ?: RingtoneManager.getActualDefaultRingtoneUri(context, RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getActualDefaultRingtoneUri(context, RingtoneManager.TYPE_RINGTONE)
            ?: return
        main.post {
            try {
                playing?.stop()
                val ringtone = RingtoneManager.getRingtone(context, uri) ?: return@post
                ringtone.audioAttributes = alarm
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) ringtone.isLooping = true
                ringtone.play()
                playing = ringtone
                main.postDelayed({
                    ringtone.stop()
                    if (playing === ringtone) playing = null
                }, soundMs)
            } catch (e: RuntimeException) {
                Log.w(TAG, "Chime not played", e)
            }
        }
    }

    private fun vibrate(context: Context, timings: LongArray) {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Vibrator::class.java)
        } ?: return
        if (!vibrator.hasVibrator()) return
        val effect = if (vibrator.hasAmplitudeControl()) {
            val amplitudes = IntArray(timings.size) { if (it % 2 == 0) 0 else 255 }
            VibrationEffect.createWaveform(timings, amplitudes, -1)
        } else {
            VibrationEffect.createWaveform(timings, -1)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                vibrator.vibrate(effect, VibrationAttributes.createForUsage(VibrationAttributes.USAGE_ALARM))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(effect, alarm)
            }
        } catch (e: SecurityException) {
            // No vibration permission: the sound and notification still go.
        }
    }
}
