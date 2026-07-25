import 'package:flutter/gestures.dart' show kDoubleTapTimeout;

/// Recognises a double click from the interval between taps.
///
/// Flutter's own `onDoubleTap` cannot be used on rows that must feel instant: a
/// gesture detector carrying both `onTap` and `onDoubleTap` holds the gesture
/// arena until the double-tap window closes, so the single tap only fires
/// [kDoubleTapTimeout] (300 ms) after the button is released. Rows fed through
/// this tracker keep `onDoubleTap` off the detector, act on the single tap
/// immediately, and still recognise the double click.
///
/// This is only safe where the single-tap action is cheap and repeatable
/// (selecting or highlighting a row), because it always runs before the second
/// click can arrive.
class DoubleTapTracker {
  DoubleTapTracker({this.timeout = kDoubleTapTimeout});

  /// How close two taps must be to count as a double click.
  final Duration timeout;

  Object? _lastTarget;
  DateTime? _lastTapAt;

  /// Records a tap on [target] at [at] and reports whether it completes a
  /// double click.
  ///
  /// [target] identifies the row, so two quick clicks on *different* rows stay
  /// two single clicks instead of being read as a double click.
  bool registerTap(Object target, DateTime at) {
    final lastTarget = _lastTarget;
    final lastTapAt = _lastTapAt;

    final isDouble =
        lastTapAt != null &&
        identical(lastTarget, target) &&
        at.difference(lastTapAt) <= timeout;

    if (isDouble) {
      // Consumed: a third quick click starts a new pair rather than reporting
      // a second double click.
      _lastTarget = null;
      _lastTapAt = null;
      return true;
    }

    _lastTarget = target;
    _lastTapAt = at;
    return false;
  }

  /// Forgets the pending tap, so the next click starts a new pair.
  void reset() {
    _lastTarget = null;
    _lastTapAt = null;
  }
}
