// The workspaces screen as the keyboard drives it (#290): the collection is
// one focus stop whose highlight starts on the first workspace, and ArrowDown
// then Enter selects the second one.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/config/app_config.dart';
import 'package:flutter_gitui/core/config/config_providers.dart';
import 'package:flutter_gitui/core/workspace/models/workspace.dart';
import 'package:flutter_gitui/core/workspace/selected_workspace_provider.dart';
import 'package:flutter_gitui/core/workspace/workspace_list_provider.dart';
import 'package:flutter_gitui/features/workspaces/workspaces_screen.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';
import '../../skin/pump_under_skin.dart';

Workspace _workspace(String id, String name) => Workspace(
  id: id,
  name: name,
  description: null,
  color: const Color(0xFF2196F3),
  repositoryPaths: const [],
  createdAt: DateTime(2026),
);

/// Serves the scripted workspaces without touching the on-disk config.
class _FakeProjectNotifier extends ProjectNotifier {
  _FakeProjectNotifier(super.ref, List<Workspace> projects) {
    state = projects;
  }
}

/// Selects in memory only; the real notifier persists the selection to the
/// on-disk config, which a test must never reach.
class _StubSelectedProjectNotifier extends SelectedProjectNotifier {
  _StubSelectedProjectNotifier(super.ref);

  @override
  Future<void> selectProject(Workspace project) async {
    state = project;
  }
}

void main() {
  Future<ProviderContainer> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          configProvider.overrideWith(
            (ref) => ConfigNotifier.withConfig(ref, AppConfig.defaults),
          ),
          projectProvider.overrideWith(
            (ref) => _FakeProjectNotifier(ref, [
              _workspace('one', 'Workspace One'),
              _workspace('two', 'Workspace Two'),
              _workspace('three', 'Workspace Three'),
            ]),
          ),
          selectedProjectProvider.overrideWith(
            (ref) => _StubSelectedProjectNotifier(ref),
          ),
          currentRepositoryPathProvider.overrideWith((ref) => null),
          projectsViewModeProvider.overrideWith((ref) => ProjectsViewMode.list),
        ],
        child: MaterialApp(
          builder: (BuildContext context, Widget? child) =>
              installSkinUnderTest(child ?? const SizedBox.shrink()),

          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const WorkspacesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(WorkspacesScreen)),
    );
  }

  testWidgets('ArrowDown then Enter selects the second workspace', (
    tester,
  ) async {
    final container = await pumpScreen(tester);
    expect(find.text('Workspace Two'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(container.read(selectedProjectProvider)?.id, 'two');

    // End jumps to the last workspace; Enter selects it.
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(container.read(selectedProjectProvider)?.id, 'three');
  });
}
