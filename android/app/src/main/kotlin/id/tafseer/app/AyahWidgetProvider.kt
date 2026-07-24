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

class AyahWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val lang = WidgetStrings.resolveLanguage(prefs)

            val arabic = getSafeString(prefs, "flutter.hw_ayah_arabic", "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ")
            val translation = getSafeString(prefs, "flutter.hw_ayah_translation",
                if (lang == "en") "In the name of Allah, the Most Gracious, the Most Merciful."
                else "Dengan nama Allah Yang Maha Pengasih, Maha Penyayang.")
            val ref = getSafeString(prefs, "flutter.hw_ayah_surah_ref", "Al-Fatihah: 1")
            val surahNo = getSafeLong(prefs, "flutter.hw_ayah_surah_no", 1L)
            val ayahNo = getSafeLong(prefs, "flutter.hw_ayah_ayah_no", 1L)

            val intent = Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse("tafseer://verse/$surahNo/$ayahNo")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }

            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            for (appWidgetId in appWidgetIds) {
                val views = RemoteViews(context.packageName, R.layout.widget_ayah)
                // Language-aware label
                views.setTextViewText(R.id.tv_ayah_label, WidgetStrings.ayahLabel(lang))
                views.setTextViewText(R.id.tv_arabic, arabic)
                views.setTextViewText(R.id.tv_translation, translation)
                views.setTextViewText(R.id.tv_surah_ref, ref)
                views.setOnClickPendingIntent(R.id.widget_ayah_root, pendingIntent)
                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
        } catch (e: Exception) {
            Log.e("AyahWidgetProvider", "Error updating widget: ${e.message}", e)
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
