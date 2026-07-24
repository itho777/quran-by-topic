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
            val location = getSafeString(prefs, "flutter.hw_location", "Jakarta")

            val p1 = getSafeString(prefs, "flutter.hw_prayer_subuh", "04:32")
            val p2 = getSafeString(prefs, "flutter.hw_prayer_dzuhur", "11:58")
            val p3 = getSafeString(prefs, "flutter.hw_prayer_ashar", "15:12")
            val p4 = getSafeString(prefs, "flutter.hw_prayer_maghrib", "17:55")
            val p5 = getSafeString(prefs, "flutter.hw_prayer_isya", "19:15")

            // Calculate active prayer dynamically
            val info = PrayerHelper.calculateNextPrayer(p1, p2, p3, p4, p5, lang)

            // Footer: "Next Dhuhr • 44 min" or "Menuju Dzuhur • 44 menit"
            val footerLabel = if (lang == "en")
                "Next ${info.nextName} • ${info.countdownText}"
            else
                "Menuju ${info.nextName} • ${info.countdownText}"

            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = intent?.let {
                PendingIntent.getActivity(context, 0, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            }

            val frostCards = listOf(
                R.id.card_frost_p1,
                R.id.card_frost_p2,
                R.id.card_frost_p3,
                R.id.card_frost_p4,
                R.id.card_frost_p5
            )

            for (appWidgetId in appWidgetIds) {
                val views = RemoteViews(context.packageName, R.layout.widget_prayer_c4)
                views.setTextViewText(R.id.tv_header, WidgetStrings.prayerHeader(lang))
                // Change top right pill to Location (as requested)
                views.setTextViewText(R.id.tv_countdown_badge, "📍 $location")
                views.setTextViewText(R.id.tv_footer_label, footerLabel)

                // Language-aware prayer names & times
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

                // Highlight active card with emerald border shape
                for (i in 0..4) {
                    val isCurrent = (i == info.nextIndex)
                    val bgDrawable = if (isCurrent) R.drawable.widget_card_active_emerald else R.drawable.widget_card_inactive
                    views.setInt(frostCards[i], "setBackgroundResource", bgDrawable)
                }

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
