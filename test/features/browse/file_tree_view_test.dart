// The browse tree after the #290 restructure: navigation lives on the tree's
// own focus node, moving the highlight publishes the file the viewer pane
// follows, and the file-operation keys stay scoped to the tree — bare Delete
// asks to delete the highlighted file while the tree owns focus and never
// while a text field is being edited.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_gitui/features/browse/browse_screen.dart';
import 'package:flutter_gitui/features/browse/widgets/file_tree_view.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/components/base_text_field.dart';
import 'package:flutter_gitui/shared/widgets/base_tree_item.dart';

void main() {
  late Directory repoDir;

  setUp(() {
    repoDir = Directory.systemTemp.createTempSync('browse_tree_test');
    File(p.join(repoDir.path, 'alpha.txt')).writeAsStringSync('alpha');
    File(p.join(repoDir.path, 'beta.txt')).writeAsStringSync('beta');
  });

  tearDown(() {
    if (repoDir.existsSync()) {
      repoDir.deleteSync(recursive: true);
    }
  });

  Widget harness({Widget? aboveTree}) => ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Column(
          children: [
            ?aboveTree,
            Expanded(
              child: FileTreeView(
                repositoryPath: repoDir.path,
                searchQuery: '',
                showHidden: false,
                showIgnored: false,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  /// Pumps the harness and drives the real event loop until the tree's file
  /// system scan has produced rows.
  Future<void> pumpTree(WidgetTester tester, {Widget? aboveTree}) async {
    await tester.pumpWidget(harness(aboveTree: aboveTree));

    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (find.byType(BaseTreeItem).evaluate().isNotEmpty) {
        // Advance the fake clock once so the config provider's deferred
        // load timer fires instead of lingering as a pending timer.
        await tester.pumpAndSettle();
        return;
      }
    }
    fail('The file tree never finished loading');
  }

  /// Replaces the tree with an empty pane inside the same ProviderScope, so
  /// the tree's dispose-time state saving runs against a live container
  /// instead of leaking a post-frame callback into the next test.
  Future<void> unmountTree(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('ArrowDown moves the highlight and the selected file follows', (
    tester,
  ) async {
    await pumpTree(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FileTreeView)),
      listen: false,
    );

    // The tree loads with the first file highlighted; moving down selects
    // the second file and publishes it for the viewer pane.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(
      container.read(selectedFileProvider),
      p.join(repoDir.path, 'beta.txt'),
    );

    await unmountTree(tester);
  });

  testWidgets('Delete asks to delete the highlighted file', (tester) async {
    await pumpTree(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    // Delete checks the file on disk before asking; that check is real IO.
    await tester.runAsync(() async {
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.text('Delete File'), findsOneWidget);
    expect(find.textContaining('beta.txt'), findsWidgets);

    // Cancelling leaves the file alone.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete File'), findsNothing);
    expect(File(p.join(repoDir.path, 'beta.txt')).existsSync(), isTrue);

    await unmountTree(tester);
  });

  testWidgets(
    'Delete while a text field is being edited stays with the field',
    (tester) async {
      await pumpTree(tester, aboveTree: const BaseTextField(label: 'Notes'));

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'notes');

      await tester.runAsync(() async {
        await tester.sendKeyEvent(LogicalKeyboardKey.delete);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      // No delete confirmation: the key never reached the tree.
      expect(find.text('Delete File'), findsNothing);
      expect(File(p.join(repoDir.path, 'alpha.txt')).existsSync(), isTrue);
      expect(File(p.join(repoDir.path, 'beta.txt')).existsSync(), isTrue);

      await unmountTree(tester);
    },
  );

  testWidgets('F2 opens the rename dialog for the highlighted file', (
    tester,
  ) async {
    await pumpTree(tester);

    await tester.runAsync(() async {
      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.text('Rename File'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Rename File'), findsNothing);

    await unmountTree(tester);
  });
}
