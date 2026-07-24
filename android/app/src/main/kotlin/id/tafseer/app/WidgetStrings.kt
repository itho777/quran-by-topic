package id.tafseer.app

/**
 * Bilingual string table for all home-screen widgets.
 * Language is determined by the `flutter.hw_language` SharedPreferences key
 * (written by HomeWidgetService.syncLanguage from the Flutter app).
 * Falls back to the device system locale if the key is absent.
 */
object WidgetStrings {

    // ── Prayer names ──────────────────────────────────────────────────────────

    val PRAYER_NAMES_ID = listOf("Subuh", "Dzuhur", "Ashar", "Maghrib", "Isya")
    val PRAYER_NAMES_EN = listOf("Fajr", "Dhuhr", "Asr", "Maghrib", "Isha")

    // ── Ayah widget ───────────────────────────────────────────────────────────

    const val AYAH_LABEL_ID = "✦ AYAH HARI INI"
    const val AYAH_LABEL_EN = "✦ TODAY'S VERSE"

    // ── Prayer widget ─────────────────────────────────────────────────────────

    const val NEXT_PRAYER_PREFIX_ID = "Menuju"
    const val NEXT_PRAYER_PREFIX_EN = "Next"
    const val MINUTES_SUFFIX_ID = "menit lagi"
    const val MINUTES_SUFFIX_EN = "min left"

    const val PRAYER_HEADER_ID = "Waktu Sholat"
    const val PRAYER_HEADER_EN = "Prayer Times"

    // ── Last Read widget ──────────────────────────────────────────────────────

    const val LAST_READ_LABEL_ID = "TERAKHIR DIBACA"
    const val LAST_READ_LABEL_EN = "LAST READ"
    const val CONTINUE_BTN_ID = "Lanjutkan ▶"
    const val CONTINUE_BTN_EN = "Continue ▶"
    const val SURAH_PREFIX_ID = "Surah"
    const val SURAH_PREFIX_EN = "Surah"
    const val AYAH_PREFIX_ID = "Ayat"
    const val AYAH_PREFIX_EN = "Verse"

    // ── Helper to resolve language ────────────────────────────────────────────

    /**
     * Returns "en" if the saved pref is "en", otherwise "id".
     * Also respects system locale as a fallback when no pref is saved.
     */
    fun resolveLanguage(prefs: android.content.SharedPreferences): String {
        val saved = try { prefs.getString("flutter.hw_language", null) } catch (e: Exception) { null }
        if (saved != null) return saved
        // Fallback: use system locale
        val systemLang = java.util.Locale.getDefault().language
        return if (systemLang == "en") "en" else "id"
    }

    fun prayerNames(lang: String) = if (lang == "en") PRAYER_NAMES_EN else PRAYER_NAMES_ID
    fun ayahLabel(lang: String) = if (lang == "en") AYAH_LABEL_EN else AYAH_LABEL_ID
    fun lastReadLabel(lang: String) = if (lang == "en") LAST_READ_LABEL_EN else LAST_READ_LABEL_ID
    fun continueBtn(lang: String) = if (lang == "en") CONTINUE_BTN_EN else CONTINUE_BTN_ID
    fun prayerHeader(lang: String) = if (lang == "en") PRAYER_HEADER_EN else PRAYER_HEADER_ID
    fun ayahPrefix(lang: String) = if (lang == "en") AYAH_PREFIX_EN else AYAH_PREFIX_ID
}
