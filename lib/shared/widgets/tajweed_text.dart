// lib/shared/widgets/tajweed_text.dart
//
// TajweedText — renders an Arabic verse with colour-coded tajweed rules.
// TajweedLegend — shows a legend panel explaining each colour.
//
// Both widgets are self-contained; they only depend on tajweed_parser.dart
// and Flutter core. No internet or asset access needed.

import 'package:flutter/material.dart';
import '../../core/tajweed_parser.dart';
import '../../core/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TajweedText
// ─────────────────────────────────────────────────────────────────────────────
/// Displays an Arabic Quranic verse string with tajweed colour-coding applied.
///
/// When [enabled] is false the text is rendered with [fallbackColor] using the
/// standard (non-coloured) style — allowing a simple toggle.
class TajweedText extends StatelessWidget {
  final String arabic;
  final double fontSize;
  final Color fallbackColor;
  final bool enabled;
  final TextAlign textAlign;

  const TajweedText({
    super.key,
    required this.arabic,
    required this.fontSize,
    required this.fallbackColor,
    this.enabled = true,
    this.textAlign = TextAlign.right,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled || arabic.isEmpty) {
      return Text(
        arabic,
        textDirection: TextDirection.rtl,
        textAlign: textAlign,
        style: AppTheme.arabicStyle(fontSize: fontSize, color: fallbackColor),
      );
    }

    final spans = parseTajweed(arabic);

    return Text.rich(
      TextSpan(
        children: spans.map((s) {
          return TextSpan(
            text: s.text,
            style: AppTheme.arabicStyle(
              fontSize: fontSize,
              color: s.color ?? fallbackColor,
            ),
          );
        }).toList(),
      ),
      textDirection: TextDirection.rtl,
      textAlign: textAlign,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TajweedLegend
// ─────────────────────────────────────────────────────────────────────────────
/// A compact horizontally-scrollable legend card showing tajweed colour rules.
///
/// Pass [isEn] = true for English labels, false for Indonesian.
class TajweedLegend extends StatelessWidget {
  final bool isEn;
  const TajweedLegend({super.key, this.isEn = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Icon(Icons.palette_outlined, size: 13, color: AppTheme.primary),
            const SizedBox(width: 4),
            Text(
              isEn ? 'Tajweed Colour Guide' : 'Panduan Warna Tajwid',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: tajweedRules.map((rule) => _LegendChip(rule: rule, isEn: isEn)).toList(),
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final TajweedRule rule;
  final bool isEn;
  const _LegendChip({required this.rule, required this.isEn});

  @override
  Widget build(BuildContext context) {
    final label = isEn ? rule.nameEn : rule.nameId;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: rule.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.onSurfaceVariant,
            fontSize: 10,
            height: 1.3,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          rule.nameAr,
          style: AppTheme.arabicStyle(fontSize: 10, color: rule.color),
        ),
      ],
    );
  }
}
