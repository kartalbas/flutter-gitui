// The commit dialog's validator gates the commit (#360): an empty or
// whitespace-only message shows its error and keeps the dialog open — for the
// dialog-wide Enter path and the Commit button alike — and the message never
// reaches GitActions.commit; a real message still commits and closes. Before
// the fix the validator was accepted but never executed, because
// BaseTextField built a plain TextField that no Form could see.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/git/git_providers.dart';
import 'package:flutter_gitui/core/git/models/file_status.dart';
import 'package:flutter_gitui/features/changes/widgets/commit_dialog.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/components/base_button.dart';

/// Records commit calls instead of touching git, so the tests can assert an
/// invalid message never reaches the action layer.
class _RecordingGitActions extends GitActions {
  _RecordingGitActions(super.ref, this.log);

  final List<String> log;

  @override
  Future<void> commit(String message, {bool amend = false}) async {
    log.add(message);
  }
}

Future<void> _openDialog(WidgetTester tester, List<String> committed) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gitActionsProvider.overrideWith(
          (ref) => _RecordingGitActions(ref, committed),
        ),
        stagedFilesProvider.overrideWith((ref) => const <FileStatus>[]),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => BaseButton(
              label: 'open',
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (_) => const CommitDialog(),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an empty message is rejected and never reaches git', (
    tester,
  ) async {
    final committed = <String>[];
    await _openDialog(tester, committed);

    // The Commit button must refuse: the dialog stays open, the field shows
    // its message, and no commit was attempted.
    await tester.tap(find.widgetWithText(BaseButton, 'Commit'));
    await tester.pumpAndSettle();
    expect(find.byType(CommitDialog), findsOneWidget);
    expect(find.text('Commit message is required'), findsOneWidget);
    expect(committed, isEmpty);

    // The Enter path must refuse too. The message field is multiline (Enter
    // inside it writes a newline), so leave it with Tab first — Enter then
    // fires the dialog's submit from wherever focus landed.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(CommitDialog), findsOneWidget);
    expect(committed, isEmpty);
  });

  testWidgets('a whitespace-only message is rejected', (tester) async {
    final committed = <String>[];
    await _openDialog(tester, committed);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.widgetWithText(BaseButton, 'Commit'));
    await tester.pumpAndSettle();

    expect(find.byType(CommitDialog), findsOneWidget);
    expect(find.text('Commit message is required'), findsOneWidget);
    expect(committed, isEmpty);
  });

  testWidgets('a real message commits and closes the dialog', (tester) async {
    final committed = <String>[];
    await _openDialog(tester, committed);

    await tester.enterText(find.byType(TextField), 'fix: proper message');
    await tester.tap(find.widgetWithText(BaseButton, 'Commit'));
    await tester.pumpAndSettle();

    expect(find.byType(CommitDialog), findsNothing);
    expect(committed, ['fix: proper message']);
  });
}
