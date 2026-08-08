// The tags selection mode on the Escape ladder (#290): Escape leaves the
// mode — the innermost dismissible surface of the screen — and a second
// Escape, with nothing left to dismiss, does nothing at all.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/config/config_providers.dart';
import 'package:flutter_gitui/core/git/git_providers.dart';
import 'package:flutter_gitui/core/git/models/tag.dart';
import 'package:flutter_gitui/features/tags/tags_screen.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';
import '../../skin/pump_under_skin.dart';

GitTag _tag(String name) => GitTag(
  name: name,
  commitHash: 'abcdef1234567890',
  type: GitTagType.lightweight,
  commitMessage: 'commit for $name',
);

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentRepositoryPathProvider.overrideWith((ref) => '/repo'),
          tagsProvider.overrideWith(
            (ref) async => [_tag('v1.0.0'), _tag('v1.1.0')],
          ),
          localOnlyTagsProvider.overrideWith((ref) async => <String>{}),
          remoteOnlyTagsProvider.overrideWith((ref) async => <String>{}),
          remoteNamesProvider.overrideWith((ref) async => const <String>[]),
        ],
        child: MaterialApp(
          builder: (BuildContext context, Widget? child) =>
              installSkinUnderTest(child ?? const SizedBox.shrink()),

          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const TagsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Escape leaves the selection mode and a second Escape is dead', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.text('v1.0.0'), findsOneWidget);

    // Enter the selection mode through the overflow menu, the way a user
    // reaches it.
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select Tags'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Exit Selection'), findsOneWidget);

    // Escape dismisses the mode: the selection app bar is gone and the
    // normal one is back.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Exit Selection'), findsNothing);
    expect(find.byTooltip('More actions'), findsOneWidget);

    // A second Escape has nothing to dismiss and changes nothing.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Exit Selection'), findsNothing);
    expect(find.byTooltip('More actions'), findsOneWidget);
    expect(find.text('v1.0.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Enter toggles the checkmark of the highlighted tag while '
      'selecting', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select Tags'));
    await tester.pumpAndSettle();

    // The roving highlight starts on the first tag; Enter checks it.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    // Enter again unchecks it.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('0 selected'), findsOneWidget);
  });
}
