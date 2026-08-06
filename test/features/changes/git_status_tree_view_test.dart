// The changes tree after the #290 restructure: key handling lives on the
// tree's own focus node instead of a shortcut wrapper around the whole split
// view. Arrows rove the highlight and the diff panel follows; Space and Enter
// toggle staging of the highlighted file through the git action layer; and a
// focused control in the diff panel keeps its arrow keys, which the previous
// Row-wide wrapper used to swallow.

import 'dart:io' show Directory;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/git/git_providers.dart';
import 'package:flutter_gitui/core/git/git_service.dart';
import 'package:flutter_gitui/core/git/models/file_status.dart';
import 'package:flutter_gitui/core/utils/result.dart';
import 'package:flutter_gitui/features/changes/widgets/git_status_tree_view.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';

/// Serves canned diffs without launching git, so the diff panel can load.
class _FakeGitService extends GitService {
  _FakeGitService() : super(Directory.systemTemp.path);

  @override
  Future<Result<String>> getDiff(String filePath, {bool staged = false}) async {
    return Success('diff --git a/$filePath b/$filePath\n@@ -0,0 +1,1 @@\n+x\n');
  }

  @override
  Future<String?> getFileContent(String filePath) async => 'x\n';
}

/// Records staging calls instead of touching git, so the tests can assert
/// which file an activation key reached the service with.
class _RecordingGitActions extends GitActions {
  _RecordingGitActions(super.ref, this.log);

  final List<String> log;

  @override
  Future<void> stageFile(String path, {bool skipRefresh = false}) async {
    log.add('stage:$path');
  }

  @override
  Future<void> unstageFile(String path, {bool skipRefresh = false}) async {
    log.add('unstage:$path');
  }
}

FileStatus _modified(String path) => FileStatus(
  path: path,
  indexStatus: FileStatusType.unchanged,
  workTreeStatus: FileStatusType.modified,
);

Future<void> _pumpChangesTree(WidgetTester tester, List<String> log) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gitServiceProvider.overrideWithValue(_FakeGitService()),
        gitActionsProvider.overrideWith(
          (ref) => _RecordingGitActions(ref, log),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => GitStatusTreeView(
              stagedFiles: const [],
              unstagedFiles: [
                _modified('docs/alpha.md'),
                _modified('docs/beta.md'),
              ],
              // The same wiring the changes screen uses, so an activation in
              // the tree lands in the recorded git action layer.
              onToggleStage: (file, currentlyStaged) async {
                if (currentlyStaged) {
                  await ref.read(gitActionsProvider).unstageFile(file.path);
                } else {
                  await ref.read(gitActionsProvider).stageFile(file.path);
                }
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ArrowDown moves the highlight and the diff panel follows', (
    tester,
  ) async {
    await _pumpChangesTree(tester, <String>[]);

    // The first file is highlighted and the diff panel names it.
    expect(find.text('docs/alpha.md'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(find.text('docs/beta.md'), findsOneWidget);
    expect(find.text('docs/alpha.md'), findsNothing);
  });

  testWidgets('Space and Enter stage the highlighted file', (tester) async {
    final log = <String>[];
    await _pumpChangesTree(tester, log);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(log, ['stage:docs/alpha.md']);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(log, ['stage:docs/alpha.md', 'stage:docs/beta.md']);
  });

  testWidgets('a focused control in the diff panel keeps its arrow keys', (
    tester,
  ) async {
    await _pumpChangesTree(tester, <String>[]);
    expect(find.text('docs/alpha.md'), findsOneWidget);

    // The tree is one Tab stop; Tab leaves it for the diff panel's controls.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    // ArrowDown now belongs to the focused control. The tree highlight must
    // not move, so the diff panel still names the first file — before the
    // restructure the tree's shortcut wrapper spanned the whole split view
    // and would have moved the highlight from here.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.text('docs/alpha.md'), findsOneWidget);
    expect(find.text('docs/beta.md'), findsNothing);
  });
}
