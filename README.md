# Tafseer.id — Quran by Topic

> Read, study, and explore the Quran organized by topic — with tafsir, translation, transliteration, and prayer tools in one app.

[![Build Mobile App](https://github.com/itho777/quran-by-topic/actions/workflows/build.yml/badge.svg?branch=mobile)](https://github.com/itho777/quran-by-topic/actions/workflows/build.yml)

---

## Features

- **Mushaf (Quran pages)** — Full SVG page rendering with verse-level tap interaction. Tap a verse to bookmark, share, or open the study panel — no layout shift.
- **Study Panel** — Translation, tafsir, transliteration, and asbabun nuzul side by side per ayah.
- **Quran by Topic** — Browse and filter ayahs by thematic tags across the entire Quran.
- **Audio Recitation** — Stream or play ayah audio with per-verse highlighting.
- **Murajaah (Memorization Review)** — Spaced repetition session for Quran memorization.
- **Bookmarks** — Save ayahs with sync across devices via Supabase auth.
- **Prayer Times** — Location-based prayer schedule with Adhan audio.
- **Qibla Direction** — Compass-based qibla finder.
- **Hijri Calendar** — Islamic date with daily ayah.
- **Home Widget** — Ayah of the day on your Android home screen.
- **Offline Support** — Core Quran data cached locally; works without internet after first load.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.x (Dart) |
| State Management | Riverpod |
| Backend / Auth | Supabase |
| Local Storage | SQLite (sqflite) + SharedPreferences |
| Page Rendering | WebView (SVG via webview_flutter) |
| Navigation | go_router |
| Audio | audioplayers |
| Fonts | Google Fonts |
| Prayer Times | adhan |
| CI/CD | GitHub Actions |

---

## Project Structure

```
lib/
├── core/                  # Auth, bookmarks, settings managers
├── features/
│   ├── mushaf/            # Quran page reader + study panel
│   ├── topics/            # Quran by topic browser
│   ├── memorization/      # Murajaah review
│   ├── prayer/            # Prayer times + qibla
│   ├── more/              # Settings, donation, about
│   └── home/              # Home screen + widget
assets/
├── data/                  # Quran JSON data files
└── images/                # App icons, QR codes
android/                   # Android-specific config
ios/                       # iOS-specific config
```

---

## Getting Started

### Prerequisites

- Flutter SDK `>=3.0.0`
- Android SDK 36 / Java 21
- A [Supabase](https://supabase.com) project (for auth + bookmark sync)

### Setup

```bash
git clone https://github.com/itho777/quran-by-topic.git
cd quran-by-topic
git checkout mobile
flutter pub get
flutter run
```

Configure your Supabase project URL and anon key in `lib/core/supabase_config.dart` before running.

---

## Build

### Android (APK)

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### Android (App Bundle for Play Store)

```bash
flutter build appbundle --release
```

### iOS (no codesign)

```bash
flutter build ios --release --no-codesign
```

CI builds both automatically on every push to `mobile`. Artifacts attached to each [Actions run](https://github.com/itho777/quran-by-topic/actions?query=branch%3Amobile).

---

## Branches

| Branch | Purpose | Deployed to |
|---|---|---|
| `mobile` | Flutter Android + iOS app | GitHub Actions CI |
| `full-web` | JavaScript SPA (Supabase-powered) | [tafseer.id](https://tafseer.id) via Cloudflare |
| `main` | JavaScript SPA (fully static) | [itho777.github.io/quran-by-topic](https://itho777.github.io/quran-by-topic/) via GitHub Pages |

---

## Contributing

Social/non-profit project. Bug reports, suggestions, and PRs welcome via [Issues](https://github.com/itho777/quran-by-topic/issues).

---

## Support

If this project benefits you, consider supporting server costs:

- **QRIS** (Indonesia): scan in-app via More → Donate
- **BNB Smart Chain**: `0x48dba8551b9c7270ba98eb7667444bcbb216ed95`

---

## License

Open source. Quran text and translations used under their respective open licenses.
