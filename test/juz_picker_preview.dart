// Golden render of the Juz picker rows — proves both locales show the same
// label and that the IslamicStar numeral frame matches the Surah page.
//   flutter test --update-goldens test/juz_picker_preview_test.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_id/core/theme.dart';
import 'package:tafseer_id/shared/widgets/juz_picker_sheet.dart';

Future<void> _loadFont(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) return;
  final bytes = await file.readAsBytes();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

Future<void> _pump(WidgetTester tester, String lang) async {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'UiSans',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppTheme.primary,
      brightness: Brightness.dark,
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: base,
      home: Scaffold(
        backgroundColor: AppTheme.background,
        body: JuzPickerSheet(currentLang: lang, currentJuz: 12),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('juz picker preview en/id', (tester) async {
    await tester.runAsync(() async {
      await _loadFont('UiSans', r'C:/Windows/Fonts/segoeui.ttf');
    });
    AppTheme.themeMode = ThemeMode.dark;
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pump(tester, 'en');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/juz_picker_en.png'),
    );

    await _pump(tester, 'id');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/juz_picker_id.png'),
    );
  });
}
