package com.perueternno.peru_eterno

import android.appwidget.AppWidgetManager
import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Widget de pantalla de inicio con la Historia del Día y el dato
 * "¿Sabías qué?". Los datos los publica `HomeWidgetService` (Dart) cada vez
 * que `DailyStoryProvider` recalcula la historia del día.
 */
class DailyFactWidgetProvider : HomeWidgetProvider() {

    companion object {
        private const val LAUNCH_URI = "peruEterno://dailyStory"
        private const val DEFAULT_TITLE = "Perú Eterno"
        private const val DEFAULT_CALLOUT_HEADER = "¿SABÍAS QUÉ?"
        private const val DEFAULT_CALLOUT_BODY =
            "Abre la app para descubrir la historia de hoy."
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.daily_fact_widget).apply {
                setTextViewText(
                    R.id.widget_title,
                    widgetData.getString("daily_title", DEFAULT_TITLE),
                )
                setTextViewText(
                    R.id.widget_callout_header,
                    widgetData.getString("daily_callout_header", DEFAULT_CALLOUT_HEADER),
                )
                setTextViewText(
                    R.id.widget_callout_body,
                    widgetData.getString("daily_callout_body", DEFAULT_CALLOUT_BODY),
                )

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse(LAUNCH_URI),
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
