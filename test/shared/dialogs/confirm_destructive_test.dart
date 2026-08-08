// The type-to-confirm gate for remote-permanent destructive actions (#308):
// the confirm button stays disabled and Enter stays inert until the user has
// retyped the target's name exactly (case-sensitively), Esc always cancels,
// the remote tier can never be silenced, and a caller cannot even open the
// gate without supplying the token.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/config/config_providers.dart';
import 'package:flutter_gitui/core/git/destructive_action.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/components/base_button.dart';
import 'package:flutter_gitui/shared/dialogs/confirm_destructive.dart';
import '../../skin/pump_under_skin.dart';

const _token = 'origin/main';

Future<void> _pumpGate(
  WidgetTester tester,
  void Function(BuildContext context, WidgetRef ref) onOpen, {
  // Riverpod 3 does not export the Override type, so the helper takes the
  // one setting the gate consults instead of a raw override list. False
  // means the user turned "confirm destructive actions" off — the state the
  // silenceable tiers may skip the dialog in and tier 3 must ignore.
  bool confirmDestructiveActions = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        confirmDestructiveActionsProvider.overrideWith(
          (ref) => confirmDestructiveActions,
        ),
      ],
      child: MaterialApp(
        builder: (BuildContext context, Widget? child) =>
            installSkinUnderTest(child ?? const SizedBox.shrink()),

        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => BaseButton(
              label: 'open',
              onPressed: () => onOpen(context, ref),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a remote-permanent action without a token is an ArgumentError', (
    tester,
  ) async {
    Object? error;
    await _pumpGate(tester, (context, ref) {
      // The error handler must not return a value (then<void> forwards its
      // result), so it is a block, not an expression: an expression-bodied
      // handler would return the error object and trip Future.then's own
      // ArgumentError instead of capturing ours.
      confirmDestructive(
        context: context,
        ref: ref,
        action: DestructiveAction.forcePush,
        title: 'Force push',
        message: 'msg',
      ).then(
        (_) {},
        onError: (Object e) {
          error = e;
        },
      );
    });

    await tester.tap(find.text('open'));
    await tester.pump();

    expect(error, isA<ArgumentError>());
  });

  testWidgets('confirm stays disabled until the token matches exactly', (
    tester,
  ) async {
    bool? result;
    await _pumpGate(tester, (context, ref) {
      confirmDestructive(
        context: context,
        ref: ref,
        action: DestructiveAction.deleteRemoteBranch,
        title: 'Delete remote branch',
        message: 'msg',
        confirmLabel: 'Delete',
        confirmationToken: _token,
      ).then((value) => result = value);
    });

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Delete remote branch'), findsOneWidget);

    // Untyped: the confirm button is disabled, a tap does nothing.
    await tester.tap(find.widgetWithText(BaseButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete remote branch'), findsOneWidget);
    expect(result, isNull);

    // Wrong case keeps it disabled: git ref names are case-sensitive, so the
    // match is too.
    await tester.enterText(find.byType(TextField), 'Origin/main');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(BaseButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete remote branch'), findsOneWidget);
    expect(result, isNull);

    // The exact token enables the button and the tap confirms.
    await tester.enterText(find.byType(TextField), _token);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(BaseButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete remote branch'), findsNothing);
    expect(result, isTrue);
  });

  testWidgets('Enter is inert until the token matches, then confirms', (
    tester,
  ) async {
    bool? result;
    await _pumpGate(tester, (context, ref) {
      confirmDestructive(
        context: context,
        ref: ref,
        action: DestructiveAction.deleteRemoteBranch,
        title: 'Delete remote branch',
        message: 'msg',
        confirmLabel: 'Delete',
        confirmationToken: _token,
      ).then((value) => result = value);
    });

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The token field autofocused, so the user can start typing immediately.
    final fieldNode = tester
        .state<EditableTextState>(find.byType(EditableText))
        .widget
        .focusNode;
    expect(fieldNode.hasPrimaryFocus, isTrue);

    // Enter with nothing typed: dead.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Delete remote branch'), findsOneWidget);
    expect(result, isNull);

    // Enter with a wrong token: still dead.
    await tester.enterText(find.byType(TextField), 'origin/mai');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Delete remote branch'), findsOneWidget);
    expect(result, isNull);

    // Enter once the token matches: confirms from inside the field.
    await tester.enterText(find.byType(TextField), _token);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Delete remote branch'), findsNothing);
    expect(result, isTrue);
  });

  testWidgets('Escape cancels even while the token field has focus', (
    tester,
  ) async {
    bool? result;
    await _pumpGate(tester, (context, ref) {
      confirmDestructive(
        context: context,
        ref: ref,
        action: DestructiveAction.deleteRemoteTag,
        title: 'Delete remote tag',
        message: 'msg',
        confirmationToken: 'v1.0.0',
      ).then((value) => result = value);
    });

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'v1.');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Delete remote tag'), findsNothing);
    expect(result, isFalse);
  });

  testWidgets('the remote tier always asks, even with confirmations silenced', (
    tester,
  ) async {
    await _pumpGate(tester, (context, ref) {
      confirmDestructive(
        context: context,
        ref: ref,
        action: DestructiveAction.forcePush,
        title: 'Force push',
        message: 'msg',
        confirmationToken: _token,
      );
    }, confirmDestructiveActions: false);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Force push'), findsOneWidget);
  });

  testWidgets('a recoverable tier ignores the token and still silences', (
    tester,
  ) async {
    bool? result;
    await _pumpGate(tester, (context, ref) {
      confirmDestructive(
        context: context,
        ref: ref,
        action: DestructiveAction.deleteLocalTag,
        title: 'Delete tag',
        message: 'msg',
        confirmationToken: 'v1.0.0',
      ).then((value) => result = value);
    }, confirmDestructiveActions: false);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // No dialog at all: the token must not change a tier's behaviour — the
    // tier alone decides.
    expect(find.text('Delete tag'), findsNothing);
    expect(result, isTrue);
  });
}
