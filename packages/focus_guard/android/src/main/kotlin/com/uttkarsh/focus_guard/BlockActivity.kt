package com.uttkarsh.focus_guard

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.window.OnBackInvokedDispatcher
import java.util.Date

/** Covers a blocked app until the user leaves it. */
class BlockActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var detail: TextView
    private var endsAt = 0L
    private var breakNext = false

    private val tick = object : Runnable {
        override fun run() {
            if (System.currentTimeMillis() >= endsAt || !FocusController.isRunning(this@BlockActivity)) {
                finish()
                return
            }
            detail.text = detailText()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(buildLayout())
        bind(intent)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            onBackInvokedDispatcher.registerOnBackInvokedCallback(
                OnBackInvokedDispatcher.PRIORITY_DEFAULT,
            ) { goHome() }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        bind(intent)
    }

    override fun onResume() {
        super.onResume()
        handler.removeCallbacks(tick)
        handler.post(tick)
    }

    override fun onPause() {
        handler.removeCallbacks(tick)
        super.onPause()
    }

    // Back would return to the blocked app, so it goes home instead.
    @Deprecated("Replaced by the back callback on Android 13 and later")
    override fun onBackPressed() = goHome()

    private lateinit var heading: TextView

    private fun bind(intent: Intent) {
        endsAt = intent.getLongExtra(EXTRA_ENDS_AT, 0)
        breakNext = intent.getBooleanExtra(EXTRA_BREAK_NEXT, false)
        val app = intent.getStringExtra(EXTRA_APP) ?: "This app"
        heading.text = "$app is blocked"
        detail.text = detailText()
    }

    private fun detailText(): String {
        val left = ((endsAt - System.currentTimeMillis()) / 60000 + 1).coerceAtLeast(1)
        val at = android.text.format.DateFormat.getTimeFormat(this).format(Date(endsAt))
        if (breakNext) return "Your break starts at $at ($left min left). Stay with it until then."
        return "You're in a focus session until $at ($left min left). Stay with it."
    }

    private fun goHome() {
        startActivity(
            Intent(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_HOME)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        finish()
    }

    private fun openStudyReminder() {
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        if (launch == null) {
            goHome()
            return
        }
        startActivity(launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK).putExtra("focus_guard_open", true))
        finish()
    }

    private fun dp(value: Int) =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value.toFloat(), resources.displayMetrics).toInt()

    private fun buildLayout(): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.rgb(16, 20, 24))
            setPadding(dp(32), dp(32), dp(32), dp(32))
        }
        val icon = ImageView(this).apply {
            setImageResource(R.drawable.focus_guard_stat)
            setColorFilter(Color.rgb(129, 140, 248))
        }
        root.addView(icon, LinearLayout.LayoutParams(dp(72), dp(72)).apply { bottomMargin = dp(24) })
        heading = TextView(this).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 26f)
            gravity = Gravity.CENTER
            paint.isFakeBoldText = true
        }
        root.addView(heading)
        detail = TextView(this).apply {
            setTextColor(Color.rgb(200, 204, 214))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            gravity = Gravity.CENTER
            setLineSpacing(0f, 1.2f)
        }
        root.addView(detail, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(12) })
        val primary = Button(this).apply {
            text = "Back to studying"
            isAllCaps = false
            setTextColor(Color.rgb(16, 20, 24))
            background = GradientDrawable().apply {
                cornerRadius = dp(28).toFloat()
                setColor(Color.rgb(165, 180, 252))
            }
            setOnClickListener { openStudyReminder() }
        }
        root.addView(primary, LinearLayout.LayoutParams(-1, dp(56)).apply { topMargin = dp(40) })
        val secondary = Button(this).apply {
            text = "Go to home screen"
            isAllCaps = false
            setTextColor(Color.rgb(200, 204, 214))
            setBackgroundColor(Color.TRANSPARENT)
            setOnClickListener { goHome() }
        }
        root.addView(secondary, LinearLayout.LayoutParams(-1, dp(52)).apply { topMargin = dp(8) })
        return root
    }

    companion object {
        const val EXTRA_APP = "app"
        const val EXTRA_ENDS_AT = "endsAt"
        const val EXTRA_BREAK_NEXT = "breakNext"
        const val EXTRA_STRICT = "strict"
    }
}
