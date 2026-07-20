import '../workspace/models/workspace_repository.dart';
import 'app_config.dart';

/// The text an older serialiser produced where an absent value belonged.
const String _stringifiedNull = 'null';

/// Clears optional fields that hold the literal text "null" instead of nothing.
///
/// Only the fields the broken serialiser could reach are swept. It stringified
/// an absent value exclusively inside the maps of a YAML sequence — the entries
/// under `repositories:` and `workspaces:` — while every other nullable value
/// took a branch that already wrote a bare `null`. Confining the sweep to those
/// fields leaves a deliberate "null" elsewhere intact, for instance a
/// repository path, a repository name or the selected workspace id.
///
/// The caller gates this on the stored schema version, so it inspects a given
/// installation once. From then on the fixed serialiser writes a bare `null`
/// for an absent value and a quoted `"null"` for that text, which makes the two
/// distinguishable again and keeps anything the user enters after the upgrade
/// out of reach of this rule.
AppConfig repairStringifiedNulls(AppConfig config) {
  final repositories = config.workspace.repositories
      .map(
        (repository) => WorkspaceRepository(
          path: repository.path,
          name: repository.name,
          customAlias: _clear(repository.customAlias),
          lastAccessed: repository.lastAccessed,
          isFavorite: repository.isFavorite,
          description: _clear(repository.description),
        ),
      )
      .toList();

  final workspaces = config.workspace.workspaces
      .map(
        (workspace) => WorkspaceConfigEntry(
          id: workspace.id,
          name: workspace.name,
          description: _clear(workspace.description),
          color: workspace.color,
          icon: _clear(workspace.icon),
          repositoryPaths: workspace.repositoryPaths,
          lastSelectedRepository: _clear(workspace.lastSelectedRepository),
          createdAt: workspace.createdAt,
          updatedAt: _clear(workspace.updatedAt),
        ),
      )
      .toList();

  return config.copyWith(
    workspace: config.workspace.copyWith(
      repositories: repositories,
      workspaces: workspaces,
    ),
  );
}

String? _clear(String? value) => value == _stringifiedNull ? null : value;
