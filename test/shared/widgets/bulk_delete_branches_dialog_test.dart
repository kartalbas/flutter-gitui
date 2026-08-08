// The shape of the bulk branch delete confirmation (#397, #403).
//
// This is the most destructive prompt in the application - it deletes every
// unprotected branch at once - and it used to offer two destructive actions
// and nothing that meant "no". What is pinned here is what that cost the
// user:
//
// 1. There is a visible way out, it deletes nothing, and Escape does the same
//    thing. A dialog whose only exit is a key the user has to know about is
//    not a confirmation, it is a choice between two deletions.
// 2. No action is the affirmative one. The affirmative action is the one a
//    design language may draw as the dialog's default (Cupertino's default
//    action, Fluent's leading position), and making a bulk branch deletion
//    the default is exactly the outcome #397 refuses.
// 3. Delete reports precisely the branches that are still ticked, and the
//    force flag is the state of the force opt-in - not of a second button
//    sitting one button-width from the safe one.
//
// Everything is driven through the rendered dialog: rows are addressed by the
// keys the dialog publishes for them, actions by their labels, and the result
// is read off the route's future. Nothing here reaches into the dialog's
// state, so the test still describes the user's path if the widget is rebuilt.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/git/models/branch.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/components/base_button.dart';
import 'package:flutter_gitui/shared/components/base_dialog.dart';
import 'package:flutter_gitui/shared/widgets/branch_switcher.dart';
import '../../skin/pump_under_skin.dart';

GitBranch _branch(String name) => GitBranch(
  name: name,
  fullName: 'refs/heads/$name',
  isLocal: true,
  isRemote: false,
  isCurrent: false,
);

/// Two branches `git branch -d` would take and one it would refuse, so every
/// assertion can tell the deletions that lose nothing from the ones that do.
final _branches = [_branch('feature'), _branch('spike'), _branch('hotfix')];
const _deletableWithoutForce = {'feature', 'hotfix'};

/// One opened dialog and what it reported when it closed.
class _Session {
  Object? result;
  bool hasClosed = false;
}

Future<_Session> _openDialog(WidgetTester tester) async {
  final session = _Session();
  await tester.pumpWidget(
    MaterialApp(
      builder: (BuildContext context, Widget? child) =>
          installSkinUnderTest(child ?? const SizedBox.shrink()),

      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => BaseButton(
            label: 'open',
            onPressed: () {
              showDialog<Object?>(
                context: context,
                builder: (_) => BulkDeleteBranchesDialog(
                  branches: _branches,
                  deletableWithoutForce: _deletableWithoutForce,
                ),
              ).then((value) {
                session.result = value;
                session.hasClosed = true;
              });
            },
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(find.byType(BulkDeleteBranchesDialog), findsOneWidget);
  return session;
}

/// The dialog's declared actions, as data - which is what a role lives on.
List<DialogAction> _declaredActions(WidgetTester tester) =>
    tester.widget<BaseDialog>(find.byType(BaseDialog)).actions ??
    const <DialogAction>[];

/// Unticks the row of [branchName] through its checkbox, the way the user
/// does.
Future<void> _untick(WidgetTester tester, String branchName) async {
  await tester.tap(
    find.byKey(BulkDeleteBranchesDialog.checkboxKeyFor(branchName)),
  );
  await tester.pump();
}

Future<void> _tapAction(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(BaseButton, label));
  await tester.pumpAndSettle();
}

/// The names the dialog reported, in the order it reported them.
List<String> _reportedNames(Object? result) => (result as BulkDeleteResult)
    .selectedBranches
    .map((branch) => branch.name)
    .toList();

void main() {
  group('the dialog can be told no', () {
    testWidgets('Cancel closes it and deletes nothing', (tester) async {
      final session = await _openDialog(tester);

      await _tapAction(tester, 'Cancel');

      expect(find.byType(BulkDeleteBranchesDialog), findsNothing);
      expect(session.hasClosed, isTrue);
      expect(
        session.result,
        isNull,
        reason:
            'a dismissal must report nothing at all, or the caller cannot '
            'tell "the user said no" from "the user selected no branches"',
      );
    });

    testWidgets('Escape still closes it and deletes nothing', (tester) async {
      final session = await _openDialog(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(BulkDeleteBranchesDialog), findsNothing);
      expect(session.hasClosed, isTrue);
      expect(session.result, isNull);
    });

    testWidgets('the dismissal is the only action that is not destructive', (
      tester,
    ) async {
      await _openDialog(tester);
      final actions = _declaredActions(tester);

      expect(
        actions.map((action) => action.role),
        containsAll(<DialogActionRole>[
          DialogActionRole.dismissive,
          DialogActionRole.destructive,
        ]),
      );
      expect(
        actions.where((a) => a.role == DialogActionRole.dismissive),
        hasLength(1),
      );
    });

    testWidgets('no action is the affirmative one', (tester) async {
      await _openDialog(tester);

      expect(
        _declaredActions(
          tester,
        ).where((action) => action.role == DialogActionRole.affirmative),
        isEmpty,
        reason:
            'the affirmative action is the one a design language may draw as '
            'the default, so an affirmative here would make a bulk branch '
            'deletion the default',
      );
    });
  });

  group('the delete reports what was ticked', () {
    testWidgets('every branch is ticked on open', (tester) async {
      final session = await _openDialog(tester);

      await _tapAction(tester, 'Delete');

      expect(
        _reportedNames(session.result),
        ['feature', 'spike', 'hotfix'],
        reason: 'the dialog opens with the whole list ticked',
      );
    });

    testWidgets('unticked branches are left out, in list order', (
      tester,
    ) async {
      final session = await _openDialog(tester);

      await _untick(tester, 'spike');
      await _untick(tester, 'hotfix');
      await _tapAction(tester, 'Delete');

      expect(_reportedNames(session.result), ['feature']);
    });

    testWidgets('with nothing ticked the delete cannot be run at all', (
      tester,
    ) async {
      final session = await _openDialog(tester);

      for (final branch in _branches) {
        await _untick(tester, branch.name);
      }

      final delete = _declaredActions(
        tester,
      ).firstWhere((action) => action.role == DialogActionRole.destructive);
      expect(delete.isEnabled, isFalse);

      await tester.tap(
        find.widgetWithText(BaseButton, 'Delete'),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(find.byType(BulkDeleteBranchesDialog), findsOneWidget);
      expect(session.hasClosed, isFalse);
    });
  });

  group('force is an opt-in, not a second button', () {
    testWidgets('the delete is unforced until the checkbox is ticked', (
      tester,
    ) async {
      final session = await _openDialog(tester);

      expect(
        _declaredActions(
          tester,
        ).where((action) => action.role == DialogActionRole.destructive),
        hasLength(1),
        reason:
            'a second destructive button would put `git branch -D` one '
            'button-width from `git branch -d`',
      );

      await _tapAction(tester, 'Delete');
      expect((session.result as BulkDeleteResult).force, isFalse);
    });

    testWidgets('ticking force relabels the action and forces the delete', (
      tester,
    ) async {
      final session = await _openDialog(tester);

      await tester.tap(find.byKey(BulkDeleteBranchesDialog.forceCheckboxKey));
      await tester.pump();

      // The label states which git command is about to run, so force is never
      // a hidden mode.
      expect(find.widgetWithText(BaseButton, 'Force Delete'), findsOneWidget);
      expect(find.widgetWithText(BaseButton, 'Delete'), findsNothing);

      await _tapAction(tester, 'Force Delete');
      final result = session.result as BulkDeleteResult;
      expect(result.force, isTrue);
      expect(_reportedNames(session.result), ['feature', 'spike', 'hotfix']);
    });

    testWidgets('an unforced delete says which branches it will keep', (
      tester,
    ) async {
      await _openDialog(tester);

      // 'spike' is the one branch outside _deletableWithoutForce, so
      // `git branch -d` would refuse exactly it - which the two-button
      // version never said.
      expect(
        find.text(
          '1 selected branch is not fully merged. An ordinary deletion keeps '
          'it, so no commits are lost.',
        ),
        findsOneWidget,
      );

      // Untick it and the notice has nothing left to report.
      await _untick(tester, 'spike');
      expect(find.textContaining('not fully merged'), findsNothing);
    });

    testWidgets('what force costs is on screen before it is ticked', (
      tester,
    ) async {
      await _openDialog(tester);

      // The standing subtitle of the opt-in, not a confirmation of a choice
      // already made: a warning that only appears after the click explains
      // the decision to someone who has already taken it.
      expect(
        find.text(
          'Force delete also removes the unmerged branches. Their commits '
          'then survive only in the reflog.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('force is not offered when it would change nothing', (
      tester,
    ) async {
      final session = await _openDialog(tester);

      // With the one unmerged branch out of the selection, `-D` and `-d` do
      // the same thing, so the checkbox that arms `-D` is not on screen at
      // all - it could only arm a mode for some later selection.
      await _untick(tester, 'spike');
      expect(
        find.byKey(BulkDeleteBranchesDialog.forceCheckboxKey),
        findsNothing,
      );

      await _tapAction(tester, 'Delete');
      expect((session.result as BulkDeleteResult).force, isFalse);
    });

    testWidgets('a hidden force opt-in does not stay armed', (tester) async {
      final session = await _openDialog(tester);

      await tester.tap(find.byKey(BulkDeleteBranchesDialog.forceCheckboxKey));
      await tester.pump();
      expect(find.widgetWithText(BaseButton, 'Force Delete'), findsOneWidget);

      // Unticking the only unmerged branch takes the opt-in off screen. It
      // must not come back ticked when another unmerged branch is selected
      // again, or `-D` would be armed with nothing on screen saying so.
      await _untick(tester, 'spike');
      await _untick(tester, 'spike');

      expect(find.widgetWithText(BaseButton, 'Delete'), findsOneWidget);
      await _tapAction(tester, 'Delete');
      expect((session.result as BulkDeleteResult).force, isFalse);
    });
  });

  testWidgets('each branch carries its merged status in words', (tester) async {
    await _openDialog(tester);

    // The pills are the only thing telling the user which deletions are
    // recoverable, so they come from the localizations like everything else
    // (#403) - here read back in the default locale.
    expect(find.text('merged'), findsNWidgets(2));
    expect(find.text('unmerged'), findsOneWidget);
    expect(find.text('3 branches selected for deletion'), findsOneWidget);

    await _untick(tester, 'spike');
    await _untick(tester, 'hotfix');
    expect(find.text('1 branch selected for deletion'), findsOneWidget);
  });
}
