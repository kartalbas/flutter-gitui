// Escape's one rule made executable: the innermost enabled scope consumes the
// key, a disabled scope is transparent so the next one out gets it, and with
// nothing enabled the key bubbles through untouched. The scope itself must
// never appear in the Tab order.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/shared/widgets/base_dismiss_scope.dart';
import '../../skin/pump_under_skin.dart';

void main() {
  late int outerDismissed;
  late int innerDismissed;
  late int escapedPastBoth;

  setUp(() {
    outerDismissed = 0;
    innerDismissed = 0;
    escapedPastBoth = 0;
  });

  Future<void> pumpNested(
    WidgetTester tester, {
    required bool outerEnabled,
    required bool innerEnabled,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (BuildContext context, Widget? child) =>
            installSkinUnderTest(child ?? const SizedBox.shrink()),

        home: Scaffold(
          // A recorder above both scopes: whatever they ignore lands here,
          // proving the key bubbled through rather than vanishing.
          body: Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                escapedPastBoth++;
              }
              return KeyEventResult.ignored;
            },
            child: BaseDismissScope(
              enabled: outerEnabled,
              onDismiss: () => outerDismissed++,
              child: BaseDismissScope(
                enabled: innerEnabled,
                onDismiss: () => innerDismissed++,
                child: Focus(autofocus: true, child: const SizedBox.shrink()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the innermost enabled scope wins', (tester) async {
    await pumpNested(tester, outerEnabled: true, innerEnabled: true);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(innerDismissed, 1);
    expect(outerDismissed, 0);
    expect(escapedPastBoth, 0);
  });

  testWidgets(
    'a disabled inner scope lets Escape reach the enabled outer one',
    (tester) async {
      await pumpNested(tester, outerEnabled: true, innerEnabled: false);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(innerDismissed, 0);
      expect(outerDismissed, 1);
      expect(escapedPastBoth, 0);
    },
  );

  testWidgets('with nothing enabled, Escape bubbles through untouched', (
    tester,
  ) async {
    await pumpNested(tester, outerEnabled: false, innerEnabled: false);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(innerDismissed, 0);
    expect(outerDismissed, 0);
    expect(escapedPastBoth, 1);
  });

  testWidgets('other keys pass through an enabled scope', (tester) async {
    await pumpNested(tester, outerEnabled: true, innerEnabled: true);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(innerDismissed, 0);
    expect(outerDismissed, 0);
  });

  testWidgets('a scope is never a Tab stop', (tester) async {
    final first = FocusNode(debugLabel: 'first');
    final second = FocusNode(debugLabel: 'second');
    await tester.pumpWidget(
      MaterialApp(
        builder: (BuildContext context, Widget? child) =>
            installSkinUnderTest(child ?? const SizedBox.shrink()),

        home: Scaffold(
          body: Column(
            children: [
              Focus(focusNode: first, child: const SizedBox.shrink()),
              BaseDismissScope(
                enabled: true,
                onDismiss: () {},
                child: Focus(focusNode: second, child: const SizedBox.shrink()),
              ),
            ],
          ),
        ),
      ),
    );
    first.requestFocus();
    await tester.pump();

    // One Tab must land inside the scope's child directly; the scope's own
    // node never holds focus.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(second.hasPrimaryFocus, isTrue);
  });
}
