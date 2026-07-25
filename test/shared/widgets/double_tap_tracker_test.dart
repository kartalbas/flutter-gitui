// The tracker exists so tree rows can act on a click immediately instead of
// waiting out Flutter's 300 ms double-tap window, so the rules it applies -
// what counts as a double click, and what must not - are pinned here. Times
// are passed in rather than read from the clock, so the suite is deterministic.

import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/shared/widgets/double_tap_tracker.dart';

void main() {
  final row = Object();
  final otherRow = Object();
  final start = DateTime.utc(2026, 1, 1);

  group('DoubleTapTracker', () {
    test('a single tap is never a double click', () {
      final tracker = DoubleTapTracker();
      expect(tracker.registerTap(row, start), isFalse);
    });

    test('a second tap within the window completes a double click', () {
      final tracker = DoubleTapTracker();
      tracker.registerTap(row, start);
      expect(
        tracker.registerTap(row, start.add(const Duration(milliseconds: 120))),
        isTrue,
      );
    });

    test('the window boundary still counts', () {
      final tracker = DoubleTapTracker();
      tracker.registerTap(row, start);
      expect(tracker.registerTap(row, start.add(kDoubleTapTimeout)), isTrue);
    });

    test('a tap after the window is a fresh single tap', () {
      final tracker = DoubleTapTracker();
      tracker.registerTap(row, start);
      expect(
        tracker.registerTap(
          row,
          start.add(kDoubleTapTimeout + const Duration(milliseconds: 1)),
        ),
        isFalse,
      );
    });

    test('two quick taps on different rows stay two single taps', () {
      final tracker = DoubleTapTracker();
      tracker.registerTap(row, start);
      expect(
        tracker.registerTap(
          otherRow,
          start.add(const Duration(milliseconds: 50)),
        ),
        isFalse,
      );
    });

    test('a third quick tap starts a new pair instead of doubling again', () {
      final tracker = DoubleTapTracker();
      tracker.registerTap(row, start);
      expect(
        tracker.registerTap(row, start.add(const Duration(milliseconds: 100))),
        isTrue,
      );
      // The double consumed both taps, so the next click is a single again.
      expect(
        tracker.registerTap(row, start.add(const Duration(milliseconds: 150))),
        isFalse,
      );
      // ...and the one after it can complete a new double.
      expect(
        tracker.registerTap(row, start.add(const Duration(milliseconds: 200))),
        isTrue,
      );
    });

    test('reset drops the pending tap', () {
      final tracker = DoubleTapTracker();
      tracker.registerTap(row, start);
      tracker.reset();
      expect(
        tracker.registerTap(row, start.add(const Duration(milliseconds: 50))),
        isFalse,
      );
    });
  });
}
