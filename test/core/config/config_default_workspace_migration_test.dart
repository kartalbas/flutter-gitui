// The one-time sweep that takes the application's own English words back out
// of an existing config file (schema version 2), and the rule that decides
// which sweeps a given file needs at all.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/config/app_config.dart';
import 'package:flutter_gitui/core/config/config_migration.dart';
import 'package:flutter_gitui/core/workspace/models/workspace.dart';
import 'package:flutter_gitui/core/workspace/models/workspace_repository.dart';

/// The pair an older build wrote for the workspace it created by itself.
const String _appAuthoredName = 'Default';
const String _appAuthoredDescription = 'Default workspace for all repositories';

WorkspaceConfigEntry entry({
  String id = Workspace.defaultId,
  String name = _appAuthoredName,
  String? description = _appAuthoredDescription,
}) => WorkspaceConfigEntry(
  id: id,
  name: name,
  description: description,
  color: 0xFF2196F3,
  repositoryPaths: const ['p'],
  createdAt: '2026-01-01T00:00:00.000Z',
);

AppConfig configWith(List<WorkspaceConfigEntry> workspaces) => AppConfig
    .defaults
    .copyWith(workspace: WorkspaceConfig(workspaces: workspaces));

WorkspaceConfigEntry sweep(WorkspaceConfigEntry input) =>
    clearAppAuthoredDefaultWorkspaceText(
      configWith([input]),
    ).workspace.workspaces.single;

void main() {
  group('clearAppAuthoredDefaultWorkspaceText', () {
    test('takes the English pair back out of the default workspace', () {
      final swept = sweep(entry());

      expect(
        swept.name,
        isEmpty,
        reason:
            'Left in the file, this English word is what every locale renders.',
      );
      expect(swept.description, isNull);
      // Nothing else about the entry is the migration's business.
      expect(swept.repositoryPaths, ['p']);
      expect(swept.color, 0xFF2196F3);
      expect(swept.createdAt, '2026-01-01T00:00:00.000Z');
    });

    test('keeps a name the user chose, and clears the description alone', () {
      final swept = sweep(entry(name: 'Arbeit'));

      expect(swept.name, 'Arbeit');
      expect(swept.description, isNull);
    });

    test('keeps a description the user wrote, and clears the name alone', () {
      final swept = sweep(entry(description: 'Meine Repositories'));

      expect(swept.name, isEmpty);
      expect(swept.description, 'Meine Repositories');
    });

    test('leaves a workspace the user created entirely alone', () {
      // Same two sentences, but on a workspace the application never wrote:
      // there they are the user's own text.
      final swept = sweep(entry(id: 'w1'));

      expect(swept.name, _appAuthoredName);
      expect(swept.description, _appAuthoredDescription);
    });

    test('leaves text that merely resembles the wording alone', () {
      final swept = sweep(
        entry(name: 'Defaults', description: 'default workspace'),
      );

      expect(swept.name, 'Defaults');
      expect(swept.description, 'default workspace');
    });
  });

  group('migrateConfig runs each step only for a file that predates it', () {
    /// A file that carries both defects: the stringified null of version 0 and
    /// the English workspace wording of version 1.
    AppConfig damaged() => AppConfig.defaults.copyWith(
      workspace: WorkspaceConfig(
        repositories: [
          WorkspaceRepository(
            path: 'p',
            name: 'repo',
            customAlias: 'null',
            lastAccessed: DateTime.utc(2026),
          ),
        ],
        workspaces: [entry()],
      ),
    );

    test('an unstamped file gets both sweeps', () {
      final migrated = migrateConfig(damaged(), null);

      expect(migrated.workspace.repositories.single.customAlias, isNull);
      expect(migrated.workspace.workspaces.single.name, isEmpty);
      expect(migrated.workspace.workspaces.single.description, isNull);
    });

    test('a version 1 file gets the new sweep and not the old repair', () {
      final migrated = migrateConfig(damaged(), 1);

      expect(
        migrated.workspace.repositories.single.customAlias,
        'null',
        reason:
            'Version 1 was written by the fixed serialiser, so this is an '
            'alias the user typed and not an absent value.',
      );
      expect(migrated.workspace.workspaces.single.name, isEmpty);
      expect(migrated.workspace.workspaces.single.description, isNull);
    });

    test('a current file is left exactly as it is', () {
      final migrated = migrateConfig(damaged(), AppConfig.currentConfigVersion);

      expect(migrated.workspace.repositories.single.customAlias, 'null');
      expect(migrated.workspace.workspaces.single.name, _appAuthoredName);
      expect(
        migrated.workspace.workspaces.single.description,
        _appAuthoredDescription,
      );
    });

    test('the version stamp is the one the new sweep closes', () {
      expect(AppConfig.currentConfigVersion, 2);
    });
  });
}
