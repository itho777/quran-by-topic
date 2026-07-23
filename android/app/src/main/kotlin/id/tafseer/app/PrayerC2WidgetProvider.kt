package id.tafseer.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import android.widget.RemoteViews

class PrayerC2WidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            val nextName = getSafeString(prefs, "flutter.hw_next_prayer_name", "Maghrib")
            val countdown = getSafeString(prefs, "flutter.hw_countdown", "00:47:22")
            val hijriDate = getSafeString(prefs, "flutter.hw_hijri_date", "14 Muharram 1447H")
            val location = getSafeString(prefs, "flutter.hw_location", "Jakarta")

            val p1 = getSafeString(prefs, "flutter.hw_prayer_subuh", "04:32")
            val p2 = getSafeString(prefs, "flutter.hw_prayer_dzuhur", "11:58")
            val p3 = getSafeString(prefs, "flutter.hw_prayer_ashar", "15:12")
            val p4 = getSafeString(prefs, "flutter.hw_prayer_maghrib", "17:55")
            val p5 = getSafeString(prefs, "flutter.hw_prayer_isya", "19:15")

            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = intent?.let {
                PendingIntent.getActivity(context, 0, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            }

            for (appWidgetId in appWidgetIds) {
                val views = RemoteViews(context.packageName, R.layout.widget_prayer_c2)
                views.setTextViewText(R.id.tv_hijri_date, hijriDate)
                views.setTextViewText(R.id.tv_location, "📍 $location")
                views.setTextViewText(R.id.tv_countdown_label, "⏱ $countdown menuju $nextName")

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

                if (pendingIntent != null) {
                    views.setOnClickPendingIntent(R.id.widget_prayer_c2_root, pendingIntent)
                }

                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
        } catch (e: Exception) {
            Log.e("PrayerC2WidgetProvider", "Error updating widget: ${e.message}", e)
        }
    }

    private fun getSafeString(prefs: SharedPreferences, key: String, default: String): String {
        return try {
            prefs.getString(key, default) ?: default
        } catch (e: Exception) {
            default
        }
    }
}
