package com.uttkarsh.study_widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle

/**
 * The "Next up" home screen widget. Draws from what the app last saved, so
 * it needs no Flutter engine; besides the system's updates it redraws on its
 * own refresh alarm, and when the clock, time zone or language changes.
 */
class StudyWidgetProvider : AppWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            StudyWidgetRenderer.ACTION_REFRESH -> {
                if (intent.hasExtra(StudyWidgetRenderer.EXTRA_FOCUS_UNTIL)) {
                    StudyWidgetStore.saveFocusUntil(
                        context,
                        intent.getLongExtra(StudyWidgetRenderer.EXTRA_FOCUS_UNTIL, 0L),
                    )
                }
                StudyWidgetRenderer.renderAll(context)
            }
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_LOCALE_CHANGED -> StudyWidgetRenderer.renderAll(context)
            else -> super.onReceive(context, intent)
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        StudyWidgetRenderer.renderAll(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        StudyWidgetRenderer.render(context, appWidgetManager, appWidgetId, newOptions)
    }

    override fun onDisabled(context: Context) {
        StudyWidgetRenderer.cancelRefresh(context)
    }
}
