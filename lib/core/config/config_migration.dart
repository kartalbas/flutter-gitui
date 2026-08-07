import '../workspace/models/workspace.dart';
import '../workspace/models/workspace_repository.dart';
import 'app_config.dart';

/// Brings a config file written by an older build up to the current schema.
///
/// [storedVersion] is the `config_version` the file carried, or null when it
/// carried none at all — the state of every file written before the stamp
/// existed.
///
/// Each step is gated on the version that introduced it, never on "anything
/// below the current one", because those are different questions. A file
/// already stamped 1 was written by the fixed serialiser, so re-running the
/// version 1 repair over it would clear a "null" the user has deliberately
/// typed since. A step therefore runs only for a file written before that step
/// existed, and everything entered afterwards is out of its reach.
AppConfig migrateConfig(AppConfig config, int? storedVersion) {
  final from = storedVersion ?? 0;
  var migrated = config;
  if (from < 1) {
    migrated = repairStringifiedNulls(migrated);
  }
  if (from < 2) {
    migrated = clearAppAuthoredDefaultWorkspaceText(migrated);
  }
  return migrated;
}

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

/// The English name an older build wrote for the default workspace.
const String _appAuthoredDefaultWorkspaceName = 'Default';

/// The English description an older build wrote for the default workspace.
const String _appAuthoredDefaultWorkspaceDescription =
    'Default workspace for all repositories';

/// Removes the application's own English words from the default workspace, so
/// the active locale supplies them again.
///
/// An older build created that workspace with an English name and description
/// and saved them into `config.yaml` the first time the user changed anything.
/// From then on every launch rendered those two sentences straight from the
/// file, in English, whichever of the six UI languages was selected. The
/// current build stores them as absent and resolves them at display time
/// (`default_workspace_text.dart`); this sweep brings an existing installation
/// to the same state.
///
/// Only text that is *exactly* what that build wrote is cleared, and only on
/// the workspace it wrote it on, so a name or description the user typed —
/// including a renamed default workspace — is left untouched. The caller gates
/// this on the stored schema version, so it judges a given installation once:
/// a user who afterwards names their workspace "Default" is never
/// second-guessed.
AppConfig clearAppAuthoredDefaultWorkspaceText(AppConfig config) {
  final workspaces = config.workspace.workspaces.map((workspace) {
    if (workspace.id != Workspace.defaultId) return workspace;
    final wroteName = workspace.name == _appAuthoredDefaultWorkspaceName;
    final wroteDescription =
        workspace.description == _appAuthoredDefaultWorkspaceDescription;
    if (!wroteName && !wroteDescription) return workspace;
    return WorkspaceConfigEntry(
      id: workspace.id,
      name: wroteName ? '' : workspace.name,
      description: wroteDescription ? null : workspace.description,
      color: workspace.color,
      icon: workspace.icon,
      repositoryPaths: workspace.repositoryPaths,
      lastSelectedRepository: workspace.lastSelectedRepository,
      createdAt: workspace.createdAt,
      updatedAt: workspace.updatedAt,
    );
  }).toList();

  return config.copyWith(
    workspace: config.workspace.copyWith(workspaces: workspaces),
  );
}
