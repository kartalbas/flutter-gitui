// The repositories screen as the keyboard drives it (#290): the collection
// is one focus stop whose highlight starts on the first repository, and three
// ArrowDowns then Enter open the fourth repository.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/config/app_config.dart';
import 'package:flutter_gitui/core/config/config_providers.dart';
import 'package:flutter_gitui/core/git/git_providers.dart';
import 'package:flutter_gitui/core/workspace/models/repository_status.dart';
import 'package:flutter_gitui/core/workspace/models/workspace_repository.dart';
import 'package:flutter_gitui/core/workspace/repository_status_provider.dart';
import 'package:flutter_gitui/core/workspace/workspace_list_provider.dart';
import 'package:flutter_gitui/core/workspace/workspace_provider.dart';
import 'package:flutter_gitui/features/repositories/repositories_screen.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';
import '../../skin/pump_under_skin.dart';

/// Serves the scripted repositories and swallows the last-accessed write,
/// which would otherwise reach the on-disk config from a test.
class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  _FakeWorkspaceNotifier(this._repositories);

  final List<WorkspaceRepository> _repositories;

  @override
  List<WorkspaceRepository> build() => _repositories;

  @override
  Future<void> markAccessed(String path) async {}
}

/// Keeps the startup auto-assignment away from the on-disk config.
class _FakeProjectNotifier extends ProjectNotifier {
  _FakeProjectNotifier(super.ref);

  @override
  Future<void> assignUnassignedRepositories(
    List<String> allRepoPaths,
    String projectId,
  ) async {}
}

/// Serves settled, healthy statuses so no row shows the indeterminate
/// loading spinner (whose endless animation would defeat pumpAndSettle).
class _FakeStatusNotifier extends RepositoryStatusNotifier {
  _FakeStatusNotifier(super.ref, Map<String, RepositoryStatus> statuses) {
    state = statuses;
  }
}

/// Records opened repositories instead of running git, so an assertion reads
/// exactly which repository the keyboard opened.
class _RecordingGitActions extends GitActions {
  _RecordingGitActions(super.ref, this.opened);

  final List<String> opened;

  @override
  Future<bool> openRepository(String path) async {
    opened.add(path);
    return true;
  }
}

void main() {
  late Directory root;
  late List<WorkspaceRepository> repositories;

  setUp(() {
    // Real directories with a .git folder: the screen checks the filesystem
    // before it lets a repository be opened.
    root = Directory.systemTemp.createTempSync('repositories_keyboard_test');
    repositories = [
      for (var i = 1; i <= 4; i++)
        () {
          final dir = Directory('${root.path}/repo$i/.git')
            ..createSync(recursive: true);
          return WorkspaceRepository(
            path: dir.parent.path,
            name: 'repo$i',
            lastAccessed: DateTime(2026),
          );
        }(),
    ];
  });

  tearDown(() {
    root.deleteSync(recursive: true);
  });

  Future<List<String>> pumpScreen(WidgetTester tester) async {
    // The desktop-drop plugin has no host in a widget test; answer its
    // channel so DropTarget's init cannot fail asynchronously.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('desktop_drop'),
      (call) async => null,
    );

    final opened = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          configProvider.overrideWith(
            (ref) => ConfigNotifier.withConfig(ref, AppConfig.defaults),
          ),
          projectProvider.overrideWith((ref) => _FakeProjectNotifier(ref)),
          workspaceProvider.overrideWith(
            () => _FakeWorkspaceNotifier(repositories),
          ),
          workspaceRepositoryStatusProvider.overrideWith(
            (ref) => _FakeStatusNotifier(ref, {
              for (final repo in repositories)
                repo.path: const RepositoryStatus(
                  exists: true,
                  isValidGit: true,
                ),
            }),
          ),
          gitActionsProvider.overrideWith(
            (ref) => _RecordingGitActions(ref, opened),
          ),
          currentRepositoryPathProvider.overrideWith((ref) => null),
          repositoriesViewModeProvider.overrideWith(
            (ref) => RepositoriesViewMode.list,
          ),
        ],
        child: MaterialApp(
          builder: (BuildContext context, Widget? child) =>
              installSkinUnderTest(child ?? const SizedBox.shrink()),

          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const RepositoriesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return opened;
  }

  testWidgets('three ArrowDowns then Enter open the fourth repository', (
    tester,
  ) async {
    final opened = await pumpScreen(tester);
    expect(find.text('repo4'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(opened, [repositories[3].path]);
  });

  testWidgets('Home returns the highlight to the first repository', (
    tester,
  ) async {
    final opened = await pumpScreen(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(opened, [repositories[0].path]);
  });
}
