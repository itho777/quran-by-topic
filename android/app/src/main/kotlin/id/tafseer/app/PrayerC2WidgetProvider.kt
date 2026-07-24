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
            val lang = WidgetPrefHelper.resolveLanguage(context)
            val names = WidgetStrings.prayerNames(lang)

            val hijriDate = WidgetPrefHelper.getString(context, "hw_hijri_date", "14 Muharram 1447H")
            val location = WidgetPrefHelper.getString(context, "hw_location", "Jakarta")

            val p1 = WidgetPrefHelper.getString(context, "hw_prayer_subuh", "04:32")
            val p2 = WidgetPrefHelper.getString(context, "hw_prayer_dzuhur", "11:58")
            val p3 = WidgetPrefHelper.getString(context, "hw_prayer_ashar", "15:12")
            val p4 = WidgetPrefHelper.getString(context, "hw_prayer_maghrib", "17:55")
            val p5 = WidgetPrefHelper.getString(context, "hw_prayer_isya", "19:15")

            // Calculate active prayer dynamically
            val info = PrayerHelper.calculateNextPrayer(p1, p2, p3, p4, p5, lang)

            val countdownLabel = if (lang == "en")
                "⏱ ${info.countdownText} to ${info.nextName}"
            else
                "⏱ ${info.countdownText} menuju ${info.nextName}"

            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = intent?.let {
                PendingIntent.getActivity(context, 0, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            }

            val cards = listOf(R.id.card_p1, R.id.card_p2, R.id.card_p3, R.id.card_p4, R.id.card_p5)
            val icons = listOf(R.id.ic_p1, R.id.ic_p2, R.id.ic_p3, R.id.ic_p4, R.id.ic_p5)

            for (appWidgetId in appWidgetIds) {
                val views = RemoteViews(context.packageName, R.layout.widget_prayer_c2)
                views.setTextViewText(R.id.tv_hijri_date, hijriDate)
                views.setTextViewText(R.id.tv_location, "📍 $location")
                views.setTextViewText(R.id.tv_countdown_label, countdownLabel)

                // Prayer names & times
                views.setTextViewText(R.id.tv_p1_name, names[0])
                views.setTextViewText(R.id.tv_p1_time, p1)
                views.setTextViewText(R.id.tv_p2_name, names[1])
                views.setTextViewText(R.id.tv_p2_time, p2)
                views.setTextViewText(R.id.tv_p3_name, names[2])
                views.setTextViewText(R.id.tv_p3_time, p3)
                views.setTextViewText(R.id.tv_p4_name, names[4 - 1]) // names[3]
                views.setTextViewText(R.id.tv_p4_time, p4)
                views.setTextViewText(R.id.tv_p5_name, names[4])
                views.setTextViewText(R.id.tv_p5_time, p5)

                // Highlight active card
                for (i in 0..4) {
                    val isCurrent = (i == info.nextIndex)
                    val bgColor = if (isCurrent) 0x35D4A843.toInt() else 0x15FFFFFF.toInt()
                    val iconColor = if (isCurrent) 0xFFD4A843.toInt() else 0xFF8B9BAD.toInt()

                    views.setInt(cards[i], "setBackgroundColor", bgColor)
                    views.setTextColor(icons[i], iconColor)
                }

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
        return try { prefs.getString(key, default) ?: default } catch (e: Exception) { default }
    }
}
