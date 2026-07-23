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

            val arabic = getSafeString(prefs, "flutter.hw_ayah_arabic", "وَعَسَىٰ أَن تَكْرَهُوا شَيْئًا وَهُوَ خَيْرٌ لَّكُمْ")
            val translation = getSafeString(prefs, "flutter.hw_ayah_translation", "Dan boleh jadi kamu membenci sesuatu, padahal ia baik bagimu.")
            val ref = getSafeString(prefs, "flutter.hw_ayah_surah_ref", "Al-Baqarah: 216")
            val surahNo = getSafeLong(prefs, "flutter.hw_ayah_surah_no", 2L)
            val ayahNo = getSafeLong(prefs, "flutter.hw_ayah_ayah_no", 216L)

            val intent = Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse("tafseer://verse/$surahNo/$ayahNo")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }

            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            for (appWidgetId in appWidgetIds) {
                val views = RemoteViews(context.packageName, R.layout.widget_ayah)
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
        return try {
            prefs.getString(key, default) ?: default
        } catch (e: Exception) {
            default
        }
    }

    private fun getSafeLong(prefs: SharedPreferences, key: String, default: Long): Long {
        return try {
            prefs.getLong(key, default)
        } catch (e: Exception) {
            try {
                prefs.getInt(key, default.toInt()).toLong()
            } catch (e2: Exception) {
                try {
                    prefs.getString(key, null)?.toLongOrNull() ?: default
                } catch (e3: Exception) {
                    default
                }
            }
        }
    }
}
