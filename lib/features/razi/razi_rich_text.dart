import 'package:flutter/material.dart';

/// Assistant replies are light markdown: `[QS 3:134](https://tafseer.id/#sura/3/verse/134)`
/// and `**bold**`. Plain `Text` prints the brackets, parentheses and the whole
/// URL; this renders the label as a tappable link and drops the raw syntax.
class RaziRichText extends StatelessWidget {
  const RaziRichText({
    super.key,
    required this.text,
    required this.style,
    required this.onLink,
  });

  final String text;
  final TextStyle style;
  final ValueChanged<String> onLink;

  static final RegExp _markdown = RegExp(
    r'\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)|\*\*([^*]+)\*\*',
  );

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    var index = 0;
    for (final match in _markdown.allMatches(text)) {
      if (match.start > index) {
        spans.add(TextSpan(text: text.substring(index, match.start)));
      }
      final label = match.group(1);
      final url = match.group(2);
      if (label != null && url != null) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () => onLink(url),
            child: Text(
              label,
              style: style.copyWith(
                color: Colors.tealAccent,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ));
      } else if (match.group(3) != null) {
        spans.add(TextSpan(
          text: match.group(3),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ));
      }
      index = match.end;
    }
    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index)));
    }
    return RichText(text: TextSpan(style: style, children: spans));
  }
}
