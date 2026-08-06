// The create-pull-request dialog's title validator gates submission (#360):
// an empty or whitespace-only title shows its message and keeps the dialog
// open — for the dialog-wide Enter path and the Create PR button alike —
// while a valid title still submits. Before the fix the validator was
// accepted but never executed, because BaseTextField built a plain TextField
// that no Form could see. (The two branch dropdowns are FormFields already
// and were never affected.)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/git/models/branch.dart';
import 'package:flutter_gitui/features/repositories/dialogs/create_pull_request_dialog.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/components/base_button.dart';
import 'package:flutter_gitui/shared/components/base_text_field.dart';

const _feature = GitBranch(
  name: 'feature',
  fullName: 'refs/heads/feature',
  isLocal: true,
  isRemote: false,
  isCurrent: true,
);

const _main = GitBranch(
  name: 'main',
  fullName: 'refs/heads/main',
  isLocal: true,
  isRemote: false,
  isCurrent: false,
);

Future<void> _openDialog(
  WidgetTester tester,
  void Function(CreatePullRequestResult?) onClosed,
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
              showCreatePullRequestDialog(
                context,
                currentBranch: 'feature',
                availableBranches: const [_feature, _main],
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

/// The title field is the first BaseTextField in the dialog (the branch
/// dropdowns are FormFields without an editable, the description follows).
Finder get _titleField => find.byType(BaseTextField).first;

void main() {
  testWidgets('an empty title is rejected and keeps the dialog open', (
    tester,
  ) async {
    var closed = false;
    await _openDialog(tester, (_) => closed = true);

    // The title field autofocused; Enter must refuse to create.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(CreatePullRequestDialog), findsOneWidget);
    expect(find.text('Please enter a title'), findsOneWidget);
    expect(closed, isFalse);

    // A whitespace-only title is no better, and the button refuses too.
    await tester.enterText(_titleField, '   ');
    await tester.tap(find.widgetWithText(BaseButton, 'Create PR'));
    await tester.pumpAndSettle();
    expect(find.byType(CreatePullRequestDialog), findsOneWidget);
    expect(find.text('Please enter a title'), findsOneWidget);
    expect(closed, isFalse);
  });

  testWidgets('a valid title submits through Enter', (tester) async {
    CreatePullRequestResult? result;
    await _openDialog(tester, (value) => result = value);

    await tester.enterText(_titleField, 'Add the feature');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(CreatePullRequestDialog), findsNothing);
    expect(result, isNotNull);
    expect(result!.title, 'Add the feature');
    expect(result!.sourceBranch, 'feature');
    expect(result!.baseBranch, 'main');
  });
}
