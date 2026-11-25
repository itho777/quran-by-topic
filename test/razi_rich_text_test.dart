import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tafseer_id/features/razi/razi_rich_text.dart';

void main() {
  testWidgets('renders citation label, hides markdown, tap returns URL',
      (tester) async {
    final tapped = <String>[];
    const url = 'https://tafseer.id/#sura/3/verse/134';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RaziRichText(
          text: 'Lihat [QS 3:134]($url) dan **menahan amarah**.',
          style: const TextStyle(fontSize: 14, color: Colors.white),
          onLink: tapped.add,
        ),
      ),
    ));

    expect(find.text('QS 3:134'), findsOneWidget);
    final rich = tester.widget<RichText>(find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().contains('Lihat'),
    ));
    final root = rich.text as TextSpan;
    final plain = root.toPlainText();
    expect(plain, isNot(contains('https://')));
    expect(plain, isNot(contains('**')));
    final bold = (root.children ?? <InlineSpan>[])
        .whereType<TextSpan>()
        .any((span) => span.text == 'menahan amarah');
    expect(bold, isTrue);

    await tester.tap(find.text('QS 3:134'));
    await tester.pumpAndSettle();
    expect(tapped, <String>[url]);
  });
}
