// The rename-branch dialog's validator gates submission (#360): an empty
// name shows its message and keeps the dialog open — for the dialog-wide
// Enter path and the Rename button alike — while a valid name still submits.
// Before the fix the validator was accepted but never executed, because
// BaseTextField built a plain TextField that no Form could see.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/git/models/branch.dart';
import 'package:flutter_gitui/features/branches/dialogs/rename_branch_dialog.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/components/base_button.dart';
import '../../skin/pump_under_skin.dart';

const _branch = GitBranch(
  name: 'feature',
  fullName: 'refs/heads/feature',
  isLocal: true,
  isRemote: false,
  isCurrent: true,
);

Future<void> _openDialog(
  WidgetTester tester,
  void Function(String?) onClosed,
) async {
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
              showDialog<String>(
                context: context,
                builder: (_) => const RenameBranchDialog(branch: _branch),
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

void main() {
  testWidgets('an empty name is rejected and keeps the dialog open', (
    tester,
  ) async {
    var closed = false;
    await _openDialog(tester, (_) => closed = true);

    // Clear the prefilled name, then try to submit with Enter.
    await tester.enterText(find.byType(TextField), '');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(RenameBranchDialog), findsOneWidget);
    expect(find.text('Please enter a branch name'), findsOneWidget);
    expect(closed, isFalse);

    // A rejected Enter must leave the user in the field, still typing.
    final fieldNode = tester
        .state<EditableTextState>(find.byType(EditableText))
        .widget
        .focusNode;
    expect(fieldNode.hasPrimaryFocus, isTrue);

    // The primary button must refuse too, not only the Enter path.
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect(find.byType(RenameBranchDialog), findsOneWidget);
    expect(closed, isFalse);
  });

  testWidgets('a valid name submits through Enter', (tester) async {
    String? result;
    await _openDialog(tester, (value) => result = value);

    await tester.enterText(find.byType(TextField), 'hotfix');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(RenameBranchDialog), findsNothing);
    expect(result, 'hotfix');
  });
}
