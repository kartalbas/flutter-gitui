// The "clear the text" rung of the Escape ladder: Escape in a non-empty field
// clears it and keeps the keyboard right there; an empty field lets the key
// bubble on to the innermost dismiss scope; and a field that opted out
// (escapeClears: false) never spends the press on clearing.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/components/base_text_field.dart';
import 'package:flutter_gitui/shared/widgets/base_dismiss_scope.dart';

void main() {
  testWidgets(
    'Escape clears a non-empty field, keeps focus there, and only the '
    'second Escape reaches the dismiss scope',
    (tester) async {
      var dismissed = 0;
      final changes = <String>[];
      final fieldFocus = FocusNode(debugLabel: 'field');

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BaseDismissScope(
              enabled: true,
              onDismiss: () => dismissed++,
              child: BaseTextField(
                focusNode: fieldFocus,
                autofocus: true,
                onChanged: changes.add,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'abc');
      await tester.pump();
      expect(changes.last, 'abc');

      // First Escape: the text goes, the keyboard stays, the scope is not
      // reached.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('abc'), findsNothing);
      expect(changes.last, '');
      expect(fieldFocus.hasFocus, isTrue);
      expect(dismissed, 0);

      // Second Escape: the field is empty, so it falls through to the scope.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(dismissed, 1);
    },
  );

  testWidgets('a field with escapeClears: false never spends the press', (
    tester,
  ) async {
    var dismissed = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BaseDismissScope(
            enabled: true,
            onDismiss: () => dismissed++,
            child: const BaseTextField(autofocus: true, escapeClears: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'v1.');
    await tester.pump();

    // Even with text present, Escape goes straight to the dismiss scope and
    // the text survives.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(dismissed, 1);
    expect(find.text('v1.'), findsOneWidget);
  });
}
