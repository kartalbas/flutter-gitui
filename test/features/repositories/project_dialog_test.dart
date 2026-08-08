// The project dialog's name validator gates submission (#360): an empty or
// whitespace-only project name shows its message and keeps the dialog open —
// for the dialog-wide Enter path and the Create button alike — while a valid
// name still submits. Before the fix the validator was accepted but never
// executed, because BaseTextField built a plain TextField that no Form could
// see.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/features/repositories/dialogs/project_dialog.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/components/base_button.dart';
import 'package:flutter_gitui/shared/components/base_text_field.dart';
import '../../skin/pump_under_skin.dart';

Future<void> _openDialog(
  WidgetTester tester,
  void Function(ProjectDialogResult?) onClosed,
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
              showProjectDialog(context).then(onClosed);
            },
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// The name field is the first BaseTextField (the description follows).
Finder get _nameField => find.byType(BaseTextField).first;

void main() {
  testWidgets('an empty name is rejected and keeps the dialog open', (
    tester,
  ) async {
    var closed = false;
    await _openDialog(tester, (_) => closed = true);

    // The name field autofocused; Enter must refuse to create.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(ProjectDialog), findsOneWidget);
    expect(find.text('Please enter a project name'), findsOneWidget);
    expect(closed, isFalse);

    // A whitespace-only name is no better, and the button refuses too.
    await tester.enterText(_nameField, '   ');
    await tester.tap(find.widgetWithText(BaseButton, 'Create'));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectDialog), findsOneWidget);
    expect(find.text('Please enter a project name'), findsOneWidget);
    expect(closed, isFalse);
  });

  testWidgets('a valid name submits through Enter', (tester) async {
    ProjectDialogResult? result;
    await _openDialog(tester, (value) => result = value);

    await tester.enterText(_nameField, 'Alpha');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(ProjectDialog), findsNothing);
    expect(result, isNotNull);
    expect(result!.name, 'Alpha');
  });
}
