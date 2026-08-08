// The contract of BaseDialog.actions after it stopped being a list of
// widgets (#395 R1).
//
// Two things are pinned here, and they are the two a design-language skin
// will rely on:
//
// 1. A role really does decide the emphasis. Every call site used to name a
//    ButtonVariant, which is Material's answer to "how emphatic is this",
//    and three design languages disagree about that answer. If a role stopped
//    resolving to an emphasis here, callers would have to start naming one
//    again and the parameter would be back where it started.
// 2. A dialog declares at most one affirmative action. Cupertino singles the
//    affirmative action out as its default action and Fluent moves it to the
//    head of the row; neither can do that with a set of two, so a second one
//    has to fail loudly at the dialog that declares it rather than quietly in
//    a language nobody is looking at yet.
//
// The whole app's dialogs are held to point 2 for free: BaseDialog asserts it
// in build(), and every dialog in the population is built by
// base_dialog_flex_sweep_test.dart and dialog_keyboard_contract_sweep_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/components/base_dialog.dart';
import '../../skin/pump_under_skin.dart';

/// Pumps a dialog carrying [actions] and hands back the ColorScheme it was
/// rendered against, so a colour assertion compares against the theme rather
/// than against a literal.
Future<ColorScheme> _pumpActions(
  WidgetTester tester,
  List<DialogAction> actions, {
  String title = 'Title',
}) async {
  late ColorScheme colorScheme;
  await tester.pumpWidget(
    MaterialApp(
      builder: (BuildContext context, Widget? child) =>
          installSkinUnderTest(child ?? const SizedBox.shrink()),

      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          colorScheme = Theme.of(context).colorScheme;
          return BaseDialog(
            title: title,
            content: const Text('body'),
            actions: actions,
          );
        },
      ),
    ),
  );
  await tester.pump();
  return colorScheme;
}

/// The button widget rendered for the action labelled [label], whichever of
/// the three Material button families the emphasis resolved to.
ButtonStyleButton _buttonFor(WidgetTester tester, String label) {
  final finder = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
  );
  return tester.widget<ButtonStyleButton>(finder.first);
}

/// The background the button resolves in its enabled state - the only way to
/// tell the two filled emphases apart. BaseButton pins the container colour on
/// the widget for every filled variant, so this never falls back to a theme
/// default.
Color? _enabledBackground(ButtonStyleButton button) =>
    button.style?.backgroundColor?.resolve(<WidgetState>{});

DialogAction _action(String label, DialogActionRole role) =>
    DialogAction(label: label, role: role, onPressed: () {});

void main() {
  group('a role decides the emphasis', () {
    testWidgets('the affirmative action is the filled, accented one', (
      tester,
    ) async {
      final colorScheme = await _pumpActions(tester, [
        _action('Save', DialogActionRole.affirmative),
      ]);
      final button = _buttonFor(tester, 'Save');
      expect(button, isA<FilledButton>());
      expect(_enabledBackground(button), colorScheme.primary);
    });

    testWidgets('a destructive action is filled with the error colour', (
      tester,
    ) async {
      final colorScheme = await _pumpActions(tester, [
        _action('Delete', DialogActionRole.destructive),
      ]);
      final button = _buttonFor(tester, 'Delete');
      expect(button, isA<FilledButton>());
      expect(
        _enabledBackground(button),
        colorScheme.error,
        reason:
            'a destructive action must not be drawn like the affirmative one: '
            'it is the only difference between confirming and losing data',
      );
    });

    testWidgets('the dismissive action carries the lowest emphasis', (
      tester,
    ) async {
      await _pumpActions(tester, [
        _action('Cancel', DialogActionRole.dismissive),
      ]);
      expect(_buttonFor(tester, 'Cancel'), isA<TextButton>());
    });

    testWidgets('a neutral peer sits between the dismissal and the confirm', (
      tester,
    ) async {
      await _pumpActions(tester, [
        _action('Cancel', DialogActionRole.dismissive),
        _action('Keep both', DialogActionRole.neutral),
        _action('Replace', DialogActionRole.affirmative),
      ]);
      // Outlined, so a second way forward reads as more than the way out and
      // less than the way the dialog is asking about.
      expect(_buttonFor(tester, 'Keep both'), isA<OutlinedButton>());
      expect(_buttonFor(tester, 'Cancel'), isA<TextButton>());
      expect(_buttonFor(tester, 'Replace'), isA<FilledButton>());
    });

    testWidgets('the actions keep the order they were declared in', (
      tester,
    ) async {
      await _pumpActions(tester, [
        _action('First', DialogActionRole.dismissive),
        _action('Second', DialogActionRole.neutral),
        _action('Third', DialogActionRole.affirmative),
      ]);
      // Reading order is what Tab walks and what the keyboard sweep holds
      // every dialog to, so this component must not reorder on its own; a
      // language that arranges them differently derives that from the roles.
      final positions = [
        'First',
        'Second',
        'Third',
      ].map((label) => tester.getTopLeft(find.text(label)).dx).toList();
      expect(positions[0], lessThan(positions[1]));
      expect(positions[1], lessThan(positions[2]));
    });
  });

  group('an action states whether it can run', () {
    testWidgets('a null callback disables it', (tester) async {
      await _pumpActions(tester, [
        const DialogAction(
          label: 'Install',
          role: DialogActionRole.affirmative,
          onPressed: null,
        ),
      ]);
      expect(_buttonFor(tester, 'Install').enabled, isFalse);
    });

    testWidgets('enabled: false disables it while the callback stays visible', (
      tester,
    ) async {
      // The shape the type-to-confirm gate uses: the confirm action keeps its
      // callback and simply may not run it until the token is retyped.
      await _pumpActions(tester, [
        DialogAction(
          label: 'Force push',
          role: DialogActionRole.destructive,
          enabled: false,
          onPressed: () {},
        ),
      ]);
      expect(_buttonFor(tester, 'Force push').enabled, isFalse);
    });

    testWidgets('a loading action cannot be invoked', (tester) async {
      var invocations = 0;
      await _pumpActions(tester, [
        DialogAction(
          label: 'Committing',
          role: DialogActionRole.affirmative,
          isLoading: true,
          onPressed: () => invocations++,
        ),
      ]);
      expect(_buttonFor(tester, 'Committing').enabled, isFalse);
      await tester.tap(find.text('Committing'), warnIfMissed: false);
      expect(invocations, 0);
    });

    test('isEnabled folds the three ways an action can be unavailable', () {
      expect(_action('a', DialogActionRole.affirmative).isEnabled, isTrue);
      expect(
        const DialogAction(
          label: 'a',
          role: DialogActionRole.affirmative,
          onPressed: null,
        ).isEnabled,
        isFalse,
      );
      expect(
        DialogAction(
          label: 'a',
          role: DialogActionRole.affirmative,
          enabled: false,
          onPressed: () {},
        ).isEnabled,
        isFalse,
      );
      expect(
        DialogAction(
          label: 'a',
          role: DialogActionRole.affirmative,
          isLoading: true,
          onPressed: () {},
        ).isEnabled,
        isFalse,
      );
    });
  });

  testWidgets('a dialog may declare only one affirmative action', (
    tester,
  ) async {
    await _pumpActions(tester, [
      _action('Save', DialogActionRole.affirmative),
      _action('Save as', DialogActionRole.affirmative),
    ]);
    final exception = tester.takeException();
    expect(
      exception,
      isFlutterError,
      reason:
          'two affirmative actions leave a language that marks its default '
          'action - Cupertino - with no way to pick one, so the dialog that '
          'declares them has to say so where it is written',
    );
    expect(
      (exception as FlutterError).message,
      contains('affirmative'),
      reason: 'the error has to name the rule it is about',
    );
  });

  testWidgets('several destructive actions are allowed', (tester) async {
    // Delete and force-delete are both destructive, so the one-affirmative
    // rule must not be a one-emphatic-action rule: two destructive actions
    // stay expressible. Whether a given dialog *should* offer both is a
    // separate question, and the bulk branch delete answered it with no (see
    // BulkDeleteBranchesDialog, where force became an opt-in beside the one
    // delete) - but a language that draws a destructive action its own way
    // still has to cope with a pair.
    await _pumpActions(tester, [
      _action('Delete', DialogActionRole.destructive),
      _action('Force delete', DialogActionRole.destructive),
    ]);
    expect(tester.takeException(), isNull);
  });
}
