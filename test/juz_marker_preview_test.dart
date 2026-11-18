// Golden render of the Juz cartouche marker. Generates a PNG so the shape can
// be eyeballed without a device:  flutter test --update-goldens test/juz_marker_preview_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_id/shared/widgets/juz_marker_icon.dart';

const _gold = Color(0xFFE9C176);

Future<void> _loadFont(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) return;
  final bytes = await file.readAsBytes();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

Future<void> _loadTrado() async {
  await _loadFont('Trado', r'C:/Windows/Fonts/trado.ttf');
  await _loadFont('UiSans', r'C:/Windows/Fonts/segoeui.ttf');
}

void main() {
  testWidgets('juz marker preview', (tester) async {
    await tester.runAsync(_loadTrado);
    tester.view.physicalSize = const Size(760, 300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF131313),
          body: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (final h in <double>[22, 32, 48, 64, 96, 140])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        JuzMarkerIcon(
                          height: h,
                          color: _gold,
                          label: h >= JuzMarkerIcon.minLabelHeight
                              ? '\u062c\u0632\u0621'
                              : null,
                          labelFontFamily: 'Trado',
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${h.toInt()}px',
                          style: const TextStyle(
                            color: Color(0xFF9A8F80),
                            fontSize: 11,
                            fontFamily: 'UiSans',
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/juz_marker_preview.png'),
    );
  });
}
