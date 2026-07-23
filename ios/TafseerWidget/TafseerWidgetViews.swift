import WidgetKit
import SwiftUI

// MARK: - Shared App Group & Colors
let appGroupSuite = "group.id.tafseer.app"
let colorBgDark = Color(red: 13/255, green: 17/255, blue: 23/255)
let colorEmerald = Color(red: 16/255, green: 185/255, blue: 129/255)
let colorGold = Color(red: 212/255, green: 168/255, blue: 67/255)
let colorAmber = Color(red: 245/255, green: 158/255, blue: 11/255)
let colorCardDark = Color(red: 21/255, green: 31/255, blue: 46/255)

// MARK: - 1. Ayah of the Day Widget
struct AyahEntry: TimelineEntry {
    let date: Date
    let arabic: String
    let translation: String
    let surahRef: String
    let surahNo: Int
    let ayahNo: Int
}

struct AyahProvider: TimelineProvider {
    func placeholder(in context: Context) -> AyahEntry {
        AyahEntry(date: Date(), arabic: "وَعَسَىٰ أَن تَكْرَهُوا شَيْئًا وَهُوَ خَيْرٌ لَّكُمْ", translation: "Dan boleh jadi kamu membenci sesuatu, padahal ia baik bagimu.", surahRef: "Al-Baqarah: 216", surahNo: 2, ayahNo: 216)
    }

    func getSnapshot(in context: Context, completion: @escaping (AyahEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AyahEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 4, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadEntry() -> AyahEntry {
        let defaults = UserDefaults(suiteName: appGroupSuite)
        let arabic = defaults?.string(forKey: "hw_ayah_arabic") ?? "وَعَسَىٰ أَن تَكْرَهُوا شَيْئًا وَهُوَ خَيْرٌ لَّكُمْ"
        let translation = defaults?.string(forKey: "hw_ayah_translation") ?? "Dan boleh jadi kamu membenci sesuatu, padahal ia baik bagimu."
        let surahRef = defaults?.string(forKey: "hw_ayah_surah_ref") ?? "Al-Baqarah: 216"
        let surahNo = defaults?.integer(forKey: "hw_ayah_surah_no") ?? 2
        let ayahNo = defaults?.integer(forKey: "hw_ayah_ayah_no") ?? 216
        return AyahEntry(date: Date(), arabic: arabic, translation: translation, surahRef: surahRef, surahNo: surahNo, ayahNo: ayahNo)
    }
}

struct AyahWidgetView: View {
    var entry: AyahEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("✦ AYAH HARI INI")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(colorGold)
                Spacer()
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            Divider().background(colorEmerald)

            Text(entry.arabic)
                .font(.custom("Amiri", size: 16))
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(entry.translation)
                .font(.system(size: 11, weight: .regular))
                .italic()
                .foregroundColor(Color(red: 200/255, green: 185/255, blue: 122/255))
                .lineLimit(2)

            Spacer()

            HStack {
                Text("tafseer.id")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
                Spacer()
                Text(entry.surahRef)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(colorGold)
                    .cornerRadius(8)
            }
        }
        .padding(12)
        .background(colorBgDark)
        .widgetURL(URL(string: "tafseer://verse/\(entry.surahNo)/\(entry.ayahNo)"))
    }
}

struct AyahWidget: Widget {
    let kind: String = "AyahWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AyahProvider()) { entry in
            AyahWidgetView(entry: entry)
        }
        .configurationDisplayName("Ayah Hari Ini")
        .description("Ayat harian pilihan dengan terjemahan Indonesia.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - 2. Prayer Times Base Model & Entry
struct PrayerEntry: TimelineEntry {
    let date: Date
    let subuh: String
    let dzuhur: String
    let ashar: String
    let maghrib: String
    let isya: String
    let nextName: String
    let nextTime: String
    let countdown: String
    let hijriDate: String
}

struct PrayerProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrayerEntry {
        PrayerEntry(date: Date(), subuh: "04:32", dzuhur: "11:58", ashar: "15:12", maghrib: "17:55", isya: "19:15", nextName: "Maghrib", nextTime: "17:55", countdown: "00:47:22", hijriDate: "14 Muharram 1447H")
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadEntry() -> PrayerEntry {
        let defaults = UserDefaults(suiteName: appGroupSuite)
        return PrayerEntry(
            date: Date(),
            subuh: defaults?.string(forKey: "hw_prayer_subuh") ?? "04:32",
            dzuhur: defaults?.string(forKey: "hw_prayer_dzuhur") ?? "11:58",
            ashar: defaults?.string(forKey: "hw_prayer_ashar") ?? "15:12",
            maghrib: defaults?.string(forKey: "hw_prayer_maghrib") ?? "17:55",
            isya: defaults?.string(forKey: "hw_prayer_isya") ?? "19:15",
            nextName: defaults?.string(forKey: "hw_next_prayer_name") ?? "Maghrib",
            nextTime: defaults?.string(forKey: "hw_next_prayer_time") ?? "17:55",
            countdown: defaults?.string(forKey: "hw_countdown") ?? "00:47:22",
            hijriDate: defaults?.string(forKey: "hw_hijri_date") ?? "14 Muharram 1447H"
        )
    }
}

// MARK: - 3. Prayer Times C1 (Circular + List) View
struct PrayerC1View: View {
    var entry: PrayerEntry

    var body: some View {
        VStack(spacing: 6) {
            Text(entry.hijriDate)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(colorGold)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                // Circular Ring Left
                ZStack {
                    Circle()
                        .stroke(colorCardDark, lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(colorEmerald, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text(entry.nextName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        Text(entry.nextTime)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(colorGold)
                        Text(entry.countdown)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(colorAmber)
                    }
                }
                .frame(width: 80, height: 80)

                // List Right
                VStack(spacing: 4) {
                    _PrayerRow(name: "Subuh", time: entry.subuh, isActive: entry.nextName == "Subuh")
                    _PrayerRow(name: "Dzuhur", time: entry.dzuhur, isActive: entry.nextName == "Dzuhur")
                    _PrayerRow(name: "Ashar", time: entry.ashar, isActive: entry.nextName == "Ashar")
                    _PrayerRow(name: "Maghrib", time: entry.maghrib, isActive: entry.nextName == "Maghrib")
                    _PrayerRow(name: "Isya", time: entry.isya, isActive: entry.nextName == "Isya")
                }
            }
        }
        .padding(12)
        .background(colorBgDark)
    }
}

struct _PrayerRow: View {
    let name: String
    let time: String
    let isActive: Bool

    var body: some View {
        HStack {
            Text(name)
                .font(.system(size: 11, weight: isActive ? .bold : .regular))
                .foregroundColor(isActive ? .white : .gray)
            Spacer()
            Text(time)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isActive ? colorGold : .gray)
            Circle()
                .fill(isActive ? colorEmerald : Color.gray.opacity(0.3))
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(isActive ? colorEmerald.opacity(0.15) : Color.clear)
        .cornerRadius(6)
    }
}

struct PrayerC1Widget: Widget {
    let kind: String = "PrayerC1Widget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerProvider()) { entry in
            PrayerC1View(entry: entry)
        }
        .configurationDisplayName("Waktu Sholat — Ring & List")
        .description("Tampilan ring countdown & daftar 5 waktu sholat.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - 4. Prayer Times C2 (Gold Glow Cards) View
struct PrayerC2View: View {
    var entry: PrayerEntry

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("14 Muharram 1447H")
                    .font(.system(size: 10))
                    .foregroundColor(colorGold)
                Spacer()
                Text("📍 Jakarta")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }

            HStack(spacing: 6) {
                _MiniCard(name: "Subuh", time: entry.subuh, isActive: entry.nextName == "Subuh")
                _MiniCard(name: "Dzuhur", time: entry.dzuhur, isActive: entry.nextName == "Dzuhur")
                _MiniCard(name: "Ashar", time: entry.ashar, isActive: entry.nextName == "Ashar")
                _MiniCard(name: "Maghrib", time: entry.maghrib, isActive: entry.nextName == "Maghrib")
                _MiniCard(name: "Isya", time: entry.isya, isActive: entry.nextName == "Isya")
            }

            Text("⏱ \(entry.countdown) menuju \(entry.nextName)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(colorAmber)
        }
        .padding(10)
        .background(Color(red: 13/255, green: 13/255, blue: 13/255))
    }
}

struct _MiniCard: View {
    let name: String
    let time: String
    let isActive: Bool

    var body: some View {
        VStack(spacing: 3) {
            Text(name)
                .font(.system(size: 9, weight: isActive ? .bold : .regular))
                .foregroundColor(isActive ? .white : .gray)
            Text(time)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isActive ? colorGold : .white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(isActive ? colorGold.opacity(0.2) : colorCardDark)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? colorGold : Color.clear, lineWidth: 1.5)
        )
        .cornerRadius(8)
    }
}

struct PrayerC2Widget: Widget {
    let kind: String = "PrayerC2Widget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerProvider()) { entry in
            PrayerC2View(entry: entry)
        }
        .configurationDisplayName("Waktu Sholat — Kartu Emas")
        .description("5 kartu sholat dengan highlight emas pada sholat berikutnya.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - 5. Prayer Times C4 (Frosted Glass Cards) View
struct PrayerC4View: View {
    var entry: PrayerEntry

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Waktu Sholat")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(colorGold)
                Spacer()
                Text(entry.countdown)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(colorAmber)
                    .cornerRadius(10)
            }

            HStack(spacing: 6) {
                _FrostedCard(name: "Subuh", time: entry.subuh, isActive: entry.nextName == "Subuh")
                _FrostedCard(name: "Dzuhur", time: entry.dzuhur, isActive: entry.nextName == "Dzuhur")
                _FrostedCard(name: "Ashar", time: entry.ashar, isActive: entry.nextName == "Ashar")
                _FrostedCard(name: "Maghrib", time: entry.maghrib, isActive: entry.nextName == "Maghrib")
                _FrostedCard(name: "Isya", time: entry.isya, isActive: entry.nextName == "Isya")
            }

            Text("Menuju \(entry.nextName) • 47m lagi")
                .font(.system(size: 9))
                .foregroundColor(colorGold)
        }
        .padding(10)
        .background(Color(red: 7/255, green: 19/255, blue: 24/255))
    }
}

struct _FrostedCard: View {
    let name: String
    let time: String
    let isActive: Bool

    var body: some View {
        VStack(spacing: 3) {
            Text(name)
                .font(.system(size: 9, weight: isActive ? .bold : .regular))
                .foregroundColor(isActive ? .white : .gray)
            Text(time)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isActive ? colorGold : .white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(isActive ? colorEmerald.opacity(0.25) : Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? colorEmerald : Color.white.opacity(0.15), lineWidth: 1)
        )
        .cornerRadius(8)
    }
}

struct PrayerC4Widget: Widget {
    let kind: String = "PrayerC4Widget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerProvider()) { entry in
            PrayerC4View(entry: entry)
        }
        .configurationDisplayName("Waktu Sholat — Frosted Glass")
        .description("Variasi kartu transparan dengan border zamrud.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - 6. Last Read & Quick Bookmark Widget
struct LastReadEntry: TimelineEntry {
    let date: Date
    let surahName: String
    let surahNo: Int
    let ayahNo: Int
    let progress: Double
}

struct LastReadProvider: TimelineProvider {
    func placeholder(in context: Context) -> LastReadEntry {
        LastReadEntry(date: Date(), surahName: "Al-Kahf", surahNo: 18, ayahNo: 10, progress: 0.37)
    }

    func getSnapshot(in context: Context, completion: @escaping (LastReadEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LastReadEntry>) -> Void) {
        completion(Timeline(entries: [loadEntry()], policy: .never))
    }

    private func loadEntry() -> LastReadEntry {
        let defaults = UserDefaults(suiteName: appGroupSuite)
        let surahName = defaults?.string(forKey: "hw_last_surah_name") ?? "Al-Kahf"
        let surahNo = defaults?.integer(forKey: "hw_last_surah_no") ?? 18
        let ayahNo = defaults?.integer(forKey: "hw_last_ayah_no") ?? 10
        let progress = defaults?.double(forKey: "hw_last_progress") ?? 0.37
        return LastReadEntry(date: Date(), surahName: surahName, surahNo: surahNo, ayahNo: ayahNo, progress: progress)
    }
}

struct LastReadWidgetView: View {
    var entry: LastReadEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "book.fill")
                    .font(.system(size: 10))
                    .foregroundColor(colorEmerald)
                Text("TERAKHIR DIBACA")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(colorGold)
            }

            Spacer()

            Text(entry.surahName)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(colorGold)

            Text("Ayat \(entry.ayahNo)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)

            ProgressView(value: entry.progress)
                .tint(colorEmerald)

            Spacer()

            HStack {
                Spacer()
                Text("Lanjutkan ▶")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(colorGold)
                    .cornerRadius(8)
                Spacer()
            }
        }
        .padding(12)
        .background(Color(red: 13/255, green: 31/255, blue: 24/255))
        .widgetURL(URL(string: "tafseer://verse/\(entry.surahNo)/\(entry.ayahNo)"))
    }
}

struct LastReadWidget: Widget {
    let kind: String = "LastReadWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LastReadProvider()) { entry in
            LastReadWidgetView(entry: entry)
        }
        .configurationDisplayName("Terakhir Dibaca")
        .description("Lanjutkan membaca Surah terakhir dengan 1 tap.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
