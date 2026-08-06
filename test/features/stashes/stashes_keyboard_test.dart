// The stashes screen as the keyboard drives it (#290): the list is one focus
// stop whose highlight starts on the first stash, and Enter opens and closes
// the highlighted stash's details.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/config/config_providers.dart';
import 'package:flutter_gitui/core/git/git_providers.dart';
import 'package:flutter_gitui/core/git/models/stash.dart';
import 'package:flutter_gitui/features/stashes/stashes_screen.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';

GitStash _stash(int index, String message) => GitStash(
  ref: 'stash@{$index}',
  index: index,
  hash: 'abcdef$index',
  branch: 'main',
  message: message,
);

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentRepositoryPathProvider.overrideWith((ref) => '/repo'),
          stashesProvider.overrideWith(
            (ref) async => [
              _stash(0, 'first stash'),
              _stash(1, 'second stash'),
            ],
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StashesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Enter opens and closes the highlighted stash details', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.text('first stash'), findsOneWidget);

    // Details are closed: the stash ref only appears in the detail rows.
    expect(find.text('stash@{0}'), findsNothing);

    // Enter on the initial highlight opens the first stash's details.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('stash@{0}'), findsOneWidget);

    // Enter again closes them.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('stash@{0}'), findsNothing);

    // ArrowDown then Enter opens the second stash, not the first.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('stash@{1}'), findsOneWidget);
    expect(find.text('stash@{0}'), findsNothing);
  });
}
