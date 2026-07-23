package id.tafseer.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

class LastReadWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        val surahName = prefs.getString("flutter.hw_last_surah_name", "Al-Fatihah")
        val ayahNo = prefs.getLong("flutter.hw_last_ayah_no", 1)
        val progress = prefs.getFloat("flutter.hw_last_progress", 0f)

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_last_read)
            views.setTextViewText(R.id.tv_surah_name, surahName)
            views.setTextViewText(R.id.tv_ayah_number, "Ayat $ayahNo")
            views.setTextViewText(R.id.tv_progress_text, "${progress.toInt()}%")
            views.setProgressBar(R.id.pb_progress, 100, progress.toInt(), false)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
