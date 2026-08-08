// The rename-remote dialog's validator gates submission (#360): an empty
// name or a name with spaces shows its message and keeps the dialog open —
// for the dialog-wide Enter path and the Rename button alike — while a valid
// name still submits. Before the fix the validator was accepted but never
// executed, because BaseTextField built a plain TextField that no Form could
// see.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/git/models/remote.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/components/base_button.dart';
import 'package:flutter_gitui/shared/dialogs/rename_remote_dialog.dart';
import '../../skin/pump_under_skin.dart';

const _remote = GitRemote(
  name: 'origin',
  fetchUrl: 'https://example.com/repo.git',
  pushUrl: 'https://example.com/repo.git',
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
                builder: (_) => const RenameRemoteDialog(remote: _remote),
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
  testWidgets('an empty or space-carrying name is rejected', (tester) async {
    var closed = false;
    await _openDialog(tester, (_) => closed = true);

    // Clear the prefilled name, then try to submit with Enter.
    await tester.enterText(find.byType(TextField), '');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(RenameRemoteDialog), findsOneWidget);
    expect(find.text('Please enter a name'), findsOneWidget);
    expect(closed, isFalse);

    // A name with a space is invalid in git, and the button refuses too.
    await tester.enterText(find.byType(TextField), 'up stream');
    await tester.tap(find.widgetWithText(BaseButton, 'Rename'));
    await tester.pumpAndSettle();
    expect(find.byType(RenameRemoteDialog), findsOneWidget);
    expect(find.text('Name cannot contain spaces'), findsOneWidget);
    expect(closed, isFalse);
  });

  testWidgets('a valid name submits through Enter', (tester) async {
    String? result;
    await _openDialog(tester, (value) => result = value);

    await tester.enterText(find.byType(TextField), 'upstream');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(RenameRemoteDialog), findsNothing);
    expect(result, 'upstream');
  });
}
