package com.uttkarsh.focus_guard

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.SystemClock
import kotlin.math.abs

/**
 * Calls [onFaceDown] once the phone has lain still, screen down, for two
 * seconds. Fires again only after it has been picked up.
 */
class FlipDetector(context: Context, private val onFaceDown: () -> Unit) : SensorEventListener {
    private val sensors = context.getSystemService(SensorManager::class.java)
    private var downSince = 0L
    private var fired = false

    fun start(): Boolean {
        val manager = sensors ?: return false
        val accelerometer = manager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) ?: return false
        return manager.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_UI)
    }

    fun stop() {
        sensors?.unregisterListener(this)
        downSince = 0
        fired = false
    }

    override fun onSensorChanged(event: SensorEvent) {
        val (x, y, z) = event.values
        val faceDown = z < -8.5f && abs(x) < 2.5f && abs(y) < 2.5f
        val now = SystemClock.elapsedRealtime()
        if (!faceDown) {
            downSince = 0
            fired = false
            return
        }
        if (downSince == 0L) downSince = now
        if (!fired && now - downSince >= 2000) {
            fired = true
            onFaceDown()
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
}
