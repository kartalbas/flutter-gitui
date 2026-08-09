// The edit-remote-URL dialog's validator gates submission (#360): an empty
// URL shows its message and keeps the dialog open — for the dialog-wide
// Enter path and the Save button alike — while a valid URL still submits.
// Before the fix the validator was accepted but never executed, because
// BaseTextField built a plain TextField that no Form could see.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/git/models/remote.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/components/base_button.dart';
import 'package:flutter_gitui/shared/dialogs/edit_remote_url_dialog.dart';
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
                builder: (_) => const EditRemoteUrlDialog(remote: _remote),
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
  testWidgets('an empty URL is rejected and keeps the dialog open', (
    tester,
  ) async {
    var closed = false;
    await _openDialog(tester, (_) => closed = true);

    // Clear the prefilled URL, then try to submit with Enter.
    await tester.enterText(find.byType(TextField), '');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(EditRemoteUrlDialog), findsOneWidget);
    expect(find.text('Please enter a URL'), findsOneWidget);
    expect(closed, isFalse);

    // The primary button must refuse too, not only the Enter path.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(EditRemoteUrlDialog), findsOneWidget);
    expect(closed, isFalse);
  });

  testWidgets('a valid URL submits through Enter', (tester) async {
    String? result;
    await _openDialog(tester, (value) => result = value);

    await tester.enterText(
      find.byType(TextField),
      'git@example.com:owner/repo.git',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(EditRemoteUrlDialog), findsNothing);
    expect(result, 'git@example.com:owner/repo.git');
  });
}
