import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsState {
  final double arabicFontSize;
  final double translationFontSize;
  final bool showTransliteration;
  final String defaultTranslationSource;
  final String appLanguage;
  final String selectedReciter;
  final bool mushafFullWidth;
  final String prayerCalculationMethod;

  SettingsState({
    required this.arabicFontSize,
    required this.translationFontSize,
    required this.showTransliteration,
    required this.defaultTranslationSource,
    required this.appLanguage,
    required this.selectedReciter,
    this.mushafFullWidth = true,
    this.prayerCalculationMethod = 'singapore',
  });

  SettingsState copyWith({
    double? arabicFontSize,
    double? translationFontSize,
    bool? showTransliteration,
    String? defaultTranslationSource,
    String? appLanguage,
    String? selectedReciter,
    bool? mushafFullWidth,
    String? prayerCalculationMethod,
  }) {
    return SettingsState(
      arabicFontSize: arabicFontSize ?? this.arabicFontSize,
      translationFontSize: translationFontSize ?? this.translationFontSize,
      showTransliteration: showTransliteration ?? this.showTransliteration,
      defaultTranslationSource: defaultTranslationSource ?? this.defaultTranslationSource,
      appLanguage: appLanguage ?? this.appLanguage,
      selectedReciter: selectedReciter ?? this.selectedReciter,
      mushafFullWidth: mushafFullWidth ?? this.mushafFullWidth,
      prayerCalculationMethod: prayerCalculationMethod ?? this.prayerCalculationMethod,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier()
      : super(SettingsState(
          arabicFontSize: 32.0,
          translationFontSize: 14.0,
          showTransliteration: true,
          defaultTranslationSource: 'id.kemenag',
          appLanguage: 'id', // Default to Indonesian
          selectedReciter: 'Alafasy_128kbps',
          mushafFullWidth: true,
          prayerCalculationMethod: 'singapore',
        )) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final arabicSize = prefs.getDouble('arabic_font_size') ?? 32.0;
      final transSize = prefs.getDouble('translation_font_size') ?? 14.0;
      final showTranslit = prefs.getBool('show_transliteration') ?? true;
      final defaultSource = prefs.getString('default_translation_source') ?? 'id.kemenag';
      final lang = prefs.getString('app_language') ?? 'id';
      final reciter = prefs.getString('selected_reciter') ?? 'Alafasy_128kbps';
      final calcMethod = prefs.getString('prayer_calculation_method') ?? 'singapore';

      // mushafFullWidth is intentionally NOT loaded from storage.
      // It always defaults to true on each app launch.
      state = SettingsState(
        arabicFontSize: arabicSize,
        translationFontSize: transSize,
        showTransliteration: showTranslit,
        defaultTranslationSource: defaultSource,
        appLanguage: lang,
        selectedReciter: reciter,
        mushafFullWidth: true,
        prayerCalculationMethod: calcMethod,
      );
    } catch (_) {}
  }

  Future<void> setArabicFontSize(double size) async {
    state = state.copyWith(arabicFontSize: size);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('arabic_font_size', size);
  }

  Future<void> setTranslationFontSize(double size) async {
    state = state.copyWith(translationFontSize: size);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('translation_font_size', size);
  }

  Future<void> setShowTransliteration(bool show) async {
    state = state.copyWith(showTransliteration: show);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_transliteration', show);
  }

  Future<void> setDefaultTranslationSource(String source) async {
    state = state.copyWith(defaultTranslationSource: source);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_translation_source', source);
  }

  Future<void> setAppLanguage(String lang) async {
    final defaultSource = lang == 'en' ? 'en.sahih' : 'id.kemenag';
    state = state.copyWith(
      appLanguage: lang,
      defaultTranslationSource: defaultSource,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', lang);
    await prefs.setString('default_translation_source', defaultSource);
  }

  Future<void> setSelectedReciter(String reciter) async {
    state = state.copyWith(selectedReciter: reciter);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_reciter', reciter);
    await _cloudSync();
  }

  // mushafFullWidth is session-only — not persisted to disk or cloud.
  void setMushafFullWidth(bool val) {
    state = state.copyWith(mushafFullWidth: val);
  }

  Future<void> setPrayerCalculationMethod(String method) async {
    state = state.copyWith(prayerCalculationMethod: method);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('prayer_calculation_method', method);
  }

  /// Reset ALL settings to factory defaults and clear persisted preferences.
  Future<void> resetToDefaults() async {
    state = SettingsState(
      arabicFontSize: 32.0,
      translationFontSize: 14.0,
      showTransliteration: true,
      defaultTranslationSource: 'id.kemenag',
      appLanguage: 'id',
      selectedReciter: 'Alafasy_128kbps',
      mushafFullWidth: true,
      prayerCalculationMethod: 'singapore',
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _cloudSync();
  }

  // ── Cloud sync ─────────────────────────────────────────────────────────────

  /// Push current settings to Supabase (no-op if not signed in).
  Future<void> syncToCloud() => _cloudSync();

  Future<void> _cloudSync() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client.from('user_preferences').upsert({
        'user_id': user.id,
        'app_language': state.appLanguage,
        'default_translation_source': state.defaultTranslationSource,
        'arabic_font_size': state.arabicFontSize,
        'translation_font_size': state.translationFontSize,
        'show_transliteration': state.showTransliteration,
        'selected_reciter': state.selectedReciter,
        // mushafFullWidth is not synced to cloud — session-only preference.
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (_) {}
  }

  /// Pull settings from Supabase and apply them (also saves locally).
  Future<void> loadFromCloud() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final data = await Supabase.instance.client
          .from('user_preferences')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      if (data == null) {
        // No cloud record yet — push local settings to cloud
        await _cloudSync();
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      // mushafFullWidth is not pulled from cloud — it is always true on launch.
      final newState = SettingsState(
        arabicFontSize: (data['arabic_font_size'] as num?)?.toDouble() ?? state.arabicFontSize,
        translationFontSize: (data['translation_font_size'] as num?)?.toDouble() ?? state.translationFontSize,
        showTransliteration: (data['show_transliteration'] as bool?) ?? state.showTransliteration,
        defaultTranslationSource: (data['default_translation_source'] as String?) ?? state.defaultTranslationSource,
        appLanguage: (data['app_language'] as String?) ?? state.appLanguage,
        selectedReciter: (data['selected_reciter'] as String?) ?? state.selectedReciter,
        mushafFullWidth: true,
        prayerCalculationMethod: prefs.getString('prayer_calculation_method') ?? state.prayerCalculationMethod,
      );
      state = newState;
      await prefs.setDouble('arabic_font_size', newState.arabicFontSize);
      await prefs.setDouble('translation_font_size', newState.translationFontSize);
      await prefs.setBool('show_transliteration', newState.showTransliteration);
      await prefs.setString('default_translation_source', newState.defaultTranslationSource);
      await prefs.setString('app_language', newState.appLanguage);
      await prefs.setString('selected_reciter', newState.selectedReciter);
    } catch (_) {}
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

final hideNavBarProvider = StateProvider<bool>((ref) => false);
