package id.tafseer.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

class PrayerC2WidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        val countdown = prefs.getString("flutter.hw_countdown", "-")
        val hijriDate = prefs.getString("flutter.hw_hijri_date", "")

        val p1 = prefs.getString("flutter.hw_prayer_subuh", "-")
        val p2 = prefs.getString("flutter.hw_prayer_dzuhur", "-")
        val p3 = prefs.getString("flutter.hw_prayer_ashar", "-")
        val p4 = prefs.getString("flutter.hw_prayer_maghrib", "-")
        val p5 = prefs.getString("flutter.hw_prayer_isya", "-")

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_prayer_c2)
            views.setTextViewText(R.id.tv_hijri_date, hijriDate)
            views.setTextViewText(R.id.tv_countdown_label, countdown)

            views.setTextViewText(R.id.tv_p1_name, "Subuh")
            views.setTextViewText(R.id.tv_p1_time, p1)
            views.setTextViewText(R.id.tv_p2_name, "Dzuhur")
            views.setTextViewText(R.id.tv_p2_time, p2)
            views.setTextViewText(R.id.tv_p3_name, "Ashar")
            views.setTextViewText(R.id.tv_p3_time, p3)
            views.setTextViewText(R.id.tv_p4_name, "Maghrib")
            views.setTextViewText(R.id.tv_p4_time, p4)
            views.setTextViewText(R.id.tv_p5_name, "Isya")
            views.setTextViewText(R.id.tv_p5_time, p5)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
