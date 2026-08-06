// The hosted-repository picker on the shared navigation (#290): typing
// filters, ArrowDown moves the result highlight while the caret stays in the
// field, Enter takes the highlighted repository, and Escape clears a filled
// filter before it closes the dialog — the search-field handoff contract,
// which this dialog originally proved with a raw Shortcuts/Actions pair.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/git/models/git_remote_identity.dart';
import 'package:flutter_gitui/core/hosting/hosted_repository.dart';
import 'package:flutter_gitui/core/hosting/hosting_providers.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/components/base_button.dart';
import 'package:flutter_gitui/shared/dialogs/select_hosted_repository_dialog.dart';

const _source = RepositorySource(
  host: 'github.com',
  provider: GitHostingProvider.gitHub,
);

const _repositories = [
  HostedRepository(
    fullName: 'acme/alpha-app',
    cloneUrl: 'https://github.com/acme/alpha-app.git',
  ),
  HostedRepository(
    fullName: 'acme/nu-beta',
    cloneUrl: 'https://github.com/acme/nu-beta.git',
  ),
  HostedRepository(
    fullName: 'acme/nu-gamma',
    cloneUrl: 'https://github.com/acme/nu-gamma.git',
  ),
];

Future<void> _openDialog(
  WidgetTester tester,
  void Function(HostedRepository?) onClosed,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositorySourcesProvider.overrideWith((ref) => const [_source]),
        sourceRepositoriesProvider.overrideWith(
          (ref, source) async => const SourceRepositories.loaded(_repositories),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => BaseButton(
              label: 'open',
              onPressed: () {
                showSelectHostedRepositoryDialog(context).then(onClosed);
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Enter without arrows takes the first (highlighted) match', (
    tester,
  ) async {
    HostedRepository? picked;
    await _openDialog(tester, (value) => picked = value);
    expect(find.text('acme/alpha-app'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(picked?.fullName, 'acme/alpha-app');
  });

  testWidgets(
    'typing filters, arrows move the highlight without leaving the field, '
    'Enter picks',
    (tester) async {
      HostedRepository? picked;
      await _openDialog(tester, (value) => picked = value);

      // Narrow to the two "nu-" repositories.
      await tester.enterText(find.byType(TextField), 'nu');
      await tester.pumpAndSettle();
      expect(find.text('acme/nu-beta'), findsOneWidget);
      expect(find.text('acme/nu-gamma'), findsOneWidget);
      expect(find.text('acme/alpha-app'), findsNothing);

      // ArrowDown moves the highlight to the second match while the caret
      // stays in the field — typing still lands there.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'nu-g');
      await tester.pumpAndSettle();
      expect(find.text('acme/nu-gamma'), findsOneWidget);
      expect(find.text('acme/nu-beta'), findsNothing);

      // Enter takes the highlighted (only) match.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(picked?.fullName, 'acme/nu-gamma');
    },
  );

  testWidgets('ArrowDown then Enter picks the second repository', (
    tester,
  ) async {
    HostedRepository? picked;
    await _openDialog(tester, (value) => picked = value);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(picked?.fullName, 'acme/nu-beta');
  });

  testWidgets('Escape clears a filled filter first, then closes the dialog', (
    tester,
  ) async {
    var closed = false;
    HostedRepository? picked;
    await _openDialog(tester, (value) {
      closed = true;
      picked = value;
    });

    await tester.enterText(find.byType(TextField), 'beta');
    await tester.pumpAndSettle();
    expect(find.text('acme/alpha-app'), findsNothing);

    // First Escape: the filter clears, the dialog stays.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(closed, isFalse);
    expect(find.text('acme/alpha-app'), findsOneWidget);

    // Second Escape: nothing left to clear, the dialog closes unpicked.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(picked, isNull);
  });
}
