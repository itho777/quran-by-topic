package id.tafseer.app

import android.content.Context
import android.content.SharedPreferences
import android.util.Log

object WidgetPrefHelper {
    private const val TAG = "WidgetPrefHelper"
    private const val HOME_WIDGET_PREFS = "HomeWidgetPreferences"
    private const val APP_GROUP = "group.id.tafseer.app"
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"

    private fun getPrefsList(context: Context): List<SharedPreferences> {
        return listOf(
            context.getSharedPreferences(HOME_WIDGET_PREFS, Context.MODE_PRIVATE),
            context.getSharedPreferences(APP_GROUP, Context.MODE_PRIVATE),
            context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        )
    }

    fun getString(context: Context, key: String, default: String): String {
        val keysToTry = listOf(key, "flutter.$key")
        for (prefs in getPrefsList(context)) {
            for (k in keysToTry) {
                try {
                    val raw = prefs.all[k]
                    if (raw != null) {
                        val str = raw.toString()
                        if (str.isNotEmpty()) {
                            Log.d(TAG, "getString '$k' = '$str'")
                            return str
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "getString error for '$k': ${e.message}")
                }
            }
        }
        return default
    }

    fun getLong(context: Context, key: String, default: Long): Long {
        val keysToTry = listOf(key, "flutter.$key")
        for (prefs in getPrefsList(context)) {
            for (k in keysToTry) {
                try {
                    val raw = prefs.all[k]
                    if (raw != null) {
                        val parsed = raw.toString().toLongOrNull()
                        if (parsed != null) {
                            Log.d(TAG, "getLong '$k' = $parsed")
                            return parsed
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "getLong error for '$k': ${e.message}")
                }
            }
        }
        return default
    }

    fun getDouble(context: Context, key: String, default: Double): Double {
        val keysToTry = listOf(key, "flutter.$key")
        for (prefs in getPrefsList(context)) {
            for (k in keysToTry) {
                try {
                    val raw = prefs.all[k]
                    if (raw != null) {
                        if (raw is Long && prefs.getBoolean("home_widget.double.$k", false)) {
                            val dVal = java.lang.Double.longBitsToDouble(raw)
                            Log.d(TAG, "getDouble '$k' = $dVal (bits)")
                            return dVal
                        }
                        val parsed = raw.toString().toDoubleOrNull()
                        if (parsed != null) {
                            Log.d(TAG, "getDouble '$k' = $parsed")
                            return parsed
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "getDouble error for '$k': ${e.message}")
                }
            }
        }
        return default
    }

    fun resolveLanguage(context: Context): String {
        val lang = getString(context, "hw_language", "")
        if (lang.isNotEmpty()) return lang
        val systemLang = java.util.Locale.getDefault().language
        return if (systemLang == "en") "en" else "id"
    }
}
