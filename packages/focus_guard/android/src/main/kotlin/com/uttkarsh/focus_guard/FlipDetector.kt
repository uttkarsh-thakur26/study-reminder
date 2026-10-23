package com.uttkarsh.focus_guard

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import kotlin.math.sqrt

/**
 * Calls [onFaceDown] once the phone has lain screen down for two seconds.
 * Fires again only after it has been picked up.
 *
 * Reads gravity where the phone has that sensor, which leaves out shakes,
 * and the accelerometer otherwise. A timer checks the two seconds, as some
 * phones send few readings while the phone lies still.
 */
class FlipDetector(context: Context, private val onFaceDown: () -> Unit) : SensorEventListener {
    private val sensors = context.getSystemService(SensorManager::class.java)
    private val main = Handler(Looper.getMainLooper())
    private var downSince = 0L
    private var lastFaceDownAt = 0L
    private var fired = false

    private val confirm = Runnable { check() }

    fun start(): Boolean {
        val manager = sensors ?: return false
        val sensor = manager.getDefaultSensor(Sensor.TYPE_GRAVITY)
            ?: manager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
            ?: return false
        return manager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_UI, main)
    }

    fun stop() {
        sensors?.unregisterListener(this)
        main.removeCallbacks(confirm)
        downSince = 0
        lastFaceDownAt = 0
        fired = false
    }

    override fun onSensorChanged(event: SensorEvent) {
        val x = event.values[0]
        val y = event.values[1]
        val z = event.values[2]
        val now = SystemClock.elapsedRealtime()
        // Screen to the table, within about 35 degrees of flat.
        val faceDown = z < -8.0f && sqrt(x * x + y * y) < 5.5f
        if (!faceDown) {
            downSince = 0
            lastFaceDownAt = 0
            fired = false
            main.removeCallbacks(confirm)
            return
        }
        lastFaceDownAt = now
        if (downSince == 0L) {
            downSince = now
            main.postDelayed(confirm, HOLD_MS)
        }
        check()
    }

    private fun check() {
        if (fired || downSince == 0L) return
        val now = SystemClock.elapsedRealtime()
        // Face down for long enough, and nothing since says otherwise.
        if (now - downSince >= HOLD_MS && now - lastFaceDownAt < STALE_MS) {
            fired = true
            onFaceDown()
        } else if (!fired) {
            main.removeCallbacks(confirm)
            main.postDelayed(confirm, 250L)
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private companion object {
        const val HOLD_MS = 2000L

        /** A reading older than this no longer says the phone lies still. */
        const val STALE_MS = 5000L
    }
}
