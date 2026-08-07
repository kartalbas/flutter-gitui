// Every dialog in the app opened once in its data-bearing state, asserting
// the layout throws nothing (#370). BaseDialog scrolls its content, a scroll
// view hands its child unbounded height, and a Column with unbounded height
// has no remaining space to distribute - so a direct Expanded, Spacer or tight
// Flexible child of the content Column is a RenderFlex error, not a layout.
// The repository switcher (Ctrl+R) shipped exactly that and crashed on every
// open; this sweep is the assertion that would have caught it the day it was
// written, applied to the whole dialog population. It found the same defect
// in the reflog dialog, the running-bisect view and the mid-rebase view (a
// Spacer, which no grep for Expanded shows), plus a different layout error:
// the update dialog's three actions overflowed BaseDialog's actions row.
//
// The population itself lives in dialog_population.dart, shared with
// dialog_keyboard_contract_sweep_test.dart, together with the census that
// fails when a dialog exists that neither sweep covers. Two separate lists of
// "all dialogs" would drift the first time someone added a dialog and updated
// only one of them, so there is exactly one.

import 'package:flutter_test/flutter_test.dart';

import 'dialog_population.dart';

void main() {
  setUpAll(prepareDialogFixtures);
  tearDownAll(disposeDialogFixtures);

  for (final dialogCase in dialogPopulation()) {
    testWidgets('${dialogCase.name} lays out', (tester) async {
      await tester.pumpWidget(
        // The route's own future says nothing about the layout, so this sweep
        // drops it; the keyboard sweep is the one that reads what closing
        // reported.
        dialogHostApp(dialogCase: dialogCase, onOpened: (_) {}),
      );

      expect(
        await openDialogOfCase(tester),
        isNull,
        reason: '${dialogCase.name} threw while laying out',
      );
      for (final text in dialogCase.expectedTexts) {
        expect(
          find.text(text),
          findsOneWidget,
          reason: '${dialogCase.name} should show "$text"',
        );
      }
    });
  }
}
