package id.tafseer.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

class PrayerC4WidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        val countdown = prefs.getString("flutter.hw_countdown", "-")

        val p1 = prefs.getString("flutter.hw_prayer_subuh", "-")
        val p2 = prefs.getString("flutter.hw_prayer_dzuhur", "-")
        val p3 = prefs.getString("flutter.hw_prayer_ashar", "-")
        val p4 = prefs.getString("flutter.hw_prayer_maghrib", "-")
        val p5 = prefs.getString("flutter.hw_prayer_isya", "-")

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_prayer_c4)
            views.setTextViewText(R.id.tv_countdown_badge, countdown)
            views.setTextViewText(R.id.tv_footer_label, "Menuju waktu sholat selanjutnya")

            views.setTextViewText(R.id.tv_fp1_name, "Subuh")
            views.setTextViewText(R.id.tv_fp1_time, p1)
            views.setTextViewText(R.id.tv_fp2_name, "Dzuhur")
            views.setTextViewText(R.id.tv_fp2_time, p2)
            views.setTextViewText(R.id.tv_fp3_name, "Ashar")
            views.setTextViewText(R.id.tv_fp3_time, p3)
            views.setTextViewText(R.id.tv_fp4_name, "Maghrib")
            views.setTextViewText(R.id.tv_fp4_time, p4)
            views.setTextViewText(R.id.tv_fp5_name, "Isya")
            views.setTextViewText(R.id.tv_fp5_time, p5)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
