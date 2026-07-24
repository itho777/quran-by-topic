package id.tafseer.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews

class PrayerC4WidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        try {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, PrayerC4WidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            if (appWidgetIds != null && appWidgetIds.isNotEmpty()) {
                onUpdate(context, appWidgetManager, appWidgetIds)
            }
        } catch (e: Exception) {
            Log.e("PrayerC4WidgetProvider", "Error in onReceive: ${e.message}", e)
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
            val location = WidgetPrefHelper.getString(context, "hw_location", "Jakarta")

            val p1 = WidgetPrefHelper.getString(context, "hw_prayer_subuh", "04:32")
            val p2 = WidgetPrefHelper.getString(context, "hw_prayer_dzuhur", "11:58")
            val p3 = WidgetPrefHelper.getString(context, "hw_prayer_ashar", "15:12")
            val p4 = WidgetPrefHelper.getString(context, "hw_prayer_maghrib", "17:55")
            val p5 = WidgetPrefHelper.getString(context, "hw_prayer_isya", "19:15")

            val info = PrayerHelper.calculateNextPrayer(p1, p2, p3, p4, p5, lang)

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
                views.setTextViewText(R.id.tv_countdown_badge, "📍 $location")
                views.setTextViewText(R.id.tv_footer_label, footerLabel)

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

                for (i in 0..4) {
                    val isCurrent = (i == info.nextIndex)
                    val bgColor = if (isCurrent) 0x3010B981.toInt() else 0x0FFFFFFF.toInt()
                    views.setInt(frostCards[i], "setBackgroundColor", bgColor)
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
}
