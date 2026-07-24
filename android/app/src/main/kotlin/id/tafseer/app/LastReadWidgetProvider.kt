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

class LastReadWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        try {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, LastReadWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            if (appWidgetIds != null && appWidgetIds.isNotEmpty()) {
                onUpdate(context, appWidgetManager, appWidgetIds)
            }
        } catch (e: Exception) {
            Log.e("LastReadWidgetProvider", "Error in onReceive: ${e.message}", e)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        try {
            val lang = WidgetPrefHelper.resolveLanguage(context)

            val surahName = WidgetPrefHelper.getString(context, "hw_last_surah_name", "Al-Kahf")
            val surahNo = WidgetPrefHelper.getLong(context, "hw_last_surah_no", 18L)
            val ayahNo = WidgetPrefHelper.getLong(context, "hw_last_ayah_no", 10L)
            val progressDouble = WidgetPrefHelper.getDouble(context, "hw_last_progress", 37.0)

            val lastReadLabel = WidgetStrings.lastReadLabel(lang)
            val continueBtn = WidgetStrings.continueBtn(lang)
            val ayahLabel = if (lang == "en") "Verse $ayahNo" else "Ayat $ayahNo"

            val intent = Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse("tafseer://verse/$surahNo/$ayahNo")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }

            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            for (appWidgetId in appWidgetIds) {
                val views = RemoteViews(context.packageName, R.layout.widget_last_read)
                views.setTextViewText(R.id.tv_last_label, lastReadLabel)
                views.setTextViewText(R.id.tv_surah_name, surahName)
                views.setTextViewText(R.id.tv_ayah_number, ayahLabel)
                views.setTextViewText(R.id.tv_progress_text, "${progressDouble.toInt()}%")
                views.setTextViewText(R.id.btn_continue, continueBtn)
                views.setProgressBar(R.id.pb_progress, 100, progressDouble.toInt(), false)
                views.setOnClickPendingIntent(R.id.widget_last_read_root, pendingIntent)
                views.setOnClickPendingIntent(R.id.btn_continue, pendingIntent)
                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
        } catch (e: Exception) {
            Log.e("LastReadWidgetProvider", "Error updating widget: ${e.message}", e)
        }
    }
}
