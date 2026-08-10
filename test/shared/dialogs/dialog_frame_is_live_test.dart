/// Which door a dialog goes through decides whether its frame can change.
///
/// `Overlays.dialog` takes a `DialogSpec` VALUE, and a value does not change -
/// so a dialog that must recount its heading, or enable its affirmative action
/// once a field validates, cannot use it. That was never a defect in the door;
/// it was that this was the ONLY door, which left 46 dialogs unable to reach
/// the contract at all and therefore still on Material's own route.
///
/// `Overlays.dialogFrom` is the other door: the application's own widget is
/// mounted inside the route, and whatever state it creates there states the
/// dialog through `SkinDialog` on every build. Both doors push the SAME route
/// and compose the SAME surface. The two tests below pin exactly where they
/// differ, so neither can quietly grow the other's behaviour.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../../skin/pump_under_skin.dart';

/// A screen with one trigger, keyed `open`.
Widget _screenOpening(void Function(BuildContext context) open) => Center(
  child: Builder(
    builder: (BuildContext inner) => GestureDetector(
      key: const ValueKey<String>('open'),
      behavior: HitTestBehavior.opaque,
      onTap: () => open(inner),
      child: const SizedBox(width: 80, height: 40),
    ),
  ),
);

Future<void> _tapOpen(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('open')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a dialog whose state is created INSIDE the route states its '
      'own frame on every build', (WidgetTester tester) async {
    await pumpUnderSkin(
      tester,
      home: _screenOpening(
        (BuildContext context) => Overlays.dialogFrom<void>(
          context,
          route: const DialogRouteSpec(title: 'Rename branch'),
          builder: (BuildContext _) => const _CountingDialog(),
        ),
      ),
    );

    await _tapOpen(tester);
    // The affirmative action's label counts, from state that did not exist
    // when the route was pushed.
    expect(find.text('Rename (0)'), findsOneWidget);

    await tester.tap(find.text('count'));
    await tester.pumpAndSettle();
    expect(
      find.text('Rename (1)'),
      findsOneWidget,
      reason: 'the frame is rebuilt from the State the route mounted',
    );
    expect(find.text('Rename (0)'), findsNothing);
  });

  testWidgets('the value door shows exactly what it was handed, and goes on '
      'showing it - which is why the other door exists', (
    WidgetTester tester,
  ) async {
    late StateSetter refresh;
    String title = 'Rename branch';

    await pumpUnderSkin(
      tester,
      home: StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          refresh = setState;
          return _screenOpening(
            (BuildContext inner) => Overlays.dialog<void>(
              inner,
              DialogSpec(
                title: title,
                content: const ContentPort(SizedBox.shrink()),
              ),
            ),
          );
        },
      ),
    );

    await _tapOpen(tester);
    expect(find.text('Rename branch'), findsOneWidget);

    // The screen behind the barrier changes its mind. The open dialog
    // does not follow: it was handed a value, and a route is its own
    // subtree with nothing in it depending on the caller's state.
    refresh(() => title = 'Rename to main');
    await tester.pumpAndSettle();
    expect(find.text('Rename branch'), findsOneWidget);
    expect(
      find.text('Rename to main'),
      findsNothing,
      reason:
          'a dialog that has to change says so through '
          'Overlays.dialogFrom instead',
    );
  });
}

/// A dialog whose frame depends on state that only exists inside the route.
class _CountingDialog extends StatefulWidget {
  const _CountingDialog();

  @override
  State<_CountingDialog> createState() => _CountingDialogState();
}

class _CountingDialogState extends State<_CountingDialog> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => SkinDialog(
    spec: DialogSpec(
      title: 'Rename branch',
      content: ContentPort(
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _count++),
          child: const Text('count', textDirection: TextDirection.ltr),
        ),
      ),
      actions: <DialogAction>[
        DialogAction(
          label: 'Rename ($_count)',
          role: DialogActionRole.affirmative,
          onPressed: _count > 0 ? () {} : null,
        ),
      ],
    ),
  );
}
