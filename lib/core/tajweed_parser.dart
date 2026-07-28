// lib/core/tajweed_parser.dart
//
// Pure-Dart Tajweed color parser for Uthmani Quranic text.
//
// Reference: Standard Tajweed Mushaf (Dar Al-Ma'rifah) color system,
// cross-validated against Quran.com / AlQuran.cloud quran-tajweed API spec.
//
// Strategy: analyse Unicode codepoints & grapheme clusters to detect all
// standard Tajweed rules. No external assets or network calls — works offline.

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colour palette — matches Dar Al-Ma'rifah / Quran.com Tajweed standard
// ─────────────────────────────────────────────────────────────────────────────
class TajweedColors {
  static const maddWajib    = Color(0xFF000EBC); // Deep Blue  — Madd Wajib (6 harakat)
  static const maddMunfasil = Color(0xFF2144C1); // Blue       — Madd Munfasil / Permissible (4-5)
  static const maddThabii   = Color(0xFF537FFF); // Light Blue — Madd Thabi'i (2 harakat)
  static const ghunnah      = Color(0xFFDD0008); // Red        — Ghunnah (Dengung)
  static const qalqalah     = Color(0xFFDD0008); // Red        — Qalqalah also shown in red (same as ghunnah)
  static const ikhfa        = Color(0xFF9400A8); // Purple     — Ikhfa' (Samar)
  static const ikhfaShafawi = Color(0xFFD500B7); // Magenta    — Ikhfa' Shafawi
  static const idgham       = Color(0xFF169777); // Teal Green — Idgham with Ghunnah
  static const idghamNoGhunnah = Color(0xFF169200); // Green  — Idgham without Ghunnah
  static const idghamShafawi  = Color(0xFF58B800); // Lime    — Idgham Shafawi
  static const iqlab        = Color(0xFF26BFFD); // Cyan       — Iqlab (Menukar)
  static const hamzatWasl   = Color(0xFFAAAAAA); // Grey       — Hamzat Wasl / Silent

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
// Unicode codepoints
// ─────────────────────────────────────────────────────────────────────────────

// Arabic base letters
const int _hamza          = 0x0621;
const int _alefMadda      = 0x0622; // آ — alef with madda above
const int _alefHamzaAbove = 0x0623;
const int _wawHamzaAbove  = 0x0624;
const int _alefHamzaBelow = 0x0625;
const int _yaHamzaAbove   = 0x0626;
const int _alef           = 0x0627;
const int _ba             = 0x0628;
const int _ta             = 0x062A;
const int _tha            = 0x062B;
const int _jim            = 0x062C;
const int _dal            = 0x062F;
const int _thal           = 0x0630;
const int _ra             = 0x0631;
const int _zay            = 0x0632;
const int _sin            = 0x0633;
const int _shin           = 0x0634;
const int _sad            = 0x0635;
const int _dad            = 0x0636;
const int _ta2            = 0x0637; // ط
const int _zha            = 0x0638;
const int _fa             = 0x0641;
const int _qaf            = 0x0642;
const int _kaf            = 0x0643;
const int _lam            = 0x0644;
const int _mim            = 0x0645;
const int _nun            = 0x0646;
const int _waw            = 0x0648;
const int _alefMaqsura    = 0x0649; // ى
const int _ya             = 0x064A;

// Harakaat / diacritics
const int _fathatain      = 0x064B; // ً
const int _dammatain      = 0x064C; // ٌ
const int _kasratain      = 0x064D; // ٍ
const int _fathah         = 0x064E; // َ
const int _dammah         = 0x064F; // ُ
const int _kasrah         = 0x0650; // ِ
const int _shadda         = 0x0651; // ّ
const int _sukun          = 0x0652; // ْ

// Uthmani special marks
const int _superscriptAlef         = 0x0670; // ٰ  — dagger alef (madd)
const int _alefWasla               = 0x0671; // ٱ — hamzat wasl
const int _smallHighUprightZero    = 0x06DF; // ۟ — silent circle marker
const int _smallHighDotlessKhah    = 0x06E1; // ۡ — Uthmani alternate sukun
const int _smallLowMeem            = 0x06E2; // ۢ — iqlab meem indicator
const int _smallHighMadda          = 0x06E4; // ۤ — small madda
const int _maddahAbove             = 0x0653; // ٓ — maddah above (used in madda letters)

// Idgham letter sets
// — with ghunnah: ي ن م و
const Set<int> _idghamWithGhunnah    = {_ya, _nun, _mim, _waw};
// — without ghunnah: ل ر
const Set<int> _idghamWithoutGhunnah = {_lam, _ra};
const Set<int> _idghamLetters        = {_ya, _nun, _mim, _waw, _lam, _ra};

// Ikhfa letters (15 letters: ص ذ ث ك ج ش ق س د ط ز ف ت ض ظ)
const Set<int> _ikhfaLetters = {
  _sad, _thal, _tha, _kaf, _jim, _shin, _qaf,
  _sin, _dal, _ta2, _zay, _fa, _ta, _dad, _zha,
};

// Qalqalah letters: ق ط ب ج د
const Set<int> _qalqalahLetters = {_qaf, _ta2, _ba, _jim, _dal};

// Letters that are Hamzah forms (for Madd classification)
const Set<int> _hamzahForms = {
  _hamza, _alefHamzaAbove, _alefHamzaBelow,
  _wawHamzaAbove, _yaHamzaAbove,
};

// Tanwin codes (nunation)
const Set<int> _tanwinCodes = {_fathatain, _dammatain, _kasratain};

// Sukun variants
const Set<int> _sukunCodes = {_sukun, _smallHighUprightZero, _smallHighDotlessKhah};

/// Returns true if code is a combining diacritic / Uthmani mark.
bool _isCombining(int code) {
  return (code >= 0x064B && code <= 0x065F) ||
      code == _superscriptAlef ||
      (code >= 0x06D6 && code <= 0x06ED);
}

/// Breaks [text] into grapheme clusters (base letter + attached diacritics).
List<String> _clusterize(String text) {
  final List<String> clusters = [];
  StringBuffer buf = StringBuffer();
  for (final ch in text.characters) {
    final code = ch.codeUnitAt(0);
    if (_isCombining(code) && buf.isNotEmpty) {
      buf.write(ch);
    } else {
      if (buf.isNotEmpty) clusters.add(buf.toString());
      buf = StringBuffer(ch);
    }
  }
  if (buf.isNotEmpty) clusters.add(buf.toString());
  return clusters;
}

/// Base letter codepoint for a cluster.
int _base(String cl) => cl.isEmpty ? 0 : cl.codeUnitAt(0);

/// True if the cluster contains the given codepoint.
bool _has(String cl, int code) => cl.codeUnits.contains(code);

/// True if the cluster contains any of the given codepoints.
bool _hasAny(String cl, Set<int> codes) => cl.codeUnits.any(codes.contains);

/// True if the cluster has a vowel (fathah/dammah/kasrah/shadda/tanwin).
bool _isVowelled(String cl) {
  return _hasAny(cl, {_fathah, _dammah, _kasrah, _shadda}) ||
      _hasAny(cl, _tanwinCodes);
}

/// True if the cluster has a sukun in any form.
bool _hasSukun(String cl) => _hasAny(cl, _sukunCodes);

// ─────────────────────────────────────────────────────────────────────────────
// Core parser
// ─────────────────────────────────────────────────────────────────────────────

/// Parses [arabic] Uthmani text and returns colour-coded [TajweedSpan]s.
List<TajweedSpan> parseTajweed(String arabic) {
  if (arabic.isEmpty) return [];

  final clusters = _clusterize(arabic);
  final n = clusters.length;

  // Returns the next non-space base letter after index i, or 0.
  int nextBaseLetter(int i) {
    for (int j = i + 1; j < n; j++) {
      final b = _base(clusters[j]);
      if (b != 0x0020) return b;
    }
    return 0;
  }

  // True if cluster i is at a pause position (end or followed by space then word boundary).
  bool isAtPause(int i) {
    if (i == n - 1) return true;
    final next = _base(clusters[i + 1]);
    return next == 0x0020;
  }

  Color? colorOf(int i) {
    final cl = clusters[i];
    final b = _base(cl);

    // ── 1. Hamzat Wasl / Silent markers ──────────────────────────────────────
    // Alef Wasla (ٱ) is always grey/silent
    if (b == _alefWasla) return TajweedColors.hamzatWasl;
    // Small circle marks a silent letter
    if (_has(cl, _smallHighUprightZero)) return TajweedColors.hamzatWasl;

    // ── 2. Madd rules ─────────────────────────────────────────────────────────
    // Alef Madda (آ) = Madd Wajib Muttasil if followed by hamzah in same word,
    // else Madd Munfasil/Permissible.
    if (b == _alefMadda || _has(cl, _maddahAbove) || _has(cl, _smallHighMadda)) {
      final nb = nextBaseLetter(i);
      if (_hamzahForms.contains(nb)) {
        return TajweedColors.maddWajib;       // Madd Wajib (4-6 harakat)
      }
      return TajweedColors.maddMunfasil;      // Madd Munfasil (4-5 harakat)
    }

    // Dagger alef (superscript ٰ) = Madd Thabi'i (2 harakat)
    if (_has(cl, _superscriptAlef)) return TajweedColors.maddThabii;

    // Madd Thabi'i: unvowelled alef/waw/ya after a matching long vowel
    if (!_isVowelled(cl) && !_hasSukun(cl) && i > 0) {
      final prevCl = clusters[i - 1];
      if ((b == _alef || b == _alefMaqsura) && _has(prevCl, _fathah)) {
        return TajweedColors.maddThabii;
      }
      if (b == _waw && _has(prevCl, _dammah)) {
        return TajweedColors.maddThabii;
      }
      if (b == _ya && _has(prevCl, _kasrah)) {
        return TajweedColors.maddThabii;
      }
    }

    // ── 3. Iqlab indicator ────────────────────────────────────────────────────
    // Small meem (ۢ) written above/below a Nun/Tanwin = Iqlab
    if (_has(cl, _smallLowMeem)) return TajweedColors.iqlab;

    // ── 4. Ghunnah — Nun or Mim Mushaddad ────────────────────────────────────
    if ((b == _nun || b == _mim) && _has(cl, _shadda)) {
      return TajweedColors.ghunnah;
    }

    // ── 5. Qalqalah ───────────────────────────────────────────────────────────
    // Qalqalah letters (ق ط ب ج د) with sukun or at a pause.
    if (_qalqalahLetters.contains(b)) {
      if (_hasSukun(cl) || (!_isVowelled(cl) && isAtPause(i))) {
        return TajweedColors.qalqalah;
      }
    }

    // ── 6. Meem Sukun rules (before detecting Nun Sukun/Tanwin) ──────────────
    if (b == _mim && (_hasSukun(cl) || (!_isVowelled(cl) && !_has(cl, _shadda)))) {
      final nb = nextBaseLetter(i);
      if (nb == _mim) return TajweedColors.idghamShafawi;  // Idgham Shafawi
      if (nb == _ba)  return TajweedColors.ikhfaShafawi;   // Ikhfa' Shafawi
    }

    // ── 7. Nun Sukun / Tanwin rules ───────────────────────────────────────────
    final isTanwin   = _hasAny(cl, _tanwinCodes);
    final isNunSukun = (b == _nun) && (_hasSukun(cl) || (!_isVowelled(cl) && cl.length == 1));

    if (isTanwin || isNunSukun) {
      final nb = nextBaseLetter(i);
      if (nb != 0) {
        if (nb == _ba) return TajweedColors.iqlab;
        if (_idghamWithGhunnah.contains(nb))    return TajweedColors.idgham;
        if (_idghamWithoutGhunnah.contains(nb)) return TajweedColors.idghamNoGhunnah;
        if (_ikhfaLetters.contains(nb))         return TajweedColors.ikhfa;
        // Izhar (clear articulation) — no color
      }
    }

    return null; // Normal text — no tajweed highlight
  }

  // Merge consecutive clusters with the same color into spans.
  final List<TajweedSpan> spans = [];
  String buf = '';
  Color? bufColor;

  for (int i = 0; i < n; i++) {
    final c = colorOf(i);
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
// Legend model
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
  TajweedRule(color: TajweedColors.maddWajib,       nameEn: 'Madd Wajib (6 harakat)',        nameId: 'Madd Wajib (6 harakat)'),
  TajweedRule(color: TajweedColors.maddMunfasil,    nameEn: 'Madd Munfasil (4-5 harakat)',   nameId: 'Madd Munfasil (4–5 harakat)'),
  TajweedRule(color: TajweedColors.maddThabii,      nameEn: 'Madd Thabi\'i (2 harakat)',     nameId: 'Madd Thabi\'i (2 harakat)'),
  TajweedRule(color: TajweedColors.ghunnah,         nameEn: 'Ghunnah (Nasalization)',         nameId: 'Ghunnah (Dengung)'),
  TajweedRule(color: TajweedColors.qalqalah,        nameEn: 'Qalqalah (Echo)',                nameId: 'Qalqalah (Memantul)'),
  TajweedRule(color: TajweedColors.ikhfa,           nameEn: 'Ikhfa\' (Concealment)',          nameId: 'Ikhfa\' (Samar)'),
  TajweedRule(color: TajweedColors.ikhfaShafawi,    nameEn: 'Ikhfa\' Shafawi (Hidden Meem)', nameId: 'Ikhfa\' Syafawi'),
  TajweedRule(color: TajweedColors.idgham,          nameEn: 'Idgham with Ghunnah',            nameId: 'Idgham (Dengung)'),
  TajweedRule(color: TajweedColors.idghamNoGhunnah, nameEn: 'Idgham without Ghunnah',         nameId: 'Idgham (Tanpa Dengung)'),
  TajweedRule(color: TajweedColors.idghamShafawi,   nameEn: 'Idgham Shafawi',                 nameId: 'Idgham Syafawi'),
  TajweedRule(color: TajweedColors.iqlab,           nameEn: 'Iqlab (Conversion)',              nameId: 'Iqlab (Menukar)'),
  TajweedRule(color: TajweedColors.hamzatWasl,      nameEn: 'Hamzat Wasl / Silent',           nameId: 'Hamzat Wasl / Huruf Silent'),
];
