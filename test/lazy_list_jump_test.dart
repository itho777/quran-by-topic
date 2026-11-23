// Proves "jump to ayah" reaches a row the lazy list has never built.
//   flutter test test/lazy_list_jump_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_id/core/lazy_list_jump.dart';

const int _rowCount = 286; // Al-Baqarah

/// Height varies per row the way verse cards do: long ayahs are much taller.
double _rowHeight(int i) => 120 + (i % 7) * 40 + (i == 281 ? 900 : 0);

Future<void> _pumpList(WidgetTester tester, List<GlobalKey> keys, ScrollController c) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView.builder(
          controller: c,
          cacheExtent: 250,
          itemCount: _rowCount,
          itemBuilder: (ctx, i) => SizedBox(
            key: keys[i],
            height: _rowHeight(i),
            child: Text('row $i'),
          ),
        ),
      ),
    ),
  );
}

/// Pumps frames until [future] completes; fails the test if it never does.
Future<void> _drive(WidgetTester tester, Future<void> future) async {
  var done = false;
  final tracked = future.whenComplete(() => done = true);
  for (var i = 0; i < 300 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(done, isTrue, reason: 'jump did not finish in 300 frames');
  await tracked;
}

void main() {
  testWidgets('jumps to an off-screen row far down the list', (tester) async {
    final keys = List.generate(_rowCount, (_) => GlobalKey());
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _pumpList(tester, keys, controller);

    expect(keys[285].currentContext, isNull,
        reason: 'row 285 must not be built before the jump (that is the bug)');

    await _drive(
      tester,
      LazyListJumper().jumpToRow(
        controller: controller,
        index: 285,
        itemCount: _rowCount,
        keyAt: (i) => keys[i],
      ),
    );

    final box = keys[285].currentContext!.findRenderObject() as RenderBox;
    final top = box.localToGlobal(Offset.zero).dy;
    final screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(box.hasSize, isTrue);
    expect(top, lessThan(screenHeight),
        reason: 'target row must be laid out and visible');
    expect(top + box.size.height, greaterThan(0));
  });

  testWidgets('lands a mid-list row exactly at the top inset', (tester) async {
    final keys = List.generate(_rowCount, (_) => GlobalKey());
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _pumpList(tester, keys, controller);

    const index = 149;
    const topInset = 64.0;
    expect(keys[index].currentContext, isNull,
        reason: 'row $index must not be built before the jump');

    await _drive(
      tester,
      LazyListJumper().jumpToRow(
        controller: controller,
        index: index,
        itemCount: _rowCount,
        keyAt: (i) => keys[i],
        topInset: topInset,
      ),
    );

    final box = keys[index].currentContext!.findRenderObject() as RenderBox;
    final top = box.localToGlobal(Offset.zero).dy;
    expect(top, closeTo(topInset, 2.0),
        reason: 'row $index top should sit at the inset, not ${top}px');
  });

  testWidgets('jumps backwards to a row above the viewport', (tester) async {
    final keys = List.generate(_rowCount, (_) => GlobalKey());
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _pumpList(tester, keys, controller);

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();

    expect(keys[3].currentContext, isNull);

    await _drive(
      tester,
      LazyListJumper().jumpToRow(
        controller: controller,
        index: 3,
        itemCount: _rowCount,
        keyAt: (i) => keys[i],
        topInset: 0,
      ),
    );

    final box = keys[3].currentContext!.findRenderObject() as RenderBox;
    final top = box.localToGlobal(Offset.zero).dy;
    expect(top, closeTo(0, 2.0), reason: 'row 3 should be at the top, got $top');
  });
}
