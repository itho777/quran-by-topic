package id.tafseer.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews

class PrayerC5WidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val lang = WidgetStrings.resolveLanguage(prefs)
            val names = WidgetStrings.prayerNames(lang)

            val hijriDate = getSafeString(prefs, "flutter.hw_hijri_date", "14 Muharram 1447H")
            val location = getSafeString(prefs, "flutter.hw_location", "Jakarta")

            val p1 = getSafeString(prefs, "flutter.hw_prayer_subuh", "04:32")
            val p2 = getSafeString(prefs, "flutter.hw_prayer_dzuhur", "11:58")
            val p3 = getSafeString(prefs, "flutter.hw_prayer_ashar", "15:12")
            val p4 = getSafeString(prefs, "flutter.hw_prayer_maghrib", "17:55")
            val p5 = getSafeString(prefs, "flutter.hw_prayer_isya", "19:15")

            // Last Read data
            val surahName = getSafeString(prefs, "flutter.hw_last_surah_name", "Al-Kahf")
            val surahNo = getSafeLong(prefs, "flutter.hw_last_surah_no", 18L)
            val ayahNo = getSafeLong(prefs, "flutter.hw_last_ayah_no", 10L)
            val ayahLabel = if (lang == "en") "Verse $ayahNo" else "Ayat $ayahNo"

            // Dynamic next prayer info
            val info = PrayerHelper.calculateNextPrayer(p1, p2, p3, p4, p5, lang)

            val deeplinkIntent = Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse("tafseer://verse/$surahNo/$ayahNo")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val lastReadPendingIntent = PendingIntent.getActivity(
                context, 0, deeplinkIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val appLaunchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val appPendingIntent = appLaunchIntent?.let {
                PendingIntent.getActivity(context, 0, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            }

            val rows = listOf(R.id.row_p1, R.id.row_p2, R.id.row_p3, R.id.row_p4, R.id.row_p5)
            val dots = listOf(R.id.dot_p1, R.id.dot_p2, R.id.dot_p3, R.id.dot_p4, R.id.dot_p5)

            for (appWidgetId in appWidgetIds) {
                val views = RemoteViews(context.packageName, R.layout.widget_prayer_c5)
                views.setTextViewText(R.id.tv_hijri_date, "$hijriDate • 📍 $location")

                // Left panel: Last Read
                views.setTextViewText(R.id.tv_last_label, WidgetStrings.lastReadLabel(lang))
                views.setTextViewText(R.id.tv_surah_name, surahName)
                views.setTextViewText(R.id.tv_ayah_number, ayahLabel)
                views.setTextViewText(R.id.btn_continue, WidgetStrings.continueBtn(lang))
                views.setOnClickPendingIntent(R.id.card_last_read, lastReadPendingIntent)

                // Right panel: Prayer names & times
                views.setTextViewText(R.id.tv_p1_name, names[0])
                views.setTextViewText(R.id.tv_p1_time, p1)
                views.setTextViewText(R.id.tv_p2_name, names[1])
                views.setTextViewText(R.id.tv_p2_time, p2)
                views.setTextViewText(R.id.tv_p3_name, names[2])
                views.setTextViewText(R.id.tv_p3_time, p3)
                views.setTextViewText(R.id.tv_p4_name, names[3])
                views.setTextViewText(R.id.tv_p4_time, p4)
                views.setTextViewText(R.id.tv_p5_name, names[4])
                views.setTextViewText(R.id.tv_p5_time, p5)

                // Highlight active prayer row
                for (i in 0..4) {
                    val isCurrent = (i == info.nextIndex)
                    val bgDrawable = if (isCurrent) R.drawable.widget_card_active_emerald else 0
                    val dotColor = if (isCurrent) 0xFF10B981.toInt() else 0xFFD4A843.toInt()

                    views.setInt(rows[i], "setBackgroundResource", bgDrawable)
                    views.setTextColor(dots[i], dotColor)
                }

                if (appPendingIntent != null) {
                    views.setOnClickPendingIntent(R.id.widget_prayer_c5_root, appPendingIntent)
                }
                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
        } catch (e: Exception) {
            Log.e("PrayerC5WidgetProvider", "Error updating widget: ${e.message}", e)
        }
    }

    private fun getSafeString(prefs: SharedPreferences, key: String, default: String): String {
        return try { prefs.getString(key, default) ?: default } catch (e: Exception) { default }
    }

    private fun getSafeLong(prefs: SharedPreferences, key: String, default: Long): Long {
        return try {
            val raw = prefs.all[key]
            when (raw) {
                is Long -> raw
                is Int -> raw.toLong()
                is Number -> raw.toLong()
                is String -> raw.toLongOrNull() ?: default
                else -> default
            }
        } catch (e: Exception) {
            default
        }
    }
}
