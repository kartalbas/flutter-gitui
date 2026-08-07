// The branch-search dialog must offer a button for the thing it exists to do
// (#398).
//
// Applying the typed filter used to have no action at all: it was reachable
// only through the dialog-wide Enter, so the row showed a Clear and a Cancel -
// two ways to abandon the typing - and nothing to complete it. Enter is a
// shortcut for an action, not a substitute for one, so this file pins both
// halves: the visible affirmative action applies the filter, and Enter still
// applies the same filter.
//
// It also pins the roles the row declares, because two of the three actions
// leave the dialog and only one of them is a dismissal: Clear pops '' and the
// caller drops its filter, while Cancel and Escape pop null and the caller
// keeps it. Those cannot both be dismissive - that role is defined as the one
// Escape is the keyboard equivalent of.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/features/branches/dialogs/search_branches_dialog.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/components/base_button.dart';
import 'package:flutter_gitui/shared/components/base_dialog.dart';

/// Opens the dialog over a host page and reports what it returned:
/// the typed query, `''` when the filter was cleared, `null` when cancelled.
Future<void> _openDialog(
  WidgetTester tester,
  void Function(String?) onClosed,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => BaseButton(
            label: 'open',
            onPressed: () {
              showDialog<String>(
                context: context,
                builder: (_) => const SearchBranchesDialog(),
              ).then(onClosed);
            },
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

List<DialogAction> _actions(WidgetTester tester) =>
    tester.widget<BaseDialog>(find.byType(BaseDialog)).actions!;

void main() {
  testWidgets('applying the typed filter has a button of its own', (
    tester,
  ) async {
    String? result;
    var closed = false;
    await _openDialog(tester, (value) {
      result = value;
      closed = true;
    });

    final affirmative = _actions(
      tester,
    ).where((action) => action.role == DialogActionRole.affirmative).toList();
    expect(
      affirmative,
      hasLength(1),
      reason:
          'the dialog exists to apply a filter, so exactly one of its visible '
          'actions must carry the affirmative role',
    );

    await tester.enterText(find.byType(TextField), 'feature/');
    await tester.pump();
    await tester.tap(find.text(affirmative.single.label));
    await tester.pumpAndSettle();

    expect(find.byType(SearchBranchesDialog), findsNothing);
    expect(closed, isTrue);
    expect(
      result,
      'feature/',
      reason: 'the affirmative button must report the typed filter',
    );
  });

  testWidgets('Enter still applies the filter from the field', (tester) async {
    String? result;
    await _openDialog(tester, (value) => result = value);

    await tester.enterText(find.byType(TextField), 'release/');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(SearchBranchesDialog), findsNothing);
    expect(
      result,
      'release/',
      reason:
          'the button is an addition to the keyboard path, not a replacement '
          'for it',
    );
  });

  testWidgets('only the action that changes nothing is the dismissive one', (
    tester,
  ) async {
    await _openDialog(tester, (_) {});
    final l10n = AppLocalizations.of(
      tester.element(find.byType(SearchBranchesDialog)),
    )!;

    final actions = _actions(tester);
    final clear = actions.firstWhere((action) => action.label == l10n.clear);
    final cancel = actions.firstWhere((action) => action.label == l10n.cancel);

    // Cancel is the only dismissal: it is what Escape does, and Escape is the
    // definition of the dismissive role. Clear leaves with a result the caller
    // acts on, which is neutral's "a second way forward that is not *the* way
    // forward" - the same shape as AdvancedFiltersDialog's Reset all. Giving
    // both the same role would leave a skin that binds Escape to the
    // dismissive action with two candidates, one of which wipes the filter.
    expect(cancel.role, DialogActionRole.dismissive);
    expect(clear.role, DialogActionRole.neutral);
    expect(
      clear.role,
      isNot(cancel.role),
      reason:
          'two actions with different outcomes must not be drawn identically',
    );

    // And the affirmative action is last, so the row reads towards the way
    // forward rather than away from it.
    expect(actions.last.role, DialogActionRole.affirmative);
  });

  testWidgets('Clear reports an empty filter where Escape reports nothing', (
    tester,
  ) async {
    String? result;
    var closed = false;
    await _openDialog(tester, (value) {
      result = value;
      closed = true;
    });
    final l10n = AppLocalizations.of(
      tester.element(find.byType(SearchBranchesDialog)),
    )!;

    await tester.enterText(find.byType(TextField), 'feature/');
    await tester.pump();
    await tester.tap(find.text(l10n.clear));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(
      result,
      isEmpty,
      reason: 'clearing drops the filter rather than cancelling the dialog',
    );
  });

  // The other half of the same statement, and the reason Clear and Cancel
  // carry different roles: Escape reports nothing, so a caller that had a
  // filter applied keeps it.
  testWidgets('Escape reports nothing at all', (tester) async {
    String? escaped = 'unset';
    var closed = false;
    await _openDialog(tester, (value) {
      escaped = value;
      closed = true;
    });

    await tester.enterText(find.byType(TextField), 'feature/');
    await tester.pump();

    // The Escape ladder: a filled BaseTextField spends the first Escape on
    // emptying itself (escapeClears), so correcting a typo cannot throw the
    // keyboard out of the field. That rung changes the field and nothing
    // else - the dialog is still open and the caller has heard nothing.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(SearchBranchesDialog), findsOneWidget);
    expect(closed, isFalse);

    // The next rung leaves the dialog, and this is where Escape and Clear
    // part company: Escape reports null, Clear reports ''.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(SearchBranchesDialog), findsNothing);
    expect(closed, isTrue);
    expect(
      escaped,
      isNull,
      reason:
          'Escape is the dismissal: it must not stand in for clearing the '
          'filter',
    );
  });
}
