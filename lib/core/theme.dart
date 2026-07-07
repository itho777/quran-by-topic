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
  // Brand color palette from Stitch designs (Gold/Teal/Dark)
  static const Color primary = Color(0xFFE9C176); // Gold
  static const Color onPrimary = Color(0xFF412D00);
  static const Color primaryContainer = Color(0xFFC5A059);
  static const Color onPrimaryContainer = Color(0xFF4E3700);

  static const Color secondary = Color(0xFF95D1D1); // Teal
  static const Color onSecondary = Color(0xFF003737);
  static const Color secondaryContainer = Color(0xFF0C5252);
  static const Color onSecondaryContainer = Color(0xFF87C3C2);

  // Background and Surface colors
  static const Color background = Color(0xFF131313);
  static const Color surface = Color(0xFF131313);
  static const Color surfaceContainer = Color(0xFF1E1E1E);
  static const Color surfaceContainerLow = Color(0xFF1C1B1B);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color surfaceContainerHighest = Color(0xFF353534);
  static const Color surfaceDim = Color(0xFF131313);

  // Text and Outlines
  static const Color onSurface = Color(0xFFE5E2E1);
  static const Color onSurfaceVariant = Color(0xFFD1C5B4);
  static const Color outline = Color(0xFF9A8F80);
  static const Color outlineVariant = Color(0xFF4E4639);
  static const Color bronzeMute = Color(0xFF8E7955);

  // Status
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFCF6679);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
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
        background: background,
        onBackground: onSurface,
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
      appBarTheme: const AppBarTheme(
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
          side: const BorderSide(color: outlineVariant, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        hintStyle: const TextStyle(color: outline, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceContainer,
        selectedItemColor: primary,
        unselectedItemColor: outline,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: outlineVariant,
        thickness: 1,
      ),
    );
  }

  /// Arabic text style using Amiri font
  static TextStyle arabicStyle({
    double fontSize = 32,
    FontWeight fontWeight = FontWeight.w400,
    Color color = primary,
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
