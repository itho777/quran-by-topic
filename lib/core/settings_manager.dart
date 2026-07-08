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

  SettingsState({
    required this.arabicFontSize,
    required this.translationFontSize,
    required this.showTransliteration,
    required this.defaultTranslationSource,
    required this.appLanguage,
    required this.selectedReciter,
    this.mushafFullWidth = false,
  });

  SettingsState copyWith({
    double? arabicFontSize,
    double? translationFontSize,
    bool? showTransliteration,
    String? defaultTranslationSource,
    String? appLanguage,
    String? selectedReciter,
    bool? mushafFullWidth,
  }) {
    return SettingsState(
      arabicFontSize: arabicFontSize ?? this.arabicFontSize,
      translationFontSize: translationFontSize ?? this.translationFontSize,
      showTransliteration: showTransliteration ?? this.showTransliteration,
      defaultTranslationSource: defaultTranslationSource ?? this.defaultTranslationSource,
      appLanguage: appLanguage ?? this.appLanguage,
      selectedReciter: selectedReciter ?? this.selectedReciter,
      mushafFullWidth: mushafFullWidth ?? this.mushafFullWidth,
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
          mushafFullWidth: false,
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
      final fullWidth = prefs.getBool('mushaf_full_width') ?? false;

      state = SettingsState(
        arabicFontSize: arabicSize,
        translationFontSize: transSize,
        showTransliteration: showTranslit,
        defaultTranslationSource: defaultSource,
        appLanguage: lang,
        selectedReciter: reciter,
        mushafFullWidth: fullWidth,
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

  Future<void> setMushafFullWidth(bool val) async {
    state = state.copyWith(mushafFullWidth: val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mushaf_full_width', val);
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
      mushafFullWidth: false,
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
        'mushaf_full_width': state.mushafFullWidth,
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
      final newState = SettingsState(
        arabicFontSize: (data['arabic_font_size'] as num?)?.toDouble() ?? state.arabicFontSize,
        translationFontSize: (data['translation_font_size'] as num?)?.toDouble() ?? state.translationFontSize,
        showTransliteration: (data['show_transliteration'] as bool?) ?? state.showTransliteration,
        defaultTranslationSource: (data['default_translation_source'] as String?) ?? state.defaultTranslationSource,
        appLanguage: (data['app_language'] as String?) ?? state.appLanguage,
        selectedReciter: (data['selected_reciter'] as String?) ?? state.selectedReciter,
        mushafFullWidth: (data['mushaf_full_width'] as bool?) ?? state.mushafFullWidth,
      );
      state = newState;
      await prefs.setDouble('arabic_font_size', newState.arabicFontSize);
      await prefs.setDouble('translation_font_size', newState.translationFontSize);
      await prefs.setBool('show_transliteration', newState.showTransliteration);
      await prefs.setString('default_translation_source', newState.defaultTranslationSource);
      await prefs.setString('app_language', newState.appLanguage);
      await prefs.setString('selected_reciter', newState.selectedReciter);
      await prefs.setBool('mushaf_full_width', newState.mushafFullWidth);
    } catch (_) {}
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

final hideNavBarProvider = StateProvider<bool>((ref) => false);
