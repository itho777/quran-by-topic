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

class AyahWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        try {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, AyahWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            if (appWidgetIds != null && appWidgetIds.isNotEmpty()) {
                onUpdate(context, appWidgetManager, appWidgetIds)
            }
        } catch (e: Exception) {
            Log.e("AyahWidgetProvider", "Error in onReceive: ${e.message}", e)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        try {
            val lang = WidgetPrefHelper.resolveLanguage(context)

            val arabic = WidgetPrefHelper.getString(context, "hw_ayah_arabic", "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ")
            val translation = WidgetPrefHelper.getString(context, "hw_ayah_translation",
                if (lang == "en") "In the name of Allah, the Most Gracious, the Most Merciful."
                else "Dengan nama Allah Yang Maha Pengasih, Maha Penyayang.")
            val ref = WidgetPrefHelper.getString(context, "hw_ayah_surah_ref", "Al-Fatihah: 1")
            val surahNo = WidgetPrefHelper.getLong(context, "hw_ayah_surah_no", 1L)
            val ayahNo = WidgetPrefHelper.getLong(context, "hw_ayah_ayah_no", 1L)

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
}
