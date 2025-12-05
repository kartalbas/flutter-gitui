import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import '../../generated/app_localizations.dart';

import 'app_config.dart';
import 'config_service.dart';
import '../diff/models/diff_tool.dart';
import '../tools/version_detector.dart';
import '../workspace/models/workspace_repository.dart';
import '../services/logger_service.dart';

/// Main config state notifier
class ConfigNotifier extends StateNotifier<AppConfig> {
  final Ref _ref;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _loadFailed = false;
  bool get loadFailed => _loadFailed;

  bool _gitPathInvalid = false;
  bool get gitPathInvalid => _gitPathInvalid;

  // Normal constructor - loads config asynchronously
  ConfigNotifier(this._ref) : super(AppConfig.defaults) {
    _loadConfig();
  }

  // Constructor with pre-loaded config - skips loading
  // Used when config is loaded before app initialization
  ConfigNotifier.withConfig(this._ref, AppConfig config) : super(config) {
    _isLoading = false;
    _loadFailed = false;
    Logger.info('[CONFIG] Using pre-loaded configuration (gitPath=${config.git.executablePath ?? "null"})');
    // Schedule loading state update after provider initialization completes
    // This avoids Riverpod's "cannot modify providers during initialization" error
    Future(() {
      _ref.read(_configLoadingStateProvider.notifier).state = false;
      Logger.info('[CONFIG] Pre-loaded config initialization completed (_configLoadingStateProvider set to false)');
    });
  }

  /// Load configuration from YAML file
  Future<void> _loadConfig() async {
    _isLoading = true;
    _ref.read(_configLoadingStateProvider.notifier).state = true;
    Logger.info('[CONFIG] Loading configuration started (_isLoading=true)');
    try {
      // Load from YAML
      final configResult = await ConfigService.load();
      var config = configResult.unwrapOr(AppConfig.defaults);
      Logger.debug('After ConfigService.load() - repositories count: ${config.workspace.repositories.length}');
      Logger.debug('After ConfigService.load() - workspaces count: ${config.workspace.workspaces.length}');
      Logger.debug('[CONFIG] Git executable path from config: ${config.git.executablePath ?? "null"}');

      // Validate and update tool versions on startup
      config = await _validateToolVersions(config);
      Logger.debug('After _validateToolVersions() - repositories count: ${config.workspace.repositories.length}');
      Logger.debug('After _validateToolVersions() - workspaces count: ${config.workspace.workspaces.length}');

      // Validate workspace: clear current_repository if it's not in the repositories list
      final workspaceValidation = _validateWorkspace(config);
      config = workspaceValidation.config;
      Logger.debug('After _validateWorkspace() - repositories count: ${config.workspace.repositories.length}');
      Logger.debug('After _validateWorkspace() - workspaces count: ${config.workspace.workspaces.length}');
      if (workspaceValidation.needsSave) {
        Logger.config('Saving workspace validation changes to config');
        final saveResult = await ConfigService.save(config);
        saveResult.unwrap(); // Throw on error
      }

      state = config;
      _loadFailed = false;
      Logger.info('[CONFIG] Configuration loaded successfully (gitPath=${config.git.executablePath ?? "null"})');
    } catch (e, stack) {
      Logger.error('Error loading config', e, stack);
      state = AppConfig.defaults;
      _loadFailed = true;
      Logger.warning('[CONFIG] Using default configuration due to error');
    } finally {
      _isLoading = false;
      _ref.read(_configLoadingStateProvider.notifier).state = false;
      Logger.info('[CONFIG] Loading configuration completed (_isLoading=false)');
    }
  }

  /// Validate workspace configuration
  /// Ensures current_repository is null or exists in repositories list
  ({AppConfig config, bool needsSave}) _validateWorkspace(AppConfig config) {
    final currentRepo = config.workspace.currentRepository;

    // If no current repository is set, nothing to validate
    if (currentRepo == null) {
      return (config: config, needsSave: false);
    }

    // Check if current repository exists in workspace repositories list
    final exists = config.workspace.repositories.any((r) => r.path == currentRepo);

    if (!exists) {
      Logger.warning('Current repository "$currentRepo" not found in workspace - clearing selection');
      // Clear the orphaned current repository
      final updatedConfig = config.copyWith(
        workspace: config.workspace.copyWith(
          currentRepository: null,
        ),
      );
      return (config: updatedConfig, needsSave: true);
    }

    return (config: config, needsSave: false);
  }

  /// Validate and update tool versions on startup
  /// This ensures version info stays current if tools are updated
  Future<AppConfig> _validateToolVersions(AppConfig config) async {
    bool needsSave = false;
    var updatedConfig = config;

    // Check git version if path exists
    if (config.git.executablePath != null && config.git.executablePath!.isNotEmpty) {
      try {
        final version = await VersionDetector.detectVersion(config.git.executablePath!);
        if (version != null && version != config.git.gitVersion) {
          Logger.config('Updated git version: ${config.git.gitVersion} → $version');
          updatedConfig = updatedConfig.copyWith(
            git: config.git.copyWith(gitVersion: version),
          );
          needsSave = true;
        }
        // Git path is valid - clear any previous error flag
        _gitPathInvalid = false;
      } catch (e) {
        Logger.warning('Failed to detect git version - git path may be invalid', e);
        // Mark git path as potentially invalid
        _gitPathInvalid = true;
      }
    }

    // Check text editor version if path exists
    if (config.tools.textEditor != null && config.tools.textEditor!.isNotEmpty) {
      try {
        final version = await VersionDetector.detectVersion(config.tools.textEditor!);
        if (version != null && version != config.tools.textEditorVersion) {
          Logger.config('Updated text editor version: ${config.tools.textEditorVersion} → $version');
          updatedConfig = updatedConfig.copyWith(
            tools: updatedConfig.tools.copyWith(textEditorVersion: version),
          );
          needsSave = true;
        }
      } catch (e) {
        Logger.warning('Failed to detect text editor version', e);
      }
    }

    // Check diff tool version if path exists
    if (config.tools.diffToolPath != null && config.tools.diffToolPath!.isNotEmpty) {
      try {
        final version = await VersionDetector.detectVersion(config.tools.diffToolPath!);
        if (version != null && version != config.tools.diffToolVersion) {
          Logger.config('Updated diff tool version: ${config.tools.diffToolVersion} → $version');
          updatedConfig = updatedConfig.copyWith(
            tools: updatedConfig.tools.copyWith(diffToolVersion: version),
          );
          needsSave = true;
        }
      } catch (e) {
        Logger.warning('Failed to detect diff tool version', e);
      }
    }

    // Check merge tool version if path exists
    if (config.tools.mergeToolPath != null && config.tools.mergeToolPath!.isNotEmpty) {
      try {
        final version = await VersionDetector.detectVersion(config.tools.mergeToolPath!);
        if (version != null && version != config.tools.mergeToolVersion) {
          Logger.config('Updated merge tool version: ${config.tools.mergeToolVersion} → $version');
          updatedConfig = updatedConfig.copyWith(
            tools: updatedConfig.tools.copyWith(mergeToolVersion: version),
          );
          needsSave = true;
        }
      } catch (e) {
        Logger.warning('Failed to detect merge tool version', e);
      }
    }

    // Check custom diff tool version if path exists
    if (config.tools.customDiffToolPath != null && config.tools.customDiffToolPath!.isNotEmpty) {
      try {
        final version = await VersionDetector.detectVersion(config.tools.customDiffToolPath!);
        if (version != null && version != config.tools.customDiffToolVersion) {
          Logger.config('Updated custom diff tool version: ${config.tools.customDiffToolVersion} → $version');
          updatedConfig = updatedConfig.copyWith(
            tools: updatedConfig.tools.copyWith(customDiffToolVersion: version),
          );
          needsSave = true;
        }
      } catch (e) {
        Logger.warning('Failed to detect custom diff tool version', e);
      }
    }

    // Check custom merge tool version if path exists
    if (config.tools.customMergeToolPath != null && config.tools.customMergeToolPath!.isNotEmpty) {
      try {
        final version = await VersionDetector.detectVersion(config.tools.customMergeToolPath!);
        if (version != null && version != config.tools.customMergeToolVersion) {
          Logger.config('Updated custom merge tool version: ${config.tools.customMergeToolVersion} → $version');
          updatedConfig = updatedConfig.copyWith(
            tools: updatedConfig.tools.copyWith(customMergeToolVersion: version),
          );
          needsSave = true;
        }
      } catch (e) {
        Logger.warning('Failed to detect custom merge tool version', e);
      }
    }

    // Save updated config if any versions changed
    if (needsSave) {
      Logger.config('Saving updated tool versions to config');
      final saveResult = await ConfigService.save(updatedConfig);
      saveResult.unwrap(); // Throw on error
    }

    return updatedConfig;
  }

  /// Save current config to YAML file with state recovery on failure
  Future<void> _saveConfig() async {
    // Capture current state before attempting save
    final previousState = state;

    try {
      Logger.debug('_saveConfig called');
      Logger.debug('Current state.git.executablePath = ${state.git.executablePath}');
      Logger.debug('Current state.tools.textEditor = ${state.tools.textEditor}');
      Logger.debug('Current state.tools.customDiffToolPath = ${state.tools.customDiffToolPath}');
      Logger.debug('Current state.tools.customMergeToolPath = ${state.tools.customMergeToolPath}');
      Logger.debug('Current state.git.defaultUserName = ${state.git.defaultUserName}');
      Logger.debug('Current state.git.defaultUserEmail = ${state.git.defaultUserEmail}');
      Logger.debug('Calling ConfigService.save...');
      final saveResult = await ConfigService.save(state);
      saveResult.unwrap(); // Throw on error
      Logger.debug('ConfigService.save completed successfully');
    } catch (e, stack) {
      Logger.error('Error saving config - reverting to previous state', e, stack);
      // Revert state to before the save attempt
      state = previousState;
      rethrow;
    }
  }

  /// Reload config from file (for external changes)
  Future<void> reload() async {
    await _loadConfig();
  }

  // Git Configuration Methods
  Future<void> setGitExecutablePath(String? path, {String? version}) async {
    Logger.debug('setGitExecutablePath called with: $path, version: $version');
    // Handle explicit null (clearing) vs just updating
    if (path == null) {
      // Clearing - explicitly set both to null
      state = state.copyWith(git: GitConfig(
        executablePath: null,
        gitVersion: null,
        defaultUserName: state.git.defaultUserName,
        defaultUserEmail: state.git.defaultUserEmail,
      ));
    } else {
      state = state.copyWith(git: state.git.copyWith(executablePath: path, gitVersion: version));
    }
    Logger.debug('After setting state, git.executablePath = ${state.git.executablePath}');
    Logger.debug('After setting state, git.gitVersion = ${state.git.gitVersion}');
    await _saveConfig();
  }

  Future<void> setDefaultUserName(String? name) async {
    Logger.debug('setDefaultUserName called with: $name');
    state = state.copyWith(git: state.git.copyWith(defaultUserName: name));
    Logger.debug('After setting state, git.defaultUserName = ${state.git.defaultUserName}');
    await _saveConfig();
  }

  Future<void> setDefaultUserEmail(String? email) async {
    Logger.debug('setDefaultUserEmail called with: $email');
    state = state.copyWith(git: state.git.copyWith(defaultUserEmail: email));
    Logger.debug('After setting state, git.defaultUserEmail = ${state.git.defaultUserEmail}');
    await _saveConfig();
  }

  // Tools Configuration Methods
  Future<void> setTextEditor(String? editor, {String? version}) async {
    Logger.debug('setTextEditor called with: $editor, version: $version');
    // Handle explicit null (clearing) vs just updating
    if (editor == null) {
      // Clearing - explicitly set both to null
      state = state.copyWith(tools: ToolsConfig(
        textEditor: null,
        textEditorVersion: null,
        diffTool: state.tools.diffTool,
        mergeTool: state.tools.mergeTool,
        customDiffToolPath: state.tools.customDiffToolPath,
        customDiffToolVersion: state.tools.customDiffToolVersion,
        customMergeToolPath: state.tools.customMergeToolPath,
        customMergeToolVersion: state.tools.customMergeToolVersion,
      ));
    } else {
      state = state.copyWith(tools: state.tools.copyWith(
        textEditor: editor,
        textEditorVersion: version,
      ));
    }
    Logger.debug('After setting state, tools.textEditor = ${state.tools.textEditor}');
    Logger.debug('After setting state, tools.textEditorVersion = ${state.tools.textEditorVersion}');
    await _saveConfig();
  }

  Future<void> setDiffTool(DiffToolType? tool, {String? path, String? version}) async {
    Logger.debug('setDiffTool called with: $tool, path: $path, version: $version');
    state = state.copyWith(tools: state.tools.copyWith(
      diffTool: tool,
      diffToolPath: path,
      diffToolVersion: version,
    ));
    Logger.debug('After setting state, tools.diffTool = ${state.tools.diffTool}');
    Logger.debug('After setting state, tools.diffToolPath = ${state.tools.diffToolPath}');
    Logger.debug('After setting state, tools.diffToolVersion = ${state.tools.diffToolVersion}');
    await _saveConfig();
  }

  Future<void> setMergeTool(DiffToolType? tool, {String? path, String? version}) async {
    Logger.debug('setMergeTool called with: $tool, path: $path, version: $version');
    state = state.copyWith(tools: state.tools.copyWith(
      mergeTool: tool,
      mergeToolPath: path,
      mergeToolVersion: version,
    ));
    Logger.debug('After setting state, tools.mergeTool = ${state.tools.mergeTool}');
    Logger.debug('After setting state, tools.mergeToolPath = ${state.tools.mergeToolPath}');
    Logger.debug('After setting state, tools.mergeToolVersion = ${state.tools.mergeToolVersion}');
    await _saveConfig();
  }

  Future<void> setCustomDiffToolPath(String? path, {String? version}) async {
    Logger.debug('setCustomDiffToolPath called with: $path, version: $version');
    // Handle explicit null (clearing) vs just updating
    if (path == null) {
      // Clearing - explicitly set both to null
      state = state.copyWith(tools: ToolsConfig(
        textEditor: state.tools.textEditor,
        textEditorVersion: state.tools.textEditorVersion,
        diffTool: state.tools.diffTool,
        mergeTool: state.tools.mergeTool,
        customDiffToolPath: null,
        customDiffToolVersion: null,
        customMergeToolPath: state.tools.customMergeToolPath,
        customMergeToolVersion: state.tools.customMergeToolVersion,
      ));
    } else {
      state = state.copyWith(tools: state.tools.copyWith(
        customDiffToolPath: path,
        customDiffToolVersion: version,
      ));
    }
    Logger.debug('After setting state, tools.customDiffToolPath = ${state.tools.customDiffToolPath}');
    Logger.debug('After setting state, tools.customDiffToolVersion = ${state.tools.customDiffToolVersion}');
    await _saveConfig();
  }

  Future<void> setCustomMergeToolPath(String? path, {String? version}) async {
    Logger.debug('setCustomMergeToolPath called with: $path, version: $version');
    // Handle explicit null (clearing) vs just updating
    if (path == null) {
      // Clearing - explicitly set both to null
      state = state.copyWith(tools: ToolsConfig(
        textEditor: state.tools.textEditor,
        textEditorVersion: state.tools.textEditorVersion,
        diffTool: state.tools.diffTool,
        mergeTool: state.tools.mergeTool,
        customDiffToolPath: state.tools.customDiffToolPath,
        customDiffToolVersion: state.tools.customDiffToolVersion,
        customMergeToolPath: null,
        customMergeToolVersion: null,
      ));
    } else {
      state = state.copyWith(tools: state.tools.copyWith(
        customMergeToolPath: path,
        customMergeToolVersion: version,
      ));
    }
    Logger.debug('After setting state, tools.customMergeToolPath = ${state.tools.customMergeToolPath}');
    Logger.debug('After setting state, tools.customMergeToolVersion = ${state.tools.customMergeToolVersion}');
    await _saveConfig();
  }

  Future<void> clearCustomDiffToolPath() async {
    await setCustomDiffToolPath(null);
  }

  Future<void> clearCustomMergeToolPath() async {
    await setCustomMergeToolPath(null);
  }

  // UI Configuration Methods
  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(ui: state.ui.copyWith(themeMode: mode));
    await _saveConfig();
  }

  Future<void> setUseSystemTheme(bool use) async {
    state = state.copyWith(ui: state.ui.copyWith(useSystemTheme: use));
    await _saveConfig();
  }

  Future<void> setRepositoriesViewMode(RepositoriesViewMode mode) async {
    state = state.copyWith(ui: state.ui.copyWith(repositoriesViewMode: mode));
    await _saveConfig();
  }

  Future<void> setProjectsViewMode(ProjectsViewMode mode) async {
    state = state.copyWith(ui: state.ui.copyWith(projectsViewMode: mode));
    await _saveConfig();
  }

  Future<void> setNavigationRailExtended(bool extended) async {
    state = state.copyWith(ui: state.ui.copyWith(navigationRailExtended: extended));
    await _saveConfig();
  }

  Future<void> setColorScheme(AppColorScheme scheme) async {
    state = state.copyWith(ui: state.ui.copyWith(colorScheme: scheme));
    await _saveConfig();
  }

  Future<void> setFontFamily(String fontFamily) async {
    state = state.copyWith(ui: state.ui.copyWith(fontFamily: fontFamily));
    await _saveConfig();
  }

  Future<void> setPreviewFontFamily(String previewFontFamily) async {
    state = state.copyWith(ui: state.ui.copyWith(previewFontFamily: previewFontFamily));
    await _saveConfig();
  }

  Future<void> setFontSize(AppFontSize size) async {
    state = state.copyWith(ui: state.ui.copyWith(fontSize: size));
    await _saveConfig();
  }

  Future<void> setPreviewFontSize(AppFontSize size) async {
    state = state.copyWith(ui: state.ui.copyWith(previewFontSize: size));
    await _saveConfig();
  }

  Future<void> setLocale(String? locale) async {
    state = state.copyWith(ui: state.ui.copyWith(locale: locale));
    await _saveConfig();
  }

  Future<void> setDiffCompactMode(bool compact) async {
    state = state.copyWith(ui: state.ui.copyWith(diffCompactMode: compact));
    await _saveConfig();
  }

  Future<void> setAnimationSpeed(AppAnimationSpeed speed) async {
    state = state.copyWith(ui: state.ui.copyWith(animationSpeed: speed));
    await _saveConfig();
  }

  // Browse Configuration Methods
  Future<void> setShowHiddenFiles(bool show) async {
    state = state.copyWith(browse: state.browse.copyWith(showHiddenFiles: show));
    await _saveConfig();
  }

  Future<void> setShowIgnoredFiles(bool show) async {
    state = state.copyWith(browse: state.browse.copyWith(showIgnoredFiles: show));
    await _saveConfig();
  }

  Future<void> setBrowseViewMode(BrowseViewMode mode) async {
    state = state.copyWith(browse: state.browse.copyWith(viewMode: mode));
    await _saveConfig();
  }

  // Command Log Configuration Methods
  Future<void> setCommandLogPanelVisible(bool visible) async {
    state = state.copyWith(commandLog: state.commandLog.copyWith(panelVisible: visible));
    await _saveConfig();
  }

  Future<void> setCommandLogPanelWidth(double width) async {
    state = state.copyWith(commandLog: state.commandLog.copyWith(panelWidth: width));
    await _saveConfig();
  }

  // Behavior Configuration Methods
  Future<void> setAutoFetch(bool enable) async {
    state = state.copyWith(behavior: state.behavior.copyWith(autoFetch: enable));
    await _saveConfig();
  }

  Future<void> setAutoFetchInterval(int minutes) async {
    state = state.copyWith(behavior: state.behavior.copyWith(autoFetchInterval: minutes));
    await _saveConfig();
  }

  Future<void> setConfirmPush(bool confirm) async {
    state = state.copyWith(behavior: state.behavior.copyWith(confirmPush: confirm));
    await _saveConfig();
  }

  Future<void> setConfirmForcePush(bool confirm) async {
    state = state.copyWith(behavior: state.behavior.copyWith(confirmForcePush: confirm));
    await _saveConfig();
  }

  Future<void> setConfirmDelete(bool confirm) async {
    state = state.copyWith(behavior: state.behavior.copyWith(confirmDelete: confirm));
    await _saveConfig();
  }

  // History Configuration Methods
  Future<void> setDefaultCommitLimit(int limit) async {
    state = state.copyWith(history: state.history.copyWith(defaultCommitLimit: limit));
    await _saveConfig();
  }

  Future<void> setShowCommitGraph(bool show) async {
    state = state.copyWith(history: state.history.copyWith(showCommitGraph: show));
    await _saveConfig();
  }

  Future<void> addSearchHistory(String query) async {
    final history = [...state.history.searchHistory];
    if (!history.contains(query)) {
      history.insert(0, query);
      // Keep only last 20 searches
      if (history.length > 20) {
        history.removeLast();
      }
      state = state.copyWith(history: state.history.copyWith(searchHistory: history));
      await _saveConfig();
    }
  }

  // Workspace Configuration Methods
  Future<void> setCurrentRepository(String? path) async {
    // Handle explicit null (clearing current repository)
    if (path == null) {
      // Create new WorkspaceConfig with null to actually clear it
      // (copyWith won't work because of the ?? operator)
      // IMPORTANT: Must preserve ALL fields when creating new object
      state = state.copyWith(workspace: WorkspaceConfig(
        currentRepository: null,
        repositories: state.workspace.repositories,
        workspaces: state.workspace.workspaces,
        selectedWorkspaceId: state.workspace.selectedWorkspaceId,
      ));
    } else {
      state = state.copyWith(workspace: state.workspace.copyWith(currentRepository: path));
    }
    await _saveConfig();
  }

  Future<void> addRepository(WorkspaceRepository repo) async {
    final repos = [...state.workspace.repositories];

    // Check if already exists
    final existingIndex = repos.indexWhere((r) => r.path == repo.path);
    if (existingIndex != -1) {
      // Update existing
      repos[existingIndex] = repo;
    } else {
      // Add new
      repos.add(repo);
    }

    state = state.copyWith(workspace: state.workspace.copyWith(repositories: repos));
    await _saveConfig();
  }

  /// Add multiple repositories in a single batch operation (single YAML write)
  Future<void> addRepositoriesBatch(List<WorkspaceRepository> newRepos) async {
    if (newRepos.isEmpty) return;

    final repos = [...state.workspace.repositories];

    // Add or update all repositories
    for (final newRepo in newRepos) {
      final existingIndex = repos.indexWhere((r) => r.path == newRepo.path);
      if (existingIndex != -1) {
        // Update existing
        repos[existingIndex] = newRepo;
      } else {
        // Add new
        repos.add(newRepo);
      }
    }

    // Single state update and YAML write
    state = state.copyWith(workspace: state.workspace.copyWith(repositories: repos));
    await _saveConfig();
  }

  Future<void> removeRepository(String path) async {
    final repos = state.workspace.repositories.where((r) => r.path != path).toList();
    state = state.copyWith(workspace: state.workspace.copyWith(repositories: repos));
    await _saveConfig();
  }

  Future<void> updateRepository(String path, {
    String? customAlias,
    bool? isFavorite,
    String? description,
  }) async {
    final repos = state.workspace.repositories.map((repo) {
      if (repo.path == path) {
        return repo.copyWith(
          customAlias: customAlias ?? repo.customAlias,
          isFavorite: isFavorite ?? repo.isFavorite,
          description: description ?? repo.description,
        );
      }
      return repo;
    }).toList();

    state = state.copyWith(workspace: state.workspace.copyWith(repositories: repos));
    await _saveConfig();
  }

  Future<void> markRepositoryAccessed(String path) async {
    final repos = state.workspace.repositories.map((repo) {
      if (repo.path == path) {
        return repo.copyWith(lastAccessed: DateTime.now());
      }
      return repo;
    }).toList();

    state = state.copyWith(workspace: state.workspace.copyWith(repositories: repos));
    await _saveConfig();
  }

  // Project Configuration Methods
  Future<void> updateWorkspaces(List<WorkspaceConfigEntry> workspaces) async {
    state = state.copyWith(
      workspace: state.workspace.copyWith(workspaces: workspaces),
    );
    await _saveConfig();
  }

  Future<void> updateSelectedWorkspaceId(String? workspaceId) async {
    state = state.copyWith(
      workspace: state.workspace.copyWith(selectedWorkspaceId: workspaceId),
    );
    await _saveConfig();
  }

  /// Reset to defaults
  Future<void> resetToDefaults() async {
    state = AppConfig.defaults;
    await _saveConfig();
  }
}

/// Main config provider
final configProvider = StateNotifierProvider<ConfigNotifier, AppConfig>((ref) {
  return ConfigNotifier(ref);
});

/// Config loading state provider
/// We use a StateProvider so we can update it reactively
final _configLoadingStateProvider = StateProvider<bool>((ref) => true);

final configLoadingProvider = Provider<bool>((ref) {
  return ref.watch(_configLoadingStateProvider);
});

/// Config load failure provider (shows if config failed to load on startup)
final configLoadFailureProvider = Provider<bool>((ref) {
  // This triggers a rebuild when the notifier changes
  ref.watch(configProvider);
  return ref.read(configProvider.notifier).loadFailed;
});

/// Git path invalid provider (shows if configured git path failed validation)
final gitPathInvalidProvider = Provider<bool>((ref) {
  // This triggers a rebuild when the notifier changes
  ref.watch(configProvider);
  return ref.read(configProvider.notifier).gitPathInvalid;
});

// Section providers (for convenience)
final gitConfigProvider = Provider<GitConfig>((ref) => ref.watch(configProvider).git);
final toolsConfigProvider = Provider<ToolsConfig>((ref) => ref.watch(configProvider).tools);
final uiConfigProvider = Provider<UiConfig>((ref) => ref.watch(configProvider).ui);
final browseConfigProvider = Provider<BrowseConfig>((ref) => ref.watch(configProvider).browse);
final commandLogConfigProvider = Provider<CommandLogConfig>((ref) => ref.watch(configProvider).commandLog);
final behaviorConfigProvider = Provider<BehaviorConfig>((ref) => ref.watch(configProvider).behavior);
final historyConfigProvider = Provider<HistoryConfig>((ref) => ref.watch(configProvider).history);
final workspaceConfigProvider = Provider<WorkspaceConfig>((ref) => ref.watch(configProvider).workspace);

// Individual setting providers (for backward compatibility and convenience)

// Git
final gitExecutablePathProvider = Provider<String?>((ref) => ref.watch(gitConfigProvider).executablePath);
final defaultUserNameProvider = Provider<String?>((ref) => ref.watch(gitConfigProvider).defaultUserName);
final defaultUserEmailProvider = Provider<String?>((ref) => ref.watch(gitConfigProvider).defaultUserEmail);

// Tools
final preferredTextEditorProvider = Provider<String?>((ref) => ref.watch(toolsConfigProvider).textEditor);
final preferredDiffToolProvider = Provider<DiffToolType?>((ref) => ref.watch(toolsConfigProvider).diffTool);
final preferredMergeToolProvider = Provider<DiffToolType?>((ref) => ref.watch(toolsConfigProvider).mergeTool);

// UI
final themeModeProvider = Provider<ThemeMode>((ref) => ref.watch(uiConfigProvider).themeMode);
final useSystemThemeProvider = Provider<bool>((ref) => ref.watch(uiConfigProvider).useSystemTheme);
final repositoriesViewModeProvider = Provider<RepositoriesViewMode>((ref) => ref.watch(uiConfigProvider).repositoriesViewMode);
final projectsViewModeProvider = Provider<ProjectsViewMode>((ref) => ref.watch(uiConfigProvider).projectsViewMode);
final navigationRailExtendedProvider = Provider<bool>((ref) => ref.watch(uiConfigProvider).navigationRailExtended);
final colorSchemeProvider = Provider<AppColorScheme>((ref) => ref.watch(uiConfigProvider).colorScheme);
final fontFamilyProvider = Provider<String>((ref) => ref.watch(uiConfigProvider).fontFamily);
final previewFontFamilyProvider = Provider<String>((ref) => ref.watch(uiConfigProvider).previewFontFamily);
final fontSizeProvider = Provider<AppFontSize>((ref) => ref.watch(uiConfigProvider).fontSize);
final previewFontSizeProvider = Provider<AppFontSize>((ref) => ref.watch(uiConfigProvider).previewFontSize);
final localeProvider = Provider<String?>((ref) => ref.watch(uiConfigProvider).locale);

// Browse
final showHiddenFilesProvider = Provider<bool>((ref) => ref.watch(browseConfigProvider).showHiddenFiles);
final showIgnoredFilesProvider = Provider<bool>((ref) => ref.watch(browseConfigProvider).showIgnoredFiles);
final browseViewModeProvider = Provider<BrowseViewMode>((ref) => ref.watch(browseConfigProvider).viewMode);

// Command Log
final commandLogPanelVisibleProvider = Provider<bool>((ref) => ref.watch(commandLogConfigProvider).panelVisible);
final commandLogPanelWidthProvider = Provider<double>((ref) => ref.watch(commandLogConfigProvider).panelWidth);

// Behavior
final autoFetchProvider = Provider<bool>((ref) => ref.watch(behaviorConfigProvider).autoFetch);
final autoFetchIntervalProvider = Provider<int>((ref) => ref.watch(behaviorConfigProvider).autoFetchInterval);
final confirmPushProvider = Provider<bool>((ref) => ref.watch(behaviorConfigProvider).confirmPush);
final confirmForcePushProvider = Provider<bool>((ref) => ref.watch(behaviorConfigProvider).confirmForcePush);
final confirmDeleteProvider = Provider<bool>((ref) => ref.watch(behaviorConfigProvider).confirmDelete);

// History
final defaultCommitLimitProvider = Provider<int>((ref) => ref.watch(historyConfigProvider).defaultCommitLimit);
final showCommitGraphProvider = Provider<bool>((ref) => ref.watch(historyConfigProvider).showCommitGraph);
final searchHistoryProvider = Provider<List<String>>((ref) => ref.watch(historyConfigProvider).searchHistory);

// Workspace
final currentRepositoryPathProvider = Provider<String?>((ref) => ref.watch(workspaceConfigProvider).currentRepository);

/// Check if all required settings are configured
final allRequiredSettingsConfiguredProvider = Provider<bool>((ref) {
  final config = ref.watch(configProvider);

  // Check all required settings
  final hasGitExecutable = config.git.executablePath != null && config.git.executablePath!.isNotEmpty;
  final hasTextEditor = config.tools.textEditor != null && config.tools.textEditor!.isNotEmpty;
  final hasDiffTool = config.tools.diffTool != null;
  final hasMergeTool = config.tools.mergeTool != null;
  final hasUserName = config.git.defaultUserName != null && config.git.defaultUserName!.isNotEmpty;
  final hasUserEmail = config.git.defaultUserEmail != null && config.git.defaultUserEmail!.isNotEmpty;

  return hasGitExecutable && hasTextEditor && hasDiffTool && hasMergeTool && hasUserName && hasUserEmail;
});

/// Get list of missing required settings
final missingRequiredSettingsProvider = Provider.family<List<String>, BuildContext>((ref, context) {
  final config = ref.watch(configProvider);
  final l10n = AppLocalizations.of(context)!;
  final missing = <String>[];

  if (config.git.executablePath == null || config.git.executablePath!.isEmpty) {
    missing.add(l10n.gitExecutablePath);
  }
  if (config.tools.textEditor == null || config.tools.textEditor!.isEmpty) {
    missing.add(l10n.textEditor);
  }
  if (config.tools.diffTool == null) {
    missing.add(l10n.diffTool);
  }
  if (config.tools.mergeTool == null) {
    missing.add(l10n.mergeTool);
  }
  if (config.git.defaultUserName == null || config.git.defaultUserName!.isEmpty) {
    missing.add(l10n.userName);
  }
  if (config.git.defaultUserEmail == null || config.git.defaultUserEmail!.isEmpty) {
    missing.add(l10n.userEmail);
  }

  return missing;
});
