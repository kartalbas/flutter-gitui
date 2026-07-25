// The toolbar used to scroll its actions out of sight when the window got
// narrow, which reads as the actions having disappeared: nothing indicates more
// exists. They now collapse into an overflow menu, so how many still fit as
// icons is the decision worth pinning - it decides whether an action is one
// click away or one click plus a menu.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/shared/widgets/overflow_action_bar.dart';

/// The real geometry: a small icon button is 32 wide with 8 between them.
const item = OverflowActionBar.itemExtent;
const gap = OverflowActionBar.spacing;

/// Width that fits exactly [count] icons and nothing else.
double widthFor(int count) => count * item + (count - 1) * gap;

void main() {
  group('visibleActionCount', () {
    test('shows everything when everything fits', () {
      expect(
        visibleActionCount(availableWidth: widthFor(6), actionCount: 6),
        6,
      );
      expect(visibleActionCount(availableWidth: 10000, actionCount: 6), 6);
    });

    test('reserves no slot for the menu when none is needed', () {
      // At exactly the width of all six, an overflow button would push one out
      // for nothing.
      expect(
        visibleActionCount(availableWidth: widthFor(6), actionCount: 6),
        6,
      );
    });

    test('gives up a slot to the overflow button once it is needed', () {
      // One pixel short of fitting all six: five icons plus their gaps plus
      // the menu button have to fit instead.
      final justUnder = widthFor(6) - 1;
      final visible = visibleActionCount(
        availableWidth: justUnder,
        actionCount: 6,
      );
      expect(visible, lessThan(6));
      expect(visible * (item + gap) + item, lessThanOrEqualTo(justUnder));
    });

    test('never claims more room than there is', () {
      // From one button's width upward, which is the narrowest the bar is ever
      // given: below that not even the overflow button fits, and the caller
      // clamps to at least this.
      for (var width = item; width <= widthFor(6); width += 7) {
        final visible = visibleActionCount(
          availableWidth: width,
          actionCount: 6,
        );
        final used = visible == 6 ? widthFor(6) : visible * (item + gap) + item;
        expect(
          used,
          lessThanOrEqualTo(width),
          reason: 'width $width showed $visible',
        );
      }
    });

    test('shows none rather than a negative count when there is no room', () {
      expect(visibleActionCount(availableWidth: 0, actionCount: 6), 0);
      expect(visibleActionCount(availableWidth: -50, actionCount: 6), 0);
      // Only the menu fits, so every action lives in it.
      expect(visibleActionCount(availableWidth: item, actionCount: 6), 0);
    });

    test('an empty bar needs nothing', () {
      expect(visibleActionCount(availableWidth: 500, actionCount: 0), 0);
    });

    test('a single action that fits needs no menu', () {
      expect(visibleActionCount(availableWidth: item, actionCount: 1), 1);
    });
  });
}
