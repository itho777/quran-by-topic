// lib/shared/widgets/tajweed_text.dart
//
// TajweedText — renders an Arabic verse with colour-coded tajweed rules.
// TajweedLegend — shows a collapsible legend panel matching the user UI design.

import 'package:flutter/material.dart';
import '../../core/tajweed_parser.dart';
import '../../core/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TajweedText
// ─────────────────────────────────────────────────────────────────────────────
/// Displays an Arabic Quranic verse string with tajweed colour-coding applied.
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
/// A collapsible legend card showing tajweed colour rules.
class TajweedLegend extends StatefulWidget {
  final bool isEn;
  const TajweedLegend({super.key, this.isEn = true});

  @override
  State<TajweedLegend> createState() => _TajweedLegendState();
}

class _TajweedLegendState extends State<TajweedLegend> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final isEn = widget.isEn;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark
        ? AppTheme.surfaceContainerHigh
        : const Color(0xFFF1F5F2);
    final borderColor = isDark
        ? AppTheme.outlineVariant
        : const Color(0xFFE2E8E4);
    final titleColor = isDark
        ? AppTheme.onSurface
        : const Color(0xFF2C4A3E);
    final iconColor = isDark
        ? AppTheme.onSurfaceVariant
        : const Color(0xFF4A6B5D);
    final dividerColor = isDark
        ? AppTheme.outlineVariant.withValues(alpha: 0.5)
        : const Color(0xFFE0E6E2);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row with colored dots, title, and collapse arrow
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  // 5 Colored dots
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Dot(color: TajweedColors.maddWajib),
                      _Dot(color: TajweedColors.maddMunfasil),
                      _Dot(color: TajweedColors.maddThabii),
                      _Dot(color: TajweedColors.ghunnah),
                      _Dot(color: TajweedColors.qalqalah),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEn ? 'Tajweed Color Guide' : 'Panduan Warna Tajwid',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                    color: iconColor,
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: dividerColor),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: tajweedRules.map((rule) => _LegendChip(rule: rule, isEn: isEn)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.only(right: 3),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.onSurface : const Color(0xFF37474F);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: rule.color,
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
