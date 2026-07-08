import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.dark) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('theme_mode');
      if (name != null) {
        state = ThemeMode.values.firstWhere(
          (e) => e.name == name,
          orElse: () => ThemeMode.dark,
        );
      }
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', mode.name);
    } catch (_) {}
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class AppTheme {
  static ThemeMode themeMode = ThemeMode.dark;

  static bool get isDark {
    if (themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    }
    return themeMode == ThemeMode.dark;
  }

  // Brand color palette inspired by DESIGN.md (Serene Path / Emerald & Gold)
  static Color get primary => isDark ? const Color(0xFFE9C176) : const Color(0xFF00443E);
  static Color get onPrimary => isDark ? const Color(0xFF412D00) : const Color(0xFFFFFFFF);
  static Color get primaryContainer => isDark ? const Color(0xFFC5A059) : const Color(0xFF0D5D56);
  static Color get onPrimaryContainer => isDark ? const Color(0xFF4E3700) : const Color(0xFF8FD3CA);

  static Color get secondary => isDark ? const Color(0xFF95D1D1) : const Color(0xFF735C00);
  static Color get onSecondary => isDark ? const Color(0xFF003737) : const Color(0xFFFFFFFF);
  static Color get secondaryContainer => isDark ? const Color(0xFF0C5252) : const Color(0xFFFED65B);
  static Color get onSecondaryContainer => isDark ? const Color(0xFF87C3C2) : const Color(0xFF745C00);

  // Background and Surface colors
  static Color get background => isDark ? const Color(0xFF131313) : const Color(0xFFF8FAF8);
  static Color get surface => isDark ? const Color(0xFF131313) : const Color(0xFFF8FAF8);
  static Color get surfaceContainer => isDark ? const Color(0xFF1E1E1E) : const Color(0xFFECEEED);
  static Color get surfaceContainerLow => isDark ? const Color(0xFF1C1B1B) : const Color(0xFFF2F4F2);
  static Color get surfaceContainerHigh => isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE7E9E7);
  static Color get surfaceContainerHighest => isDark ? const Color(0xFF353534) : const Color(0xFFE1E3E1);
  static Color get surfaceDim => isDark ? const Color(0xFF131313) : const Color(0xFFD8DAD9);

  // Text and Outlines
  static Color get onSurface => isDark ? const Color(0xFFE5E2E1) : const Color(0xFF191C1C);
  static Color get onSurfaceVariant => isDark ? const Color(0xFFD1C5B4) : const Color(0xFF3F4947);
  static Color get outline => isDark ? const Color(0xFF9A8F80) : const Color(0xFF6F7977);
  static Color get outlineVariant => isDark ? const Color(0xFF4E4639) : const Color(0xFFBEC9C6);
  static Color get bronzeMute => const Color(0xFF8E7955);

  // Status
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFCF6679);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.dark(
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondary,
        onSecondary: onSecondary,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        surface: surface,
        onSurface: onSurface,
        error: error,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          color: onSurface,
          fontWeight: FontWeight.w700,
          fontSize: 32,
        ),
        displayMedium: GoogleFonts.inter(
          color: onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 24,
        ),
        headlineMedium: GoogleFonts.inter(
          color: onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        titleMedium: GoogleFonts.inter(
          color: onSurface,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        bodyLarge: GoogleFonts.inter(color: onSurfaceVariant, fontSize: 15),
        bodyMedium: GoogleFonts.inter(color: onSurfaceVariant, fontSize: 13),
        labelSmall: GoogleFonts.inter(color: outline, fontSize: 11),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: primary,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
        iconTheme: IconThemeData(color: primary),
      ),
      cardTheme: CardThemeData(
        color: surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: outlineVariant, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        hintStyle: TextStyle(color: outline, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceContainer,
        selectedItemColor: primary,
        unselectedItemColor: outline,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: outlineVariant,
        thickness: 1,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.light(
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondary,
        onSecondary: onSecondary,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        surface: surface,
        onSurface: onSurface,
        error: error,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          color: onSurface,
          fontWeight: FontWeight.w700,
          fontSize: 32,
        ),
        displayMedium: GoogleFonts.inter(
          color: onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 24,
        ),
        headlineMedium: GoogleFonts.inter(
          color: onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        titleMedium: GoogleFonts.inter(
          color: onSurface,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        bodyLarge: GoogleFonts.inter(color: onSurfaceVariant, fontSize: 15),
        bodyMedium: GoogleFonts.inter(color: onSurfaceVariant, fontSize: 13),
        labelSmall: GoogleFonts.inter(color: outline, fontSize: 11),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: primary,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
        iconTheme: IconThemeData(color: primary),
      ),
      cardTheme: CardThemeData(
        color: surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: outlineVariant, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        hintStyle: TextStyle(color: outline, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceContainer,
        selectedItemColor: primary,
        unselectedItemColor: outline,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: outlineVariant,
        thickness: 1,
      ),
    );
  }

  /// Arabic text style using Amiri font
  static TextStyle arabicStyle({
    double fontSize = 32,
    FontWeight fontWeight = FontWeight.w400,
    Color color = const Color(0xFF0F5B5B),
  }) {
    return GoogleFonts.amiri(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.8,
    );
  }

  /// Render text containing simple HTML-like tags like <b>, <u>, <i> as formatted widgets.
  static Widget buildFormattedText(String text, TextStyle baseStyle, {TextAlign textAlign = TextAlign.left}) {
    if (!text.contains('<')) {
      return Text(text, style: baseStyle, textAlign: textAlign);
    }

    final List<InlineSpan> spans = [];
    final regExp = RegExp(r'(<[^>]+>)|([^<]+)');
    final matches = regExp.allMatches(text);

    bool isBold = false;
    bool isItalic = false;
    bool isUnderline = false;

    for (final match in matches) {
      final str = match.group(0) ?? '';
      if (str.startsWith('<')) {
        final tag = str.toLowerCase();
        if (tag == '<b>' || tag == '<strong>') {
          isBold = true;
        } else if (tag == '</b>' || tag == '</strong>') {
          isBold = false;
        } else if (tag == '<i>' || tag == '<em>') {
          isItalic = true;
        } else if (tag == '</i>' || tag == '</em>') {
          isItalic = false;
        } else if (tag == '<u>') {
          isUnderline = true;
        } else if (tag == '</u>') {
          isUnderline = false;
        }
      } else {
        spans.add(
          TextSpan(
            text: str,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : baseStyle.fontWeight,
              fontStyle: isItalic ? FontStyle.italic : baseStyle.fontStyle,
              decoration: isUnderline ? TextDecoration.underline : baseStyle.decoration,
            ),
          ),
        );
      }
    }

    return Text.rich(
      TextSpan(children: spans, style: baseStyle),
      textAlign: textAlign,
    );
  }
}
