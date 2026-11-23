import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Scrolls a lazily built list to a row that may not exist yet.
///
/// A row only gets a live `BuildContext` once the sliver has laid it out, so a
/// row far outside the viewport cannot be reached with `ensureVisible` alone —
/// that is a silent no-op, which is exactly how "jump to ayah" used to fail.
///
/// [jumpToRow] instead estimates the offset from the rows that *are* laid out,
/// jumps there, then re-measures and corrects. A few passes land exactly on the
/// target no matter how tall the list is or how uneven the row heights are.
class LazyListJumper {
  LazyListJumper({this.maxPasses = 6});

  /// Upper bound on measure/correct cycles. Each pass at least halves the
  /// remaining error in practice; six is far more than needed.
  final int maxPasses;

  int _job = 0;

  /// Scrolls [controller] so the row at [index] sits [topInset] pixels below
  /// the viewport top.
  ///
  /// [keyAt] must return the same `GlobalKey` the list attaches to row `i`, or
  /// null when that row has never been built. [itemCount] bounds the search for
  /// laid-out rows.
  Future<void> jumpToRow({
    required ScrollController controller,
    required int index,
    required int itemCount,
    required GlobalKey? Function(int index) keyAt,
    double topInset = 0,
  }) async {
    final job = ++_job;
    for (var pass = 0; pass < maxPasses; pass++) {
      if (job != _job || !controller.hasClients) return;
      final pos = controller.position;

      final box = keyAt(index)?.currentContext?.findRenderObject();
      double? target;
      if (box is RenderBox && box.hasSize) {
        final viewport = RenderAbstractViewport.maybeOf(box);
        if (viewport == null) return;
        target = viewport.getOffsetToReveal(box, 0.0).offset - topInset;
      } else {
        target = estimateOffset(
          controller: controller,
          index: index,
          itemCount: itemCount,
          keyAt: keyAt,
        );
      }
      if (target == null) return;

      final clamped = target.clamp(0.0, pos.maxScrollExtent);
      if ((clamped - pos.pixels).abs() < 1.0) return;

      await controller.animateTo(
        clamped,
        duration: Duration(milliseconds: pass == 0 ? 300 : 140),
        curve: Curves.easeOut,
      );
      // Let the sliver lay out the newly revealed rows before re-measuring.
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  /// Rough scroll offset for row [index], derived from the rows currently laid
  /// out: anchor on the nearest one and extrapolate with the local row pitch.
  static double? estimateOffset({
    required ScrollController controller,
    required int index,
    required int itemCount,
    required GlobalKey? Function(int index) keyAt,
  }) {
    if (!controller.hasClients) return null;
    final pos = controller.position;

    final measured = <int, double>{};
    for (var i = 0; i < itemCount; i++) {
      final box = keyAt(i)?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      final viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport == null) continue;
      measured[i] = viewport.getOffsetToReveal(box, 0.0).offset;
    }

    if (measured.isEmpty) {
      return (index * 180.0).clamp(0.0, pos.maxScrollExtent);
    }

    var anchor = measured.keys.first;
    for (final k in measured.keys) {
      if ((k - index).abs() < (anchor - index).abs()) anchor = k;
    }

    var pitch = 180.0;
    if (measured.length > 1) {
      int? nearest;
      for (final k in measured.keys) {
        if (k == anchor) continue;
        if (nearest == null || (k - anchor).abs() < (nearest - anchor).abs()) {
          nearest = k;
        }
      }
      if (nearest != null) {
        final di = (nearest - anchor).abs();
        final dh = (measured[nearest]! - measured[anchor]!).abs();
        final p = di == 0 ? 0.0 : dh / di;
        if (p.isFinite && p > 1) pitch = p;
      }
    }

    return (measured[anchor]! + (index - anchor) * pitch)
        .clamp(0.0, pos.maxScrollExtent);
  }
}
