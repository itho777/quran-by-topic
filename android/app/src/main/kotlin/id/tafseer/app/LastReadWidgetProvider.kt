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

class LastReadWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val lang = WidgetStrings.resolveLanguage(prefs)

            val surahName = getSafeString(prefs, "flutter.hw_last_surah_name", "Al-Kahf")
            val surahNo = getSafeLong(prefs, "flutter.hw_last_surah_no", 18L)
            val ayahNo = getSafeLong(prefs, "flutter.hw_last_ayah_no", 10L)
            val progressDouble = getSafeDouble(prefs, "flutter.hw_last_progress", 37.0)

            // Language-aware labels
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

    private fun getSafeDouble(prefs: SharedPreferences, key: String, default: Double): Double {
        return try {
            val raw = prefs.all[key]
            when (raw) {
                is Double -> raw
                is Float -> raw.toDouble()
                is Long -> raw.toDouble()
                is Int -> raw.toDouble()
                is String -> raw.toDoubleOrNull() ?: default
                else -> default
            }
        } catch (e: Exception) { default }
    }
}
