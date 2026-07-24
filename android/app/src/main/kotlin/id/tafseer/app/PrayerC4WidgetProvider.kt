package id.tafseer.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import android.widget.RemoteViews

class PrayerC4WidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val lang = WidgetStrings.resolveLanguage(prefs)
            val names = WidgetStrings.prayerNames(lang)

            val nextName = getSafeString(prefs, "flutter.hw_next_prayer_name", names[3])
            val countdown = getSafeString(prefs, "flutter.hw_countdown", "00:47:22")

            val p1 = getSafeString(prefs, "flutter.hw_prayer_subuh", "04:32")
            val p2 = getSafeString(prefs, "flutter.hw_prayer_dzuhur", "11:58")
            val p3 = getSafeString(prefs, "flutter.hw_prayer_ashar", "15:12")
            val p4 = getSafeString(prefs, "flutter.hw_prayer_maghrib", "17:55")
            val p5 = getSafeString(prefs, "flutter.hw_prayer_isya", "19:15")

            // Footer: "Menuju Maghrib • 00:47" or "Next Maghrib • 00:47"
            val footerLabel = if (lang == "en")
                "Next $nextName • $countdown"
            else
                "Menuju $nextName • $countdown"

            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = intent?.let {
                PendingIntent.getActivity(context, 0, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            }

            for (appWidgetId in appWidgetIds) {
                val views = RemoteViews(context.packageName, R.layout.widget_prayer_c4)
                views.setTextViewText(R.id.tv_countdown_badge, countdown)
                views.setTextViewText(R.id.tv_footer_label, footerLabel)

                // Language-aware prayer name labels
                views.setTextViewText(R.id.tv_fp1_name, names[0])
                views.setTextViewText(R.id.tv_fp1_time, p1)
                views.setTextViewText(R.id.tv_fp2_name, names[1])
                views.setTextViewText(R.id.tv_fp2_time, p2)
                views.setTextViewText(R.id.tv_fp3_name, names[2])
                views.setTextViewText(R.id.tv_fp3_time, p3)
                views.setTextViewText(R.id.tv_fp4_name, names[3])
                views.setTextViewText(R.id.tv_fp4_time, p4)
                views.setTextViewText(R.id.tv_fp5_name, names[4])
                views.setTextViewText(R.id.tv_fp5_time, p5)

                if (pendingIntent != null) {
                    views.setOnClickPendingIntent(R.id.widget_prayer_c4_root, pendingIntent)
                }
                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
        } catch (e: Exception) {
            Log.e("PrayerC4WidgetProvider", "Error updating widget: ${e.message}", e)
        }
    }

    private fun getSafeString(prefs: SharedPreferences, key: String, default: String): String {
        return try { prefs.getString(key, default) ?: default } catch (e: Exception) { default }
    }
}
