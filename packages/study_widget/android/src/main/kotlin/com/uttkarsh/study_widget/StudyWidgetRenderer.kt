package com.uttkarsh.study_widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.text.format.DateFormat
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import java.util.Date
import java.util.Locale

/**
 * Draws the widget from the saved data, dropping reminders whose time has
 * passed, and asks for the next redraw: when the next reminder is due, the
 * focus session ends or the day turns, whichever is first. The alarm is
 * inexact and does not wake the phone; the widget is only seen with the
 * screen on, and Android delivers it then.
 */
object StudyWidgetRenderer {
    private const val TAG = "StudyWidget"

    const val ACTION_REFRESH = "com.uttkarsh.study_widget.REFRESH"

    /**
     * On [ACTION_REFRESH]: when the phone's focus session now ends, in epoch
     * milliseconds, 0 for none. Sent by the focus plugin when a session
     * starts or ends with the app closed, so the widget need not wait for it.
     */
    const val EXTRA_FOCUS_UNTIL = "focusUntil"

    /** Extras on the app's launch intent from the "+" button. */
    const val EXTRA_REQUEST = "study_widget_request"
    const val EXTRA_TOKEN = "study_widget_token"
    const val REQUEST_QUICK_ADD = "quickAdd"

    private const val OPEN_CODE = 7401
    private const val QUICK_ADD_CODE = 7402
    private const val REFRESH_CODE = 7403

    // Sizes in dp, as in layout/study_widget.xml: 12dp padding above and
    // below, the 40dp header, the focus line with its gap, and each row.
    private const val CHROME_DP = 64
    private const val FOCUS_DP = 36
    private const val ROW_DP = 32
    private const val MAX_ROWS = 6
    private const val DEFAULT_ROWS = 3

    private const val WINDOW_MS = 60_000L

    private val ROWS = intArrayOf(
        R.id.study_widget_row_0,
        R.id.study_widget_row_1,
        R.id.study_widget_row_2,
        R.id.study_widget_row_3,
        R.id.study_widget_row_4,
        R.id.study_widget_row_5,
    )
    private val DOTS = intArrayOf(
        R.id.study_widget_dot_0,
        R.id.study_widget_dot_1,
        R.id.study_widget_dot_2,
        R.id.study_widget_dot_3,
        R.id.study_widget_dot_4,
        R.id.study_widget_dot_5,
    )
    private val TITLES = intArrayOf(
        R.id.study_widget_title_0,
        R.id.study_widget_title_1,
        R.id.study_widget_title_2,
        R.id.study_widget_title_3,
        R.id.study_widget_title_4,
        R.id.study_widget_title_5,
    )
    private val TIMES = intArrayOf(
        R.id.study_widget_time_0,
        R.id.study_widget_time_1,
        R.id.study_widget_time_2,
        R.id.study_widget_time_3,
        R.id.study_widget_time_4,
        R.id.study_widget_time_5,
    )

    /** Redraws every placed widget. Cancels the refresh alarm when there is none. */
    fun renderAll(context: Context) {
        try {
            val manager: AppWidgetManager = AppWidgetManager.getInstance(context) ?: return
            val ids: IntArray = manager.getAppWidgetIds(ComponentName(context, StudyWidgetProvider::class.java))
            if (ids.isEmpty()) {
                cancelRefresh(context)
                return
            }
            val data = StudyWidgetStore.load(context)
            val now = System.currentTimeMillis()
            val token = StudyWidgetStore.token(context)
            for (id in ids) {
                manager.updateAppWidget(id, build(context, data, now, token, manager.getAppWidgetOptions(id)))
            }
            scheduleRefresh(context, data, now)
        } catch (e: RuntimeException) {
            Log.w(TAG, "Could not draw the widget", e)
        }
    }

    /** Redraws one widget, for example after the user resized it. */
    fun render(context: Context, manager: AppWidgetManager, id: Int, options: Bundle?) {
        try {
            val data = StudyWidgetStore.load(context)
            val now = System.currentTimeMillis()
            manager.updateAppWidget(id, build(context, data, now, StudyWidgetStore.token(context), options))
            scheduleRefresh(context, data, now)
        } catch (e: RuntimeException) {
            Log.w(TAG, "Could not draw the widget", e)
        }
    }

    // The host may apply these onto the views it already shows, so every
    // view state is set each time, never left to the layout's defaults.
    private fun build(
        context: Context,
        data: StudyWidgetData,
        now: Long,
        token: Long,
        options: Bundle?,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.study_widget)

        val open = openApp(context, quickAdd = false, token = 0L)
        if (open != null) {
            views.setOnClickPendingIntent(android.R.id.background, open)
            views.setOnClickPendingIntent(R.id.study_widget_header, open)
        }
        val add = openApp(context, quickAdd = true, token = token)
        if (add != null) views.setOnClickPendingIntent(R.id.study_widget_add, add)

        val focusing = data.focusing(now)
        if (focusing) {
            views.setViewVisibility(R.id.study_widget_focus, View.VISIBLE)
            views.setTextViewText(
                R.id.study_widget_focus_text,
                context.getString(R.string.study_widget_focusing, clock(context, data.focusUntil)),
            )
            val base: Long = SystemClock.elapsedRealtime() + (data.focusUntil - now)
            views.setChronometerCountDown(R.id.study_widget_focus_timer, true)
            views.setChronometer(R.id.study_widget_focus_timer, base, null, true)
        } else {
            views.setViewVisibility(R.id.study_widget_focus, View.GONE)
            views.setChronometer(R.id.study_widget_focus_timer, SystemClock.elapsedRealtime(), null, false)
        }

        val items = data.upcoming(now)
        val shown: Int = minOf(rowsFor(context, options, focusing), items.size)
        for (i in 0 until MAX_ROWS) {
            if (i < shown) {
                val item = items[i]
                views.setViewVisibility(ROWS[i], View.VISIBLE)
                views.setTextViewText(TITLES[i], item.title)
                views.setTextViewText(TIMES[i], label(context, item.at, now))
                // 0 keeps the dot's own accent colour.
                views.setInt(DOTS[i], "setColorFilter", item.color)
            } else {
                views.setViewVisibility(ROWS[i], View.GONE)
            }
        }
        views.setViewVisibility(R.id.study_widget_empty, if (items.isEmpty()) View.VISIBLE else View.GONE)
        return views
    }

    /** How many rows fit the widget's height. */
    private fun rowsFor(context: Context, options: Bundle?, focusing: Boolean): Int {
        if (options == null) return DEFAULT_ROWS
        // Launchers report a range: the widget is the tallest in portrait
        // and the shortest in landscape.
        val landscape = context.resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
        val height: Int = if (landscape) {
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        } else {
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
        }
        if (height <= 0) return DEFAULT_ROWS
        val free: Int = height - CHROME_DP - (if (focusing) FOCUS_DP else 0)
        return (free / ROW_DP).coerceIn(1, MAX_ROWS)
    }

    /** "7:00 PM", "Tomorrow 9:00 AM", "Fri 6:30 PM" or "29 Oct 6:30 PM". */
    private fun label(context: Context, at: Long, now: Long): String {
        val zone: ZoneId = ZoneId.systemDefault()
        val today: LocalDate = Instant.ofEpochMilli(now).atZone(zone).toLocalDate()
        val day: LocalDate = Instant.ofEpochMilli(at).atZone(zone).toLocalDate()
        val days: Long = ChronoUnit.DAYS.between(today, day)
        val time = clock(context, at)
        return when {
            days <= 0L -> time
            days == 1L -> context.getString(R.string.study_widget_tomorrow, time)
            days < 7L -> context.getString(R.string.study_widget_day_time, dayName("EEE", at), time)
            else -> context.getString(R.string.study_widget_day_time, dayName("MMMd", at), time)
        }
    }

    private fun dayName(skeleton: String, at: Long): String {
        val pattern = DateFormat.getBestDateTimePattern(Locale.getDefault(), skeleton)
        return DateFormat.format(pattern, at).toString()
    }

    /** The time of day, in the phone's 12 or 24 hour setting. */
    private fun clock(context: Context, at: Long): String =
        DateFormat.getTimeFormat(context).format(Date(at))

    private fun openApp(context: Context, quickAdd: Boolean, token: Long): PendingIntent? {
        val launch: Intent = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return null
        if (quickAdd) {
            // Delivered to the app even when it is open already.
            launch.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP,
            )
            launch.putExtra(EXTRA_REQUEST, REQUEST_QUICK_ADD)
            launch.putExtra(EXTRA_TOKEN, token)
        } else {
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        }
        return PendingIntent.getActivity(
            context,
            if (quickAdd) QUICK_ADD_CODE else OPEN_CODE,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun scheduleRefresh(context: Context, data: StudyWidgetData, now: Long) {
        var next: Long = nextMidnight(now)
        val item = data.items.firstOrNull { it.at > now }
        if (item != null && item.at < next) next = item.at
        if (data.focusUntil > now && data.focusUntil < next) next = data.focusUntil
        val alarms: AlarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        // A second late, so the reminder counts as passed when it redraws.
        // On time when the app may set exact alarms (it does for reminders);
        // otherwise within a minute.
        val at = next + 1000L
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarms.canScheduleExactAlarms()) {
            alarms.setExact(AlarmManager.RTC, at, refreshIntent(context))
        } else {
            alarms.setWindow(AlarmManager.RTC, at, WINDOW_MS, refreshIntent(context))
        }
    }

    fun cancelRefresh(context: Context) {
        val alarms: AlarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        alarms.cancel(refreshIntent(context))
    }

    private fun refreshIntent(context: Context): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            REFRESH_CODE,
            Intent(context, StudyWidgetProvider::class.java).setAction(ACTION_REFRESH),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun nextMidnight(now: Long): Long {
        val zone: ZoneId = ZoneId.systemDefault()
        val tomorrow: LocalDate = Instant.ofEpochMilli(now).atZone(zone).toLocalDate().plusDays(1L)
        return tomorrow.atStartOfDay(zone).toInstant().toEpochMilli()
    }
}
