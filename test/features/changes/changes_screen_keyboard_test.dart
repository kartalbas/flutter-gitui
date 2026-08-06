// The changes screen through the keyboard (#290): the tree holds initial
// focus, and Enter on the highlighted file reaches the git action layer as a
// stage call — the whole path from key press to service, through the real
// screen.

import 'dart:io' show Directory;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/config/config_providers.dart';
import 'package:flutter_gitui/core/git/git_providers.dart';
import 'package:flutter_gitui/core/git/git_service.dart';
import 'package:flutter_gitui/core/git/models/file_status.dart';
import 'package:flutter_gitui/core/utils/result.dart';
import 'package:flutter_gitui/features/changes/changes_screen.dart';
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

/// Records staging calls instead of touching git, so the test can assert
/// which file the activation key reached the service with.
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

Future<void> _pumpChangesScreen(WidgetTester tester, List<String> log) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentRepositoryPathProvider.overrideWith((ref) => '/repo'),
        gitServiceProvider.overrideWith((ref) => _FakeGitService()),
        repositoryStatusProvider.overrideWith(
          (ref) async => [
            _modified('docs/alpha.md'),
            _modified('docs/beta.md'),
          ],
        ),
        gitActionsProvider.overrideWith(
          (ref) => _RecordingGitActions(ref, log),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ChangesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Enter on the highlighted file stages it through the service', (
    tester,
  ) async {
    final log = <String>[];
    await _pumpChangesScreen(tester, log);

    // The tree holds initial focus with the first file highlighted; Enter
    // stages exactly that file.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(log, ['stage:docs/alpha.md']);

    // The highlight roves; Enter follows it.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(log, ['stage:docs/alpha.md', 'stage:docs/beta.md']);
  });

  testWidgets('Escape has nothing to dismiss on the changes screen', (
    tester,
  ) async {
    final log = <String>[];
    await _pumpChangesScreen(tester, log);

    // No dial, no search, no mode: Escape is dead, stages nothing and
    // breaks nothing.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(log, isEmpty);
    expect(find.text('docs'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
