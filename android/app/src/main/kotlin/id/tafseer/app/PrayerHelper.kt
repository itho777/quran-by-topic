package id.tafseer.app

import java.util.Calendar
import java.util.Locale

object PrayerHelper {

    data class PrayerInfo(
        val nextIndex: Int,          // 0: Subuh, 1: Dzuhur, 2: Ashar, 3: Maghrib, 4: Isya
        val nextName: String,
        val nextTime: String,
        val countdownText: String    // e.g. "44 min" or "00:44:00"
    )

    private fun timeToMinutes(timeStr: String): Int {
        val parts = timeStr.split(":")
        if (parts.size >= 2) {
            val h = parts[0].trim().toIntOrNull() ?: 0
            val m = parts[1].trim().toIntOrNull() ?: 0
            return h * 60 + m
        }
        return 0
    }

    fun calculateNextPrayer(
        subuh: String,
        dzuhur: String,
        ashar: String,
        maghrib: String,
        isya: String,
        lang: String
    ): PrayerInfo {
        val times = listOf(subuh, dzuhur, ashar, maghrib, isya)
        val names = WidgetStrings.prayerNames(lang)
        val mins = times.map { timeToMinutes(it) }

        val cal = Calendar.getInstance()
        val currentMin = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)

        var nextIdx = 0
        var targetMin = mins[0] + 1440 // Subuh tomorrow

        for (i in 0..4) {
            if (currentMin < mins[i]) {
                nextIdx = i
                targetMin = mins[i]
                break
            }
        }

        val diffMin = targetMin - currentMin
        val hours = diffMin / 60
        val remainingMins = diffMin % 60

        val countdown = if (hours > 0) {
            if (lang == "en") "${hours}h ${remainingMins}m" else "${hours}j ${remainingMins}m"
        } else {
            if (lang == "en") "${remainingMins} min" else "${remainingMins} menit"
        }

        return PrayerInfo(
            nextIndex = nextIdx,
            nextName = names[nextIdx],
            nextTime = times[nextIdx],
            countdownText = countdown
        )
    }
}
