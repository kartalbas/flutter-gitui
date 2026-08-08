// The keyboard contract of every dialog: Enter fires the primary action from
// anywhere inside it, Escape closes it without firing, a multiline editable
// keeps its Enter for newlines, and a destructive prompt keeps Enter dead so
// the key repeat of the keystroke that opened it can never confirm the loss.
// Also pins the autofocus fix: the dialog wrapper must not steal focus from
// an autofocus field, and must still hold focus when there is no field.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/components/base_button.dart';
import 'package:flutter_gitui/shared/components/base_dialog.dart';
import 'package:flutter_gitui/shared/components/base_text_field.dart';
import '../../skin/pump_under_skin.dart';

Future<void> _pumpOpener(
  WidgetTester tester,
  void Function(BuildContext context) onOpen,
) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (BuildContext context, Widget? child) =>
          installSkinUnderTest(child ?? const SizedBox.shrink()),

      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) =>
              BaseButton(label: 'open', onPressed: () => onOpen(context)),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Enter confirms a confirmation dialog from anywhere', (
    tester,
  ) async {
    bool? result;
    await _pumpOpener(tester, (context) async {
      result = await showConfirmationDialog(
        context: context,
        title: 'Confirm push',
        message: 'Push to remote?',
      );
    });

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm push'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('Confirm push'), findsNothing);
    expect(result, isTrue);
  });

  testWidgets('Escape closes a confirmation dialog without confirming', (
    tester,
  ) async {
    bool? result;
    await _pumpOpener(tester, (context) async {
      result = await showConfirmationDialog(
        context: context,
        title: 'Confirm push',
        message: 'Push to remote?',
      );
    });

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm push'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Confirm push'), findsNothing);
    expect(result, isFalse);
  });

  testWidgets('a destructive dialog ignores Enter and cancels on Escape', (
    tester,
  ) async {
    bool? result;
    await _pumpOpener(tester, (context) {
      showDestructiveDialog(
        context: context,
        title: 'Delete branch',
        message: 'This cannot be undone.',
      ).then((value) => result = value);
    });

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Delete branch'), findsOneWidget);

    // Enter must be dead: the dialog stays open and nothing resolves.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Delete branch'), findsOneWidget);
    expect(result, isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Delete branch'), findsNothing);
    expect(result, isFalse);
  });

  testWidgets(
    'an autofocus field wins focus and a multiline editable keeps Enter',
    (tester) async {
      var submits = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (BuildContext context, Widget? child) =>
              installSkinUnderTest(child ?? const SizedBox.shrink()),

          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BaseDialog(
            title: 'Form',
            onSubmit: () => submits++,
            content: const BaseTextField(autofocus: true, maxLines: 3),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The dialog wrapper must not have stolen the field's autofocus.
      final fieldNode = tester
          .state<EditableTextState>(find.byType(EditableText))
          .widget
          .focusNode;
      expect(fieldNode.hasPrimaryFocus, isTrue);

      // Enter inside the multiline field writes a newline, it must not submit.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(submits, 0);

      // Tab moves focus to the next control inside the dialog (the X close
      // button); from there Enter submits. (Do NOT use fieldNode.unfocus():
      // that parks focus on the enclosing scope, which sits ABOVE the
      // dialog's key handler, so the key would never reach it.)
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(fieldNode.hasPrimaryFocus, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(submits, 1);
    },
  );

  testWidgets('a dialog without fields still receives Escape', (tester) async {
    await _pumpOpener(tester, (context) {
      BaseDialog.show<void>(
        context: context,
        dialog: const BaseDialog(title: 'Info', content: Text('body')),
      );
    });

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Info'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Info'), findsNothing);
  });
}
