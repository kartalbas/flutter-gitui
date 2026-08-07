// The branches screen as the keyboard drives it (#290): typing in the search
// field filters without firing any git command and without moving the roving
// highlight, ArrowDown typed in the field moves the list highlight while the
// caret stays in the field, and Enter checks out the highlighted branch.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/config/config_providers.dart';
import 'package:flutter_gitui/core/git/git_providers.dart';
import 'package:flutter_gitui/core/git/models/branch.dart';
import 'package:flutter_gitui/features/branches/branches_screen.dart';

import '../../skin/pump_under_skin.dart';

/// Records checkouts instead of running git, so an assertion reads exactly
/// which branch the keyboard activated — and that typing activated none.
class _RecordingGitActions extends GitActions {
  _RecordingGitActions(super.ref, this.switchedTo);

  final List<String> switchedTo;

  @override
  Future<void> switchBranch(
    String branchName, {
    bool createIfMissing = false,
    bool skipRefresh = false,
  }) async {
    switchedTo.add(branchName);
  }
}

GitBranch _branch(String name, {bool isCurrent = false}) => GitBranch(
  name: name,
  fullName: 'refs/heads/$name',
  isLocal: true,
  isRemote: false,
  isCurrent: isCurrent,
);

void main() {
  Future<List<String>> pumpScreen(WidgetTester tester) async {
    final switchedTo = <String>[];
    await pumpUnderSkin(
      tester,
      home: const BranchesScreen(),
      // The window this test was written against; the funnel's desktop
      // default would be a second change in the same edit.
      surface: null,
      overrides: [
        currentRepositoryPathProvider.overrideWith((ref) => '/repo'),
        localBranchesProvider.overrideWith(
          (ref) async => [
            _branch('main', isCurrent: true),
            _branch('alpha'),
            _branch('beta'),
            _branch('gamma'),
          ],
        ),
        remoteBranchesProvider.overrideWith((ref) async => const <GitBranch>[]),
        gitActionsProvider.overrideWith(
          (ref) => _RecordingGitActions(ref, switchedTo),
        ),
      ],
    );
    await tester.pumpAndSettle();
    return switchedTo;
  }

  testWidgets('typing filters without firing a command and Enter activates '
      'the branch the arrows highlighted', (tester) async {
    final switchedTo = await pumpScreen(tester);
    expect(find.text('beta'), findsOneWidget);

    // Focus the search field and type. The text filters the list down to
    // 'main' and 'gamma'; no git command fires and the highlight is left
    // where it was.
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ma');
    await tester.pumpAndSettle();
    expect(find.text('beta'), findsNothing);
    expect(find.text('alpha'), findsNothing);
    expect(find.text('gamma'), findsOneWidget);
    expect(switchedTo, isEmpty);

    // Enter activates the highlighted row, which is still the first one —
    // the current branch, which has nothing to check out.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(switchedTo, isEmpty);

    // ArrowDown typed in the field moves the list highlight while the caret
    // stays in the field: the editable keeps primary focus, typing goes on.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    expect(editable.widget.focusNode.hasPrimaryFocus, isTrue);

    // Enter now checks out the branch under the highlight: the second of
    // the filtered rows (main, gamma).
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(switchedTo, ['gamma']);
  });

  testWidgets('arrows on the focused list walk rows and Enter checks out', (
    tester,
  ) async {
    final switchedTo = await pumpScreen(tester);

    // The list holds initial focus; two ArrowDowns from the initial
    // highlight (main) land on beta, and Enter checks it out.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(switchedTo, ['beta']);
  });
}
