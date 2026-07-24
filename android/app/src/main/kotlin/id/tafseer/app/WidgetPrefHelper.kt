package id.tafseer.app

import android.content.Context
import android.content.SharedPreferences
import android.util.Log

object WidgetPrefHelper {
    private const val TAG = "WidgetPrefHelper"
    private const val APP_GROUP = "group.id.tafseer.app"
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"

    private fun getPrefsList(context: Context): List<SharedPreferences> {
        return listOf(
            context.getSharedPreferences(APP_GROUP, Context.MODE_PRIVATE),
            context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        )
    }

    fun getString(context: Context, key: String, default: String): String {
        val keysToTry = listOf(key, "flutter.$key")
        for (prefs in getPrefsList(context)) {
            for (k in keysToTry) {
                try {
                    if (prefs.contains(k)) {
                        val valStr = prefs.getString(k, null)
                        if (valStr != null) {
                            Log.d(TAG, "Found string for key '$k': $valStr")
                            return valStr
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error reading string for key '$k': ${e.message}")
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
                    if (prefs.contains(k)) {
                        val raw = prefs.all[k]
                        val parsed = when (raw) {
                            is Long -> raw
                            is Int -> raw.toLong()
                            is Number -> raw.toLong()
                            is String -> raw.toLongOrNull()
                            else -> null
                        }
                        if (parsed != null) {
                            Log.d(TAG, "Found long for key '$k': $parsed")
                            return parsed
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error reading long for key '$k': ${e.message}")
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
                    if (prefs.contains(k)) {
                        val raw = prefs.all[k]
                        val parsed = when (raw) {
                            is Double -> raw
                            is Float -> raw.toDouble()
                            is Long -> raw.toDouble()
                            is Int -> raw.toDouble()
                            is String -> raw.toDoubleOrNull()
                            else -> null
                        }
                        if (parsed != null) {
                            Log.d(TAG, "Found double for key '$k': $parsed")
                            return parsed
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error reading double for key '$k': ${e.message}")
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
