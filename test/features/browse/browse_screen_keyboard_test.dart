// The browse screen's Escape ladder (#290): with focus in the tree, Escape
// clears a filled search filter — restoring the unfiltered tree — and a
// second Escape, with nothing left to dismiss, does nothing at all.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// flutter_riverpod does not re-export the Override type the shared override
// list is typed with.
import 'package:riverpod/misc.dart' show Override;

import 'package:flutter_gitui/core/config/config_providers.dart';
import 'package:flutter_gitui/core/git/git_providers.dart';
import 'package:flutter_gitui/core/git/git_service.dart';
import 'package:flutter_gitui/core/git/models/commit.dart';
import 'package:flutter_gitui/core/utils/result.dart';
import 'package:flutter_gitui/features/browse/browse_screen.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/widgets/base_tree_item.dart';

/// Git without git: the tree asks for ignored paths and the viewer pane for
/// a selected file's history — both answered without a process.
class _FakeGitService extends GitService {
  _FakeGitService(super.repoPath);

  @override
  Future<Result<List<String>>> getIgnoredPaths() async =>
      const Success(<String>[]);

  @override
  Future<Result<List<GitCommit>>> getFileHistory(String filePath) async =>
      const Success(<GitCommit>[]);
}

/// A row of the file tree showing [name] — scoped so the viewer pane naming
/// the selected file can never satisfy a tree assertion.
Finder _treeRow(String name) =>
    find.descendant(of: find.byType(BaseTreeItem), matching: find.text(name));

void main() {
  late Directory repoDir;

  setUp(() {
    repoDir = Directory.systemTemp.createTempSync('browse_screen_test');
    File(p.join(repoDir.path, 'alpha.txt')).writeAsStringSync('alpha');
    File(p.join(repoDir.path, 'beta.txt')).writeAsStringSync('beta');
  });

  tearDown(() {
    if (repoDir.existsSync()) {
      repoDir.deleteSync(recursive: true);
    }
  });

  List<Override> overrides() => [
    currentRepositoryPathProvider.overrideWith((ref) => repoDir.path),
    gitServiceProvider.overrideWith((ref) => _FakeGitService(repoDir.path)),
    currentBranchProvider.overrideWith((ref) async => 'main'),
    repositoryStatusProvider.overrideWith((ref) async => const []),
  ];

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const BrowseScreen(),
        ),
      ),
    );

    // The tree scans the real file system; drive the event loop until its
    // rows appear.
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (find.byType(BaseTreeItem).evaluate().isNotEmpty) {
        await tester.pumpAndSettle();
        return;
      }
    }
    fail('The file tree never finished loading');
  }

  /// Replaces the screen inside the same ProviderScope (same override set —
  /// riverpod forbids changing the count), so the tree's dispose-time state
  /// saving runs against a live container.
  Future<void> unmountScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Escape from the tree clears the search filter, then is dead', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(_treeRow('alpha.txt'), findsOneWidget);
    expect(_treeRow('beta.txt'), findsOneWidget);

    // Filter down to one file (the search debounce is 300ms, scheduled in
    // the rebuild the first pump runs).
    await tester.enterText(find.byType(TextField), 'beta');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(_treeRow('alpha.txt'), findsNothing);
    expect(_treeRow('beta.txt'), findsOneWidget);

    // Move focus into the tree: Escape must clear the filter from there,
    // not only from inside the field.
    await tester.tap(_treeRow('beta.txt'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(_treeRow('alpha.txt'), findsOneWidget);
    expect(_treeRow('beta.txt'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'beta'), findsNothing);

    // Nothing left to dismiss: Escape is dead and changes nothing.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_treeRow('alpha.txt'), findsOneWidget);
    expect(_treeRow('beta.txt'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await unmountScreen(tester);
  });

  testWidgets('ArrowDown typed in the search field moves the tree highlight', (
    tester,
  ) async {
    await pumpScreen(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BrowseScreen)),
      listen: false,
    );

    // Focus the field, then drive the tree without leaving it: the first
    // ArrowDown highlights the first file, the second moves on, and the
    // viewer pane's selected file follows.
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(
      container.read(selectedFileProvider),
      p.join(repoDir.path, 'beta.txt'),
    );
    // The caret stayed in the field: typing continues there.
    await tester.enterText(find.byType(TextField), 'x');
    expect(find.widgetWithText(TextField, 'x'), findsOneWidget);

    await unmountScreen(tester);
  });
}
