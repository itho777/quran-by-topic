package id.tafseer.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews

class PrayerC5WidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        try {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, PrayerC5WidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            if (appWidgetIds != null && appWidgetIds.isNotEmpty()) {
                onUpdate(context, appWidgetManager, appWidgetIds)
            }
        } catch (e: Exception) {
            Log.e("PrayerC5WidgetProvider", "Error in onReceive: ${e.message}", e)
        }
    }

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

            val surahName = WidgetPrefHelper.getString(context, "hw_last_surah_name", "Al-Kahf")
            val surahNo = WidgetPrefHelper.getLong(context, "hw_last_surah_no", 18L)
            val ayahNo = WidgetPrefHelper.getLong(context, "hw_last_ayah_no", 10L)
            val ayahLabel = if (lang == "en") "Verse $ayahNo" else "Ayat $ayahNo"

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

                views.setTextViewText(R.id.tv_last_label, WidgetStrings.lastReadLabel(lang))
                views.setTextViewText(R.id.tv_surah_name, surahName)
                views.setTextViewText(R.id.tv_ayah_number, ayahLabel)
                views.setTextViewText(R.id.btn_continue, WidgetStrings.continueBtn(lang))
                views.setOnClickPendingIntent(R.id.card_last_read, lastReadPendingIntent)

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

                for (i in 0..4) {
                    val isCurrent = (i == info.nextIndex)
                    val bgColor = if (isCurrent) 0x2010B981.toInt() else 0x00000000
                    val dotColor = if (isCurrent) 0xFF10B981.toInt() else 0xFFD4A843.toInt()

                    views.setInt(rows[i], "setBackgroundColor", bgColor)
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
}
