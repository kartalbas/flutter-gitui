// Serialisation of absent optional values, and the one-time repair of a config
// written before that serialisation was fixed.

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'package:flutter_gitui/core/config/app_config.dart';
import 'package:flutter_gitui/core/config/config_migration.dart';
import 'package:flutter_gitui/core/config/config_service.dart';
import 'package:flutter_gitui/core/workspace/models/workspace_repository.dart';

/// Serialises [map] exactly as a save does, then reads it back.
Map<dynamic, dynamic> roundTrip(Map<String, dynamic> map) =>
    loadYaml(ConfigService.toYamlString(map)) as Map;

WorkspaceRepository repository({String? customAlias, String? description}) {
  return WorkspaceRepository(
    path: 'p',
    name: 'repo',
    customAlias: customAlias,
    lastAccessed: DateTime.utc(2026),
    description: description,
  );
}

WorkspaceConfigEntry workspaceEntry({
  String? description,
  String? icon,
  String? lastSelectedRepository,
  String? updatedAt,
}) {
  return WorkspaceConfigEntry(
    id: 'w1',
    name: 'work',
    description: description,
    color: 0xFF000000,
    icon: icon,
    repositoryPaths: const ['p'],
    lastSelectedRepository: lastSelectedRepository,
    createdAt: '2026-01-01T00:00:00.000Z',
    updatedAt: updatedAt,
  );
}

void main() {
  group('an absent value survives as null', () {
    test('at the top level', () {
      final parsed = roundTrip({'custom_diff_tool_path': null});

      expect(parsed['custom_diff_tool_path'], isNull);
    });

    test('inside the map of a list entry', () {
      final parsed = roundTrip({
        'repositories': [
          {'path': 'p', 'custom_alias': null, 'description': null},
        ],
      });
      final entry = (parsed['repositories'] as List).single as Map;

      expect(entry['custom_alias'], isNull);
      expect(entry['description'], isNull);
      // The reader casts before use, so the cast has to survive it too.
      expect(entry['custom_alias'] as String?, isNull);
    });

    test('inside a list nested in a list entry', () {
      final parsed = roundTrip({
        'repositories': [
          {
            'repository_paths': ['a', null],
          },
        ],
      });
      final entry = (parsed['repositories'] as List).single as Map;

      expect((entry['repository_paths'] as List)[1], isNull);
    });

    test('inside a top-level list', () {
      final parsed = roundTrip({
        'search_history': [null, 'b'],
      });
      final history = parsed['search_history'] as List;

      expect(history[0], isNull);
      expect(history[1], 'b');
    });

    test('while a value that really is the text "null" stays a string', () {
      final parsed = roundTrip({
        'locale': 'null',
        'search_history': ['null'],
        'repositories': [
          {'name': 'null'},
        ],
      });
      final entry = (parsed['repositories'] as List).single as Map;

      expect(parsed['locale'], isA<String>());
      expect(parsed['locale'], 'null');
      expect((parsed['search_history'] as List).single, 'null');
      expect(entry['name'], 'null');
    });
  });

  group('config round trip', () {
    test('optional fields left unset reload as null, not as "null"', () {
      final config = AppConfig.defaults.copyWith(
        workspace: WorkspaceConfig(
          repositories: [repository()],
          workspaces: [workspaceEntry()],
        ),
      );

      final reloaded = AppConfig.fromYaml(
        loadYaml(ConfigService.toYamlString(config.toYaml())) as Map,
      );

      final repo = reloaded.workspace.repositories.single;
      expect(repo.customAlias, isNull);
      expect(repo.description, isNull);
      expect(repo.displayName, 'repo');

      final entry = reloaded.workspace.workspaces.single;
      expect(entry.description, isNull);
      expect(entry.icon, isNull);
      expect(entry.lastSelectedRepository, isNull);
      expect(entry.updatedAt, isNull);

      expect(reloaded.tools.customDiffToolPath, isNull);
      expect(reloaded.ui.locale, isNull);
    });

    test('every written config carries the version that closes the repair', () {
      expect(
        AppConfig.defaults.toYaml()['config_version'],
        AppConfig.currentConfigVersion,
      );
    });
  });

  group('repairStringifiedNulls', () {
    test('drops a poisoned alias and description on a repository', () {
      final repaired = repairStringifiedNulls(
        AppConfig.defaults.copyWith(
          workspace: WorkspaceConfig(
            repositories: [
              repository(customAlias: 'null', description: 'null'),
            ],
          ),
        ),
      );

      final repo = repaired.workspace.repositories.single;
      expect(repo.customAlias, isNull);
      expect(repo.description, isNull);
      expect(repo.displayName, 'repo');
    });

    test('drops the poisoned optional fields on a workspace entry', () {
      final repaired = repairStringifiedNulls(
        AppConfig.defaults.copyWith(
          workspace: WorkspaceConfig(
            workspaces: [
              workspaceEntry(
                description: 'null',
                icon: 'null',
                lastSelectedRepository: 'null',
                updatedAt: 'null',
              ),
            ],
          ),
        ),
      );

      final entry = repaired.workspace.workspaces.single;
      expect(entry.description, isNull);
      expect(entry.icon, isNull);
      expect(entry.lastSelectedRepository, isNull);
      expect(entry.updatedAt, isNull);
      expect(entry.name, 'work');
      expect(entry.createdAt, '2026-01-01T00:00:00.000Z');
    });

    test('keeps "null" where the old serialiser could never have put it', () {
      final repaired = repairStringifiedNulls(
        AppConfig.defaults.copyWith(
          workspace: WorkspaceConfig(
            currentRepository: 'null',
            selectedWorkspaceId: 'null',
            repositories: [
              WorkspaceRepository(
                path: 'null',
                name: 'null',
                lastAccessed: DateTime.utc(2026),
              ),
            ],
          ),
        ),
      );

      expect(repaired.workspace.currentRepository, 'null');
      expect(repaired.workspace.selectedWorkspaceId, 'null');
      expect(repaired.workspace.repositories.single.path, 'null');
      expect(repaired.workspace.repositories.single.name, 'null');
    });

    test('keeps a value that merely contains the word', () {
      final repaired = repairStringifiedNulls(
        AppConfig.defaults.copyWith(
          workspace: WorkspaceConfig(
            repositories: [
              repository(customAlias: 'null pointer', description: 'Null'),
            ],
          ),
        ),
      );

      final repo = repaired.workspace.repositories.single;
      expect(repo.customAlias, 'null pointer');
      expect(repo.description, 'Null');
    });
  });
}
