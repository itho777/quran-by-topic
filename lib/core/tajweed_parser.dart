// lib/core/tajweed_parser.dart
//
// Pure-Dart Tajweed color parser for Uthmani Arabic text.
//
// Strategy: analyse each Unicode codepoint to detect which tajweed rule is
// active, then emit a list of (text, Color?) spans.  No external assets or
// network calls are needed — this works offline and adds zero bytes to APK.
//
// Rules implemented (QPC colour convention):
//   Madd (prolongation)         — green   #2DB56B
//   Idgham (merging)            — blue    #4A90D9
//   Ikhfa / Iqlab              — purple  #9B59B6
//   Ghunnah                    — violet  #8E44AD
//   Qalqalah                   — orange  #E67E22
//   Waqf / silent              — grey    #95A5A6
//   Lam Shamsiyya (sun letter) — red     #E74C3C
//   Isti'ala (heavy letters)   — teal    #16A085
//   Normal text                — null    (inherit from parent)
//
// See: https://quranpedia.net and QPC Mushaf colour specifications.

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colour palette — matches QPC standard
// ─────────────────────────────────────────────────────────────────────────────
class TajweedColors {
  static const madd       = Color(0xFF2DB56B); // Green  — prolongation
  static const idgham     = Color(0xFF4A90D9); // Blue   — merging
  static const ikhfaIqlab = Color(0xFF9B59B6); // Purple — concealment / turning
  static const ghunnah    = Color(0xFF8E44AD); // Violet — nasalisation
  static const qalqalah   = Color(0xFFE67E22); // Orange — echo
  static const lam        = Color(0xFFE74C3C); // Red    — solar lam
  static const istiaala   = Color(0xFF16A085); // Teal   — heavy letters
  static const waqf       = Color(0xFF95A5A6); // Grey   — pause / silent

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
const int _shadda  = 0x0651; // ّ  — shaddah
const int _sukun   = 0x0652; // ْ  — sukun
const int _fathah  = 0x064E;
const int _dammah  = 0x064F;
const int _kasrah  = 0x0650;
const int _fathatain  = 0x064B;
const int _dammatain  = 0x064C;
const int _kasratain  = 0x064D;

// Special Uthmani marks
const int _small_high_upright_rec_zero = 0x06DF; // ۟ — small circle (Sukun Uthmani)
const int _sign_dot_above              = 0x06EC;
const int _superscript_alef            = 0x0670; // ٰ  — madd dagger alef
const int _small_high_jeem             = 0x06DC; // ۜ  — tajweed annotation
const int _small_low_meem              = 0x06E2;
const int _small_high_seen             = 0x06DB;
const int _small_waw                   = 0x06E5;
const int _small_ya                    = 0x06E6;
const int _hamza_above_alef            = 0x0623;
const int _alef_madda                  = 0x0622; // آ — madd
const int _alef_wasla                  = 0x0671;
const int _waw_hamza                   = 0x0624;
const int _ya_hamza                    = 0x0626;

// Heavy (Isti'ala) letters
const _heavier = {_sad, _dad, _ta2, _zha, _ghayn, _qaf, _kaf};

// Qalqalah letters
const _qalqalaLetters = {_qaf, _ta2, _ba, _jim, _dal};

// Sun (solar) letters — produce assimilation of "al-"
const _sunLetters = {
  _ta, _tha, _dal, _thal, _ra, _zay, _sin, _shin, _sad, _dad, _ta2, _zha,
  _lam, _nun,
};

// Idgham letters (when a noon-sakin or tanwin is followed by these)
const _idghamLetters = {_ya, _ra, _mim, _lam, _waw, _nun};

// Ikhfa letters
const _ikhfaLetters = {
  _ta, _tha, _jim, _dal, _thal, _zay, _sin, _shin, _sad, _dad, _ta2, _zha,
  _fa, _qaf, _kaf,
};

bool _isArabicLetter(int cp) =>
    (cp >= 0x0621 && cp <= 0x06FF) ||
    (cp >= 0xFB50 && cp <= 0xFDFF) ||
    (cp >= 0xFE70 && cp <= 0xFEFF);

bool _isDiacritic(int cp) =>
    (cp >= 0x064B && cp <= 0x065F) || cp == _superscript_alef ||
    (cp >= 0x06D6 && cp <= 0x06ED);

bool _isTanwin(int cp) =>
    cp == _fathatain || cp == _dammatain || cp == _kasratain;

bool _isNunSakin(String cluster) {
  // A cluster is nun-sakin if it contains ن followed by a sukun / sukun-like
  final cps = cluster.runes.toList();
  bool hasNun = false;
  bool hasSukun = false;
  for (final cp in cps) {
    if (cp == _nun) hasNun = true;
    if (cp == _sukun || cp == _small_high_upright_rec_zero) hasSukun = true;
  }
  return hasNun && hasSukun;
}

bool _isMimSakin(String cluster) {
  final cps = cluster.runes.toList();
  bool hasMim = false;
  bool hasSukun = false;
  for (final cp in cps) {
    if (cp == _mim) hasMim = true;
    if (cp == _sukun || cp == _small_high_upright_rec_zero) hasSukun = true;
  }
  return hasMim && hasSukun;
}

// ─────────────────────────────────────────────────────────────────────────────
// Cluster splitter — splits Arabic string into grapheme clusters (base + diacritics)
// ─────────────────────────────────────────────────────────────────────────────
List<String> _splitClusters(String text) {
  final clusters = <String>[];
  final runes = text.runes.toList();
  int i = 0;
  while (i < runes.length) {
    final start = i;
    i++;
    // Absorb all following diacritics / marks
    while (i < runes.length && _isDiacritic(runes[i])) {
      i++;
    }
    clusters.add(String.fromCharCodes(runes.sublist(start, i)));
  }
  return clusters;
}

// ─────────────────────────────────────────────────────────────────────────────
// Main parser
// ─────────────────────────────────────────────────────────────────────────────
/// Parses an Uthmani Arabic verse string into coloured [TajweedSpan]s.
/// Consecutive clusters with the same colour are merged into one span.
List<TajweedSpan> parseTajweed(String text) {
  if (text.isEmpty) return [];

  final clusters = _splitClusters(text);
  final spans = <TajweedSpan>[];

  Color? _colorFor(int idx) {
    final cluster = clusters[idx];
    final runes = cluster.runes.toList();
    if (runes.isEmpty) return null;
    final base = runes[0];

    // ── Space / punctuation ──────────────────────────────────────────────────
    if (base == 0x20 || base == 0x0020) return null; // regular space

    // ── Waqf signs (pause markers) ───────────────────────────────────────────
    // Uthmani Quran uses various waqf characters in range 0x06D6–0x06DD
    if (base >= 0x06D6 && base <= 0x06DD) return TajweedColors.waqf;

    if (!_isArabicLetter(base)) return null;

    // ── Madd ─────────────────────────────────────────────────────────────────
    // Superscript alef (dagger alef) on a letter = madd
    if (runes.contains(_superscript_alef)) return TajweedColors.madd;
    // Alef-madda (آ) always carries a long vowel
    if (base == _alef_madda) return TajweedColors.madd;
    // Waw or Ya with sukun preceded by a long vowel in the adjacent cluster
    if ((base == _waw || base == _ya) && runes.contains(_sukun)) {
      if (idx > 0) {
        final prev = clusters[idx - 1].runes.toList();
        final prevBase = prev.isNotEmpty ? prev[0] : 0;
        if (prevBase == _alef || prevBase == _waw || prevBase == _ya ||
            prev.contains(_fathah) || prev.contains(_dammah) || prev.contains(_kasrah)) {
          return TajweedColors.madd;
        }
      }
    }
    // Small waw / ya = madd
    if (base == _small_waw || base == _small_ya) return TajweedColors.madd;

    // ── Shadda (gemination) → check for idgham ───────────────────────────────
    if (runes.contains(_shadda)) {
      // Shadda on a letter after nun-sakin or tanwin → idgham
      if (idx > 0) {
        final prev = clusters[idx - 1];
        if (_isNunSakin(prev) || prev.runes.any(_isTanwin)) {
          if (_idghamLetters.contains(base)) return TajweedColors.idgham;
        }
      }
      // Shadda on mim after mim-sakin → idgham shafawi (ghunnah variant)
      if (base == _mim && idx > 0 && _isMimSakin(clusters[idx - 1])) {
        return TajweedColors.ghunnah;
      }
    }

    // ── Noon-sakin / Tanwin rules ─────────────────────────────────────────────
    // Look at the current cluster for noon-sakin / tanwin, then at next cluster
    if (_isNunSakin(cluster) || cluster.runes.any(_isTanwin)) {
      if (idx + 1 < clusters.length) {
        final nextBase = clusters[idx + 1].runes.toList();
        final nb = nextBase.isNotEmpty ? nextBase[0] : 0;
        // Idgham
        if (_idghamLetters.contains(nb)) return TajweedColors.idgham;
        // Ikhfa
        if (_ikhfaLetters.contains(nb)) return TajweedColors.ikhfaIqlab;
        // Iqlab (ba follows noon-sakin/tanwin)
        if (nb == _ba) return TajweedColors.ikhfaIqlab;
      }
    }

    // ── Mim-sakin rules ──────────────────────────────────────────────────────
    if (_isMimSakin(cluster) && idx + 1 < clusters.length) {
      final nextBase = clusters[idx + 1].runes.toList();
      final nb = nextBase.isNotEmpty ? nextBase[0] : 0;
      if (nb == _ba) return TajweedColors.ikhfaIqlab; // Ikhfa shafawi
    }

    // ── Ghunnah — mim/nun with shadda ────────────────────────────────────────
    if ((base == _mim || base == _nun) && runes.contains(_shadda)) {
      return TajweedColors.ghunnah;
    }

    // ── Qalqalah — qalqalah letters with sukun ───────────────────────────────
    if (_qalqalaLetters.contains(base) &&
        (runes.contains(_sukun) || runes.contains(_small_high_upright_rec_zero))) {
      return TajweedColors.qalqalah;
    }

    // ── Lam Shamsiyya — ل with shadda after ال ───────────────────────────────
    if (base == _lam && runes.contains(_shadda)) {
      // Check if the preceding cluster is alef (part of definite article)
      if (idx >= 2) {
        final pp = clusters[idx - 2].runes.toList();
        final p = clusters[idx - 1].runes.toList();
        if ((pp.isNotEmpty && (pp[0] == _alef || pp[0] == _alef_wasla)) &&
            (p.isNotEmpty && p[0] == _lam)) {
          // Next letter is a sun letter → lam shamsiyya
          if (idx + 1 < clusters.length) {
            final nb = clusters[idx + 1].runes.toList();
            if (nb.isNotEmpty && _sunLetters.contains(nb[0])) {
              return TajweedColors.lam;
            }
          }
        }
      }
    }

    // ── Isti'ala — heavy letters ──────────────────────────────────────────────
    if (_heavier.contains(base)) return TajweedColors.istiaala;

    return null; // normal
  }

  // Build spans, merging adjacent same-colour clusters
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
// Legend model
// ─────────────────────────────────────────────────────────────────────────────
class TajweedRule {
  final Color color;
  final String nameEn;
  final String nameId;
  final String nameAr;
  const TajweedRule({
    required this.color,
    required this.nameEn,
    required this.nameId,
    required this.nameAr,
  });
}

const List<TajweedRule> tajweedRules = [
  TajweedRule(color: TajweedColors.madd,       nameEn: 'Madd (Prolongation)',   nameId: 'Madd (Panjang)',        nameAr: 'مـَد'),
  TajweedRule(color: TajweedColors.ghunnah,    nameEn: 'Ghunnah (Nasalisation)',nameId: 'Ghunnah (Dengung)',     nameAr: 'غُنَّة'),
  TajweedRule(color: TajweedColors.idgham,     nameEn: 'Idgham (Merging)',      nameId: 'Idgham (Memasukkan)',   nameAr: 'إِدْغَام'),
  TajweedRule(color: TajweedColors.ikhfaIqlab, nameEn: 'Ikhfa / Iqlab',        nameId: 'Ikhfa / Iqlab',         nameAr: 'إِخْفَاء / إِقْلَاب'),
  TajweedRule(color: TajweedColors.qalqalah,   nameEn: 'Qalqalah (Echo)',       nameId: 'Qalqalah (Memantul)',   nameAr: 'قَلْقَلَة'),
  TajweedRule(color: TajweedColors.lam,        nameEn: 'Lam Shamsiyya',         nameId: 'Lam Syamsiah',          nameAr: 'لَام شَمْسِيَّة'),
  TajweedRule(color: TajweedColors.istiaala,   nameEn: 'Isti\'ala (Elevation)', nameId: 'Isti\'la (Berat)',      nameAr: 'اسْتِعْلَاء'),
];
