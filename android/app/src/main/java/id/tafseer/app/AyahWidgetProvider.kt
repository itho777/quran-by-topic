package id.tafseer.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

class AyahWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        val arabic = prefs.getString("flutter.hw_ayah_arabic", "بِسْمِ اللَّهِ")
        val translation = prefs.getString("flutter.hw_ayah_translation", "Dengan nama Allah")
        val ref = prefs.getString("flutter.hw_ayah_ref", "Al-Fatihah: 1")
        val surahNo = prefs.getLong("flutter.hw_ayah_surah_no", 1)
        val ayahNo = prefs.getLong("flutter.hw_ayah_ayah_no", 1)

        val intent = Intent(Intent.ACTION_VIEW).apply {
            data = Uri.parse("tafseer://verse/$surahNo/$ayahNo")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
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
            
            views.setOnClickPendingIntent(R.id.tv_arabic, pendingIntent) // Need a root click ideally but this is close

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
