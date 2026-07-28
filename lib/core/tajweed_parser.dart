// lib/core/tajweed_parser.dart
//
// Pure-Dart Tajweed color parser for Uthmani Arabic text.
//
// Strategy: analyse each Unicode codepoint to detect which tajweed rule is
// active, then emit a list of (text, Color?) spans. No external assets or
// network calls are needed — this works offline and adds zero bytes to APK.

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colour palette — matches standard Indonesian/QPC Tajweed colors in screenshot
// ─────────────────────────────────────────────────────────────────────────────
class TajweedColors {
  static const maddWajib    = Color(0xFFE53935); // Red (6 harakat)
  static const maddMunfasil = Color(0xFFFB8C00); // Orange (4-5 harakat)
  static const maddThabii   = Color(0xFFC62828); // Dark Red (2 harakat)
  static const ghunnah      = Color(0xFFF57C00); // Dengung (Orange-Yellow)
  static const qalqalah     = Color(0xFF4CAF50); // Memantul (Green)
  static const ikhfa        = Color(0xFF1E88E5); // Samar (Blue)
  static const idgham       = Color(0xFF00ACC1); // Lebur (Teal)
  static const iqlab        = Color(0xFF8E24AA); // Menukar (Purple)
  static const hamzatWasl   = Color(0xFF78909C); // Alif Washal (Grey)

  TajweedColors._();
}

/// A coloured fragment of text produced by [parseTajweed].
class TajweedSpan {
  final String text;
  /// `null` means use the default (parent) colour — i.e. normal text.
  final Color? color;
  const TajweedSpan(this.text, this.color);
}

// ─────────────────────────────────────────────────────────────────────────────
// Unicode helpers
// ─────────────────────────────────────────────────────────────────────────────

// Arabic letter codepoints
const int _alef    = 0x0627;
const int _ba      = 0x0628;
const int _ta      = 0x062A;
const int _tha     = 0x062B;
const int _jim     = 0x062C;
const int _dal     = 0x062F;
const int _thal    = 0x0630;
const int _ra      = 0x0631;
const int _zay     = 0x0632;
const int _sin     = 0x0633;
const int _shin    = 0x0634;
const int _sad     = 0x0635;
const int _dad     = 0x0636;
const int _ta2     = 0x0637; // ط
const int _zha     = 0x0638;
const int _ayn     = 0x0639;
const int _ghayn   = 0x063A;
const int _fa      = 0x0641;
const int _qaf     = 0x0642;
const int _kaf     = 0x0643;
const int _lam     = 0x0644;
const int _mim     = 0x0645;
const int _nun     = 0x0646;
const int _ha      = 0x0647;
const int _waw     = 0x0648;
const int _ya      = 0x064A;

// Harakaat / diacritics
const int _shadda     = 0x0651; // ّ  — shaddah
const int _sukun      = 0x0652; // ْ  — sukun
const int _fathah     = 0x064E;
const int _dammah     = 0x064F;
const int _kasrah     = 0x0650;
const int _fathatain  = 0x064B;
const int _dammatain  = 0x064C;
const int _kasratain  = 0x064D;

// Special Uthmani marks
const int _small_high_upright_rec_zero = 0x06DF; // ۟ — small circle (Sukun Uthmani)
const int _superscript_alef            = 0x0670; // ٰ  — madd dagger alef
const int _small_high_madda            = 0x06E4; // ۤ  — small madda
const int _small_low_meem              = 0x06E2; // ۢ  — iqlab meem
const int _alef_wasla                  = 0x0671; // ٱ — hamzat wasl
const int _alef_madda                  = 0x0622; // آ — madd

const Set<int> _qalqalahLetters = {_ba, _jim, _dal, _ta2, _qaf};
const Set<int> _ikhfaLetters    = {_ta, _tha, _jim, _dal, _thal, _zay, _sin, _shin, _sad, _dad, _ta2, _zha, _fa, _qaf, _kaf};
const Set<int> _idghamLetters   = {_ya, _ra, _mim, _lam, _waw, _nun};

/// Breaks [arabic] string into cluster units (letter + attached diacritics).
List<String> _clusterize(String text) {
  final List<String> clusters = [];
  StringBuffer buf = StringBuffer();

  for (final char in text.characters) {
    final code = char.codeUnitAt(0);
    final isDiacritic = (code >= 0x064B && code <= 0x065F) ||
        code == _superscript_alef ||
        code == _small_high_upright_rec_zero ||
        code == _small_high_madda ||
        code == _small_low_meem;

    if (isDiacritic && buf.isNotEmpty) {
      buf.write(char);
    } else {
      if (buf.isNotEmpty) clusters.add(buf.toString());
      buf = StringBuffer(char);
    }
  }
  if (buf.isNotEmpty) clusters.add(buf.toString());
  return clusters;
}

int _baseLetter(String cluster) {
  if (cluster.isEmpty) return 0;
  return cluster.codeUnitAt(0);
}

bool _hasCode(String cluster, int code) {
  return cluster.codeUnits.contains(code);
}

/// Parses [arabic] text and returns a list of [TajweedSpan]s for rendering.
List<TajweedSpan> parseTajweed(String arabic) {
  if (arabic.isEmpty) return [];

  final clusters = _clusterize(arabic);
  final List<TajweedSpan> spans = [];

  Color? _colorFor(int i) {
    final cl = clusters[i];
    final base = _baseLetter(cl);

    // 1. Hamzat Wasl (Alif Washal)
    if (base == _alef_wasla) {
      return TajweedColors.hamzatWasl;
    }

    // 2. Madd Wajib / Munfasil / Thabi'i
    if (base == _alef_madda || _hasCode(cl, _small_high_madda)) {
      if (i + 1 < clusters.length && (_baseLetter(clusters[i + 1]) == 0x0621 || _baseLetter(clusters[i + 1]) == _alef)) {
        return TajweedColors.maddWajib;
      }
      return TajweedColors.maddMunfasil;
    }
    if (base == _alef || base == _waw || base == _ya || _hasCode(cl, _superscript_alef)) {
      if (_hasCode(cl, _fathah) || _hasCode(cl, _dammah) || _hasCode(cl, _kasrah) || _hasCode(cl, _superscript_alef)) {
        return TajweedColors.maddThabii;
      }
    }

    // 3. Iqlab (Meem above/below Nun/Tanwin)
    if (_hasCode(cl, _small_low_meem)) {
      return TajweedColors.iqlab;
    }

    // 4. Ghunnah (Nun/Mim with Shaddah)
    if ((base == _nun || base == _mim) && _hasCode(cl, _shadda)) {
      return TajweedColors.ghunnah;
    }

    // 5. Qalqalah (Sukun on Qalqalah letters)
    if (_qalqalahLetters.contains(base)) {
      if (_hasCode(cl, _sukun) || _hasCode(cl, _small_high_upright_rec_zero) || i == clusters.length - 1) {
        return TajweedColors.qalqalah;
      }
    }

    // 6. Idgham / Ikhfa (Tanwin or Nun Sukun followed by specific letter)
    final isTanwin = _hasCode(cl, _fathatain) || _hasCode(cl, _dammatain) || _hasCode(cl, _kasratain);
    final isNunSukun = (base == _nun) && (_hasCode(cl, _sukun) || cl.length == 1);

    if (isTanwin || isNunSukun) {
      int nextLetter = 0;
      for (int j = i + 1; j < clusters.length; j++) {
        final b = _baseLetter(clusters[j]);
        if (b != 0x0020 && b != 0x0611) { // non-space
          nextLetter = b;
          break;
        }
      }
      if (nextLetter != 0) {
        if (_idghamLetters.contains(nextLetter)) {
          return TajweedColors.idgham;
        }
        if (_ikhfaLetters.contains(nextLetter)) {
          return TajweedColors.ikhfa;
        }
        if (nextLetter == _ba) {
          return TajweedColors.iqlab;
        }
      }
    }

    return null; // Normal text
  }

  String buf = '';
  Color? bufColor;

  for (int i = 0; i < clusters.length; i++) {
    final c = _colorFor(i);
    if (c == bufColor) {
      buf += clusters[i];
    } else {
      if (buf.isNotEmpty) spans.add(TajweedSpan(buf, bufColor));
      buf = clusters[i];
      bufColor = c;
    }
  }
  if (buf.isNotEmpty) spans.add(TajweedSpan(buf, bufColor));

  return spans;
}

// ─────────────────────────────────────────────────────────────────────────────
// Legend model — matches exact items & colors in user screenshot
// ─────────────────────────────────────────────────────────────────────────────
class TajweedRule {
  final Color color;
  final String nameEn;
  final String nameId;
  const TajweedRule({
    required this.color,
    required this.nameEn,
    required this.nameId,
  });
}

const List<TajweedRule> tajweedRules = [
  TajweedRule(color: TajweedColors.maddWajib,    nameEn: 'Madd Wajib (6 harakat)',     nameId: 'Madd Wajib (6 harakat)'),
  TajweedRule(color: TajweedColors.maddMunfasil, nameEn: 'Madd Munfasil (4-5 harakat)', nameId: 'Madd Munfasil (4–5 harakat)'),
  TajweedRule(color: TajweedColors.maddThabii,   nameEn: 'Madd Thabi\'i (2 harakat)',  nameId: 'Madd Thabi\'i (2 harakat)'),
  TajweedRule(color: TajweedColors.ghunnah,      nameEn: 'Ghunnah (Nasalization)',      nameId: 'Ghunnah (Dengung)'),
  TajweedRule(color: TajweedColors.qalqalah,     nameEn: 'Qalqalah (Echo)',             nameId: 'Qalqalah (Memantul)'),
  TajweedRule(color: TajweedColors.ikhfa,        nameEn: 'Ikhfa\' (Concealment)',       nameId: 'Ikhfa\' (Samar)'),
  TajweedRule(color: TajweedColors.idgham,       nameEn: 'Idgham (Merging)',            nameId: 'Idgham (Lebur)'),
  TajweedRule(color: TajweedColors.iqlab,        nameEn: 'Iqlab (Conversion)',          nameId: 'Iqlab (Menukar)'),
  TajweedRule(color: TajweedColors.hamzatWasl,   nameEn: 'Hamzat Wasl (Alif Washal)',   nameId: 'Hamzat Wasl (Alif Washal)'),
];
