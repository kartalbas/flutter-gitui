import 'package:flutter/material.dart';

import '../diff/models/diff_tool.dart';
import '../workspace/models/workspace_repository.dart';

/// Complete application configuration model
/// All settings are stored in YAML file at ~/.flutter-gitui/config.yaml
class AppConfig {
  // Git Configuration
  final GitConfig git;

  // Tools Configuration
  final ToolsConfig tools;

  // UI Preferences
  final UiConfig ui;

  // Browse View Settings
  final BrowseConfig browse;

  // Command Log Settings
  final CommandLogConfig commandLog;

  // Behavior Settings
  final BehaviorConfig behavior;

  // History Settings
  final HistoryConfig history;

  // Workspace Settings
  final WorkspaceConfig workspace;

  // App Metadata (last seen version for changelog)
  final String? lastSeenVersion;
  final bool? disableWhatsNewDialog;

  const AppConfig({
    required this.git,
    required this.tools,
    required this.ui,
    required this.browse,
    required this.commandLog,
    required this.behavior,
    required this.history,
    required this.workspace,
    this.lastSeenVersion,
    this.disableWhatsNewDialog,
  });

  /// Default configuration
  static AppConfig get defaults => AppConfig(
        git: GitConfig.defaults,
        tools: ToolsConfig.defaults,
        ui: UiConfig.defaults,
        browse: BrowseConfig.defaults,
        commandLog: CommandLogConfig.defaults,
        behavior: BehaviorConfig.defaults,
        history: HistoryConfig.defaults,
        workspace: WorkspaceConfig.defaults,
      );

  /// Copy with modifications
  AppConfig copyWith({
    GitConfig? git,
    ToolsConfig? tools,
    UiConfig? ui,
    BrowseConfig? browse,
    CommandLogConfig? commandLog,
    BehaviorConfig? behavior,
    HistoryConfig? history,
    WorkspaceConfig? workspace,
    String? lastSeenVersion,
    bool? disableWhatsNewDialog,
  }) {
    return AppConfig(
      git: git ?? this.git,
      tools: tools ?? this.tools,
      ui: ui ?? this.ui,
      browse: browse ?? this.browse,
      commandLog: commandLog ?? this.commandLog,
      behavior: behavior ?? this.behavior,
      history: history ?? this.history,
      workspace: workspace ?? this.workspace,
      lastSeenVersion: lastSeenVersion ?? this.lastSeenVersion,
      disableWhatsNewDialog: disableWhatsNewDialog ?? this.disableWhatsNewDialog,
    );
  }

  /// Convert to YAML map
  Map<String, dynamic> toYaml() {
    return {
      'git': git.toYaml(),
      'tools': tools.toYaml(),
      'ui': ui.toYaml(),
      'browse': browse.toYaml(),
      'command_log': commandLog.toYaml(),
      'behavior': behavior.toYaml(),
      'history': history.toYaml(),
      'workspace': workspace.toYaml(),
      if (lastSeenVersion != null) 'last_seen_version': lastSeenVersion,
      if (disableWhatsNewDialog != null) 'disable_whats_new_dialog': disableWhatsNewDialog,
    };
  }

  /// Create from YAML map
  factory AppConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return AppConfig(
      git: GitConfig.fromYaml(yaml['git'] as Map<dynamic, dynamic>? ?? {}),
      tools: ToolsConfig.fromYaml(yaml['tools'] as Map<dynamic, dynamic>? ?? {}),
      ui: UiConfig.fromYaml(yaml['ui'] as Map<dynamic, dynamic>? ?? {}),
      browse: BrowseConfig.fromYaml(yaml['browse'] as Map<dynamic, dynamic>? ?? {}),
      commandLog: CommandLogConfig.fromYaml(yaml['command_log'] as Map<dynamic, dynamic>? ?? {}),
      behavior: BehaviorConfig.fromYaml(yaml['behavior'] as Map<dynamic, dynamic>? ?? {}),
      history: HistoryConfig.fromYaml(yaml['history'] as Map<dynamic, dynamic>? ?? {}),
      workspace: WorkspaceConfig.fromYaml(yaml['workspace'] as Map<dynamic, dynamic>? ?? {}),
      lastSeenVersion: yaml['last_seen_version'] as String?,
      disableWhatsNewDialog: yaml['disable_whats_new_dialog'] as bool?,
    );
  }
}

/// Git configuration
class GitConfig {
  final String? executablePath;
  final String? defaultUserName;
  final String? defaultUserEmail;
  final String? gitVersion; // Detected git version
  final List<String> protectedBranches; // Branch names that are protected from deletion/renaming

  const GitConfig({
    this.executablePath,
    this.defaultUserName,
    this.defaultUserEmail,
    this.gitVersion,
    this.protectedBranches = const ['main', 'master', 'develop', 'development', 'production', 'staging'],
  });

  static const GitConfig defaults = GitConfig();

  GitConfig copyWith({
    String? executablePath,
    String? defaultUserName,
    String? defaultUserEmail,
    String? gitVersion,
    List<String>? protectedBranches,
  }) {
    return GitConfig(
      executablePath: executablePath ?? this.executablePath,
      defaultUserName: defaultUserName ?? this.defaultUserName,
      defaultUserEmail: defaultUserEmail ?? this.defaultUserEmail,
      gitVersion: gitVersion ?? this.gitVersion,
      protectedBranches: protectedBranches ?? this.protectedBranches,
    );
  }

  Map<String, dynamic> toYaml() {
    return {
      'executable_path': executablePath,
      'default_user_name': defaultUserName,
      'default_user_email': defaultUserEmail,
      'git_version': gitVersion,
      'protected_branches': protectedBranches,
    };
  }

  factory GitConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    // Parse protected branches from YAML, default to standard list if not present
    List<String> parsedProtectedBranches;
    if (yaml['protected_branches'] != null) {
      parsedProtectedBranches = (yaml['protected_branches'] as List).cast<String>();
    } else {
      parsedProtectedBranches = const ['main', 'master', 'develop', 'development', 'production', 'staging'];
    }

    return GitConfig(
      executablePath: yaml['executable_path'] as String?,
      defaultUserName: yaml['default_user_name'] as String?,
      defaultUserEmail: yaml['default_user_email'] as String?,
      gitVersion: yaml['git_version'] as String?,
      protectedBranches: parsedProtectedBranches,
    );
  }
}

/// Tools configuration
class ToolsConfig {
  final String? textEditor;
  final String? textEditorVersion;
  final DiffToolType? diffTool;
  final String? diffToolPath;
  final String? diffToolVersion;
  final DiffToolType? mergeTool;
  final String? mergeToolPath;
  final String? mergeToolVersion;
  final String? customDiffToolPath;
  final String? customDiffToolVersion;
  final String? customMergeToolPath;
  final String? customMergeToolVersion;

  const ToolsConfig({
    this.textEditor,
    this.textEditorVersion,
    this.diffTool,
    this.diffToolPath,
    this.diffToolVersion,
    this.mergeTool,
    this.mergeToolPath,
    this.mergeToolVersion,
    this.customDiffToolPath,
    this.customDiffToolVersion,
    this.customMergeToolPath,
    this.customMergeToolVersion,
  });

  static const ToolsConfig defaults = ToolsConfig();

  ToolsConfig copyWith({
    String? textEditor,
    String? textEditorVersion,
    DiffToolType? diffTool,
    String? diffToolPath,
    String? diffToolVersion,
    DiffToolType? mergeTool,
    String? mergeToolPath,
    String? mergeToolVersion,
    String? customDiffToolPath,
    String? customDiffToolVersion,
    String? customMergeToolPath,
    String? customMergeToolVersion,
  }) {
    return ToolsConfig(
      textEditor: textEditor ?? this.textEditor,
      textEditorVersion: textEditorVersion ?? this.textEditorVersion,
      diffTool: diffTool ?? this.diffTool,
      diffToolPath: diffToolPath ?? this.diffToolPath,
      diffToolVersion: diffToolVersion ?? this.diffToolVersion,
      mergeTool: mergeTool ?? this.mergeTool,
      mergeToolPath: mergeToolPath ?? this.mergeToolPath,
      mergeToolVersion: mergeToolVersion ?? this.mergeToolVersion,
      customDiffToolPath: customDiffToolPath ?? this.customDiffToolPath,
      customDiffToolVersion: customDiffToolVersion ?? this.customDiffToolVersion,
      customMergeToolPath: customMergeToolPath ?? this.customMergeToolPath,
      customMergeToolVersion: customMergeToolVersion ?? this.customMergeToolVersion,
    );
  }

  Map<String, dynamic> toYaml() {
    return {
      'text_editor': textEditor,
      'text_editor_version': textEditorVersion,
      'diff_tool': diffTool?.name,
      'diff_tool_path': diffToolPath,
      'diff_tool_version': diffToolVersion,
      'merge_tool': mergeTool?.name,
      'merge_tool_path': mergeToolPath,
      'merge_tool_version': mergeToolVersion,
      'custom_diff_tool_path': customDiffToolPath,
      'custom_diff_tool_version': customDiffToolVersion,
      'custom_merge_tool_path': customMergeToolPath,
      'custom_merge_tool_version': customMergeToolVersion,
    };
  }

  factory ToolsConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return ToolsConfig(
      textEditor: yaml['text_editor'] as String?,
      textEditorVersion: yaml['text_editor_version'] as String?,
      diffTool: yaml['diff_tool'] != null
          ? DiffToolType.values.firstWhere(
              (e) => e.name == yaml['diff_tool'],
              orElse: () => DiffToolType.vscode,
            )
          : null,
      diffToolPath: yaml['diff_tool_path'] as String?,
      diffToolVersion: yaml['diff_tool_version'] as String?,
      mergeTool: yaml['merge_tool'] != null
          ? DiffToolType.values.firstWhere(
              (e) => e.name == yaml['merge_tool'],
              orElse: () => DiffToolType.vscode,
            )
          : null,
      mergeToolPath: yaml['merge_tool_path'] as String?,
      mergeToolVersion: yaml['merge_tool_version'] as String?,
      customDiffToolPath: yaml['custom_diff_tool_path'] as String?,
      customDiffToolVersion: yaml['custom_diff_tool_version'] as String?,
      customMergeToolPath: yaml['custom_merge_tool_path'] as String?,
      customMergeToolVersion: yaml['custom_merge_tool_version'] as String?,
    );
  }
}

/// UI configuration
class UiConfig {
  final ThemeMode themeMode;
  final bool useSystemTheme;
  final RepositoriesViewMode repositoriesViewMode;
  final ProjectsViewMode projectsViewMode;
  final bool navigationRailExtended;
  final AppColorScheme colorScheme;
  final String fontFamily;
  final String previewFontFamily;
  final AppFontSize fontSize;
  final AppFontSize previewFontSize;
  final String? locale;
  final bool diffCompactMode;
  final AppAnimationSpeed animationSpeed;

  const UiConfig({
    this.themeMode = ThemeMode.system,
    this.useSystemTheme = true,
    this.repositoriesViewMode = RepositoriesViewMode.grid,
    this.projectsViewMode = ProjectsViewMode.grid,
    this.navigationRailExtended = false,
    this.colorScheme = AppColorScheme.deepPurple,
    this.fontFamily = 'Inter',
    this.previewFontFamily = 'JetBrains Mono',
    this.fontSize = AppFontSize.medium,
    this.previewFontSize = AppFontSize.medium,
    this.locale,
    this.diffCompactMode = false,
    this.animationSpeed = AppAnimationSpeed.normal,
  });

  static const UiConfig defaults = UiConfig();

  UiConfig copyWith({
    ThemeMode? themeMode,
    bool? useSystemTheme,
    RepositoriesViewMode? repositoriesViewMode,
    ProjectsViewMode? projectsViewMode,
    bool? navigationRailExtended,
    AppColorScheme? colorScheme,
    String? fontFamily,
    String? previewFontFamily,
    AppFontSize? fontSize,
    AppFontSize? previewFontSize,
    String? locale,
    bool? diffCompactMode,
    AppAnimationSpeed? animationSpeed,
  }) {
    return UiConfig(
      themeMode: themeMode ?? this.themeMode,
      useSystemTheme: useSystemTheme ?? this.useSystemTheme,
      repositoriesViewMode: repositoriesViewMode ?? this.repositoriesViewMode,
      projectsViewMode: projectsViewMode ?? this.projectsViewMode,
      navigationRailExtended: navigationRailExtended ?? this.navigationRailExtended,
      colorScheme: colorScheme ?? this.colorScheme,
      fontFamily: fontFamily ?? this.fontFamily,
      previewFontFamily: previewFontFamily ?? this.previewFontFamily,
      fontSize: fontSize ?? this.fontSize,
      previewFontSize: previewFontSize ?? this.previewFontSize,
      locale: locale ?? this.locale,
      diffCompactMode: diffCompactMode ?? this.diffCompactMode,
      animationSpeed: animationSpeed ?? this.animationSpeed,
    );
  }

  Map<String, dynamic> toYaml() {
    return {
      'theme_mode': themeMode.name,
      'use_system_theme': useSystemTheme,
      'repositories_view_mode': repositoriesViewMode.name,
      'projects_view_mode': projectsViewMode.name,
      'navigation_rail_extended': navigationRailExtended,
      'color_scheme': colorScheme.name,
      'font_family': fontFamily,
      'preview_font_family': previewFontFamily,
      'font_size': fontSize.name,
      'preview_font_size': previewFontSize.name,
      'locale': locale,
      'diff_compact_mode': diffCompactMode,
      'animation_speed': animationSpeed.name,
    };
  }

  factory UiConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return UiConfig(
      themeMode: yaml['theme_mode'] != null
          ? ThemeMode.values.firstWhere(
              (e) => e.name == yaml['theme_mode'],
              orElse: () => ThemeMode.system,
            )
          : ThemeMode.system,
      useSystemTheme: yaml['use_system_theme'] as bool? ?? true,
      repositoriesViewMode: yaml['repositories_view_mode'] != null
          ? RepositoriesViewMode.values.firstWhere(
              (e) => e.name == yaml['repositories_view_mode'],
              orElse: () => RepositoriesViewMode.grid,
            )
          : RepositoriesViewMode.grid,
      projectsViewMode: yaml['projects_view_mode'] != null
          ? ProjectsViewMode.values.firstWhere(
              (e) => e.name == yaml['projects_view_mode'],
              orElse: () => ProjectsViewMode.grid,
            )
          : ProjectsViewMode.grid,
      navigationRailExtended: yaml['navigation_rail_extended'] as bool? ?? false,
      colorScheme: yaml['color_scheme'] != null
          ? AppColorScheme.values.firstWhere(
              (e) => e.name == yaml['color_scheme'],
              orElse: () => AppColorScheme.deepPurple,
            )
          : AppColorScheme.deepPurple,
      fontFamily: yaml['font_family'] as String? ?? 'Inter',
      previewFontFamily: yaml['preview_font_family'] as String? ?? 'JetBrains Mono',
      fontSize: yaml['font_size'] != null
          ? AppFontSize.values.firstWhere(
              (e) => e.name == yaml['font_size'],
              orElse: () => AppFontSize.medium,
            )
          : AppFontSize.medium,
      previewFontSize: yaml['preview_font_size'] != null
          ? AppFontSize.values.firstWhere(
              (e) => e.name == yaml['preview_font_size'],
              orElse: () => AppFontSize.medium,
            )
          : AppFontSize.medium,
      locale: yaml['locale'] as String?,
      diffCompactMode: yaml['diff_compact_mode'] as bool? ?? false,
      animationSpeed: yaml['animation_speed'] != null
          ? AppAnimationSpeed.values.firstWhere(
              (e) => e.name == yaml['animation_speed'],
              orElse: () => AppAnimationSpeed.normal,
            )
          : AppAnimationSpeed.normal,
    );
  }
}

/// Application color schemes
enum AppColorScheme {
  /// Material Deep Purple & Amber
  deepPurple,

  /// Material Indigo & Cyan
  indigo,

  /// Material Blue & Orange
  blue,

  /// Material Teal & Amber
  teal,

  /// Material Green & Orange
  green,

  /// Material Red & Cyan
  red,

  /// Material Pink & Teal
  pink,

  /// Material Purple & Green
  purple,

  /// Material Deep Orange & Cyan
  deepOrange,

  /// Material Blue Grey & Orange
  blueGrey,
}

/// Font size options
enum AppFontSize {
  tiny,
  small,
  medium,
  large,
}

/// Repositories view mode
enum RepositoriesViewMode {
  grid,
  list,
}

/// Projects view mode
enum ProjectsViewMode {
  grid,
  list,
}

/// Animation speed preference
enum AppAnimationSpeed {
  /// Fast animations (0.7x speed) - instant feel
  fast,

  /// Normal animations (1.0x speed) - default
  normal,

  /// Slow animations (1.5x speed) - accessibility
  slow,

  /// No animations (0x) - reduce motion for accessibility
  none,
}

/// Browse configuration
class BrowseConfig {
  final bool showHiddenFiles;
  final bool showIgnoredFiles;
  final BrowseViewMode viewMode;

  const BrowseConfig({
    this.showHiddenFiles = false,
    this.showIgnoredFiles = false,
    this.viewMode = BrowseViewMode.history,
  });

  static const BrowseConfig defaults = BrowseConfig();

  BrowseConfig copyWith({
    bool? showHiddenFiles,
    bool? showIgnoredFiles,
    BrowseViewMode? viewMode,
  }) {
    return BrowseConfig(
      showHiddenFiles: showHiddenFiles ?? this.showHiddenFiles,
      showIgnoredFiles: showIgnoredFiles ?? this.showIgnoredFiles,
      viewMode: viewMode ?? this.viewMode,
    );
  }

  Map<String, dynamic> toYaml() {
    return {
      'show_hidden_files': showHiddenFiles,
      'show_ignored_files': showIgnoredFiles,
      'view_mode': viewMode.name,
    };
  }

  factory BrowseConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return BrowseConfig(
      showHiddenFiles: yaml['show_hidden_files'] as bool? ?? false,
      showIgnoredFiles: yaml['show_ignored_files'] as bool? ?? false,
      viewMode: yaml['view_mode'] != null
          ? BrowseViewMode.values.firstWhere(
              (e) => e.name == yaml['view_mode'],
              orElse: () => BrowseViewMode.history,
            )
          : BrowseViewMode.history,
    );
  }
}

/// Browse view mode
enum BrowseViewMode {
  history,
  preview,
  blame, // Who changed what when (line-by-line)
}

/// Command log configuration
class CommandLogConfig {
  final bool panelVisible;
  final double panelWidth;

  const CommandLogConfig({
    this.panelVisible = false,
    this.panelWidth = 600.0,
  });

  static const CommandLogConfig defaults = CommandLogConfig();

  CommandLogConfig copyWith({
    bool? panelVisible,
    double? panelWidth,
  }) {
    return CommandLogConfig(
      panelVisible: panelVisible ?? this.panelVisible,
      panelWidth: panelWidth ?? this.panelWidth,
    );
  }

  Map<String, dynamic> toYaml() {
    return {
      'panel_visible': panelVisible,
      'panel_width': panelWidth,
    };
  }

  factory CommandLogConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return CommandLogConfig(
      panelVisible: yaml['panel_visible'] as bool? ?? false,
      panelWidth: (yaml['panel_width'] as num?)?.toDouble() ?? 600.0,
    );
  }
}

/// Behavior configuration
class BehaviorConfig {
  final bool autoFetch;
  final int autoFetchInterval; // minutes
  final bool confirmPush;
  final bool confirmForcePush;
  final bool confirmDelete;

  const BehaviorConfig({
    this.autoFetch = false,
    this.autoFetchInterval = 5,
    this.confirmPush = true,
    this.confirmForcePush = true,
    this.confirmDelete = true,
  });

  static const BehaviorConfig defaults = BehaviorConfig();

  BehaviorConfig copyWith({
    bool? autoFetch,
    int? autoFetchInterval,
    bool? confirmPush,
    bool? confirmForcePush,
    bool? confirmDelete,
  }) {
    return BehaviorConfig(
      autoFetch: autoFetch ?? this.autoFetch,
      autoFetchInterval: autoFetchInterval ?? this.autoFetchInterval,
      confirmPush: confirmPush ?? this.confirmPush,
      confirmForcePush: confirmForcePush ?? this.confirmForcePush,
      confirmDelete: confirmDelete ?? this.confirmDelete,
    );
  }

  Map<String, dynamic> toYaml() {
    return {
      'auto_fetch': autoFetch,
      'auto_fetch_interval': autoFetchInterval,
      'confirm_push': confirmPush,
      'confirm_force_push': confirmForcePush,
      'confirm_delete': confirmDelete,
    };
  }

  factory BehaviorConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return BehaviorConfig(
      autoFetch: yaml['auto_fetch'] as bool? ?? false,
      autoFetchInterval: yaml['auto_fetch_interval'] as int? ?? 5,
      confirmPush: yaml['confirm_push'] as bool? ?? true,
      confirmForcePush: yaml['confirm_force_push'] as bool? ?? true,
      confirmDelete: yaml['confirm_delete'] as bool? ?? true,
    );
  }
}

/// History configuration
class HistoryConfig {
  final int defaultCommitLimit;
  final bool showCommitGraph;
  final List<String> searchHistory;

  const HistoryConfig({
    this.defaultCommitLimit = 100,
    this.showCommitGraph = true,
    this.searchHistory = const [],
  });

  static const HistoryConfig defaults = HistoryConfig();

  HistoryConfig copyWith({
    int? defaultCommitLimit,
    bool? showCommitGraph,
    List<String>? searchHistory,
  }) {
    return HistoryConfig(
      defaultCommitLimit: defaultCommitLimit ?? this.defaultCommitLimit,
      showCommitGraph: showCommitGraph ?? this.showCommitGraph,
      searchHistory: searchHistory ?? this.searchHistory,
    );
  }

  Map<String, dynamic> toYaml() {
    return {
      'default_commit_limit': defaultCommitLimit,
      'show_commit_graph': showCommitGraph,
      'search_history': searchHistory,
    };
  }

  factory HistoryConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return HistoryConfig(
      defaultCommitLimit: yaml['default_commit_limit'] as int? ?? 100,
      showCommitGraph: yaml['show_commit_graph'] as bool? ?? true,
      searchHistory: yaml['search_history'] != null
          ? (yaml['search_history'] as List).map((e) => e.toString()).toList()
          : [],
    );
  }
}

/// Workspace configuration
class WorkspaceConfig {
  final String? currentRepository;
  final List<WorkspaceRepository> repositories;
  final List<WorkspaceConfigEntry> workspaces;
  final String? selectedWorkspaceId;

  const WorkspaceConfig({
    this.currentRepository,
    this.repositories = const [],
    this.workspaces = const [],
    this.selectedWorkspaceId,
  });

  static const WorkspaceConfig defaults = WorkspaceConfig();

  WorkspaceConfig copyWith({
    String? currentRepository,
    List<WorkspaceRepository>? repositories,
    List<WorkspaceConfigEntry>? workspaces,
    String? selectedWorkspaceId,
  }) {
    return WorkspaceConfig(
      currentRepository: currentRepository ?? this.currentRepository,
      repositories: repositories ?? this.repositories,
      workspaces: workspaces ?? this.workspaces,
      selectedWorkspaceId: selectedWorkspaceId ?? this.selectedWorkspaceId,
    );
  }

  Map<String, dynamic> toYaml() {
    return {
      'current_repository': currentRepository,
      'repositories': repositories.map((r) => r.toYaml()).toList(),
      'workspaces': workspaces.map((w) => w.toYaml()).toList(),
      'selected_workspace_id': selectedWorkspaceId,
    };
  }

  factory WorkspaceConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return WorkspaceConfig(
      currentRepository: yaml['current_repository'] as String?,
      repositories: yaml['repositories'] != null
          ? (yaml['repositories'] as List)
              .map((r) => WorkspaceRepository.fromYaml(r as Map<dynamic, dynamic>))
              .toList()
          : [],
      workspaces: (yaml['workspaces'] ?? yaml['projects']) != null
          ? ((yaml['workspaces'] ?? yaml['projects']) as List)
              .map((w) => WorkspaceConfigEntry.fromYaml(w as Map<dynamic, dynamic>))
              .toList()
          : [],
      selectedWorkspaceId: yaml['selected_workspace_id'] ?? yaml['selected_project_id'] as String?,
    );
  }
}

/// Workspace configuration entry (stored in YAML)
/// Represents a workspace's data in the configuration file
class WorkspaceConfigEntry {
  final String id;
  final String name;
  final String? description;
  final int color; // Color value as int for YAML storage
  final String? icon;
  final List<String> repositoryPaths;
  final String? lastSelectedRepository; // Remember last selected repository for this project
  final String createdAt;
  final String? updatedAt;

  const WorkspaceConfigEntry({
    required this.id,
    required this.name,
    this.description,
    required this.color,
    this.icon,
    required this.repositoryPaths,
    this.lastSelectedRepository,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toYaml() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color,
      'icon': icon,
      'repository_paths': repositoryPaths,
      'last_selected_repository': lastSelectedRepository,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory WorkspaceConfigEntry.fromYaml(Map<dynamic, dynamic> yaml) {
    return WorkspaceConfigEntry(
      id: yaml['id'] as String,
      name: yaml['name'] as String,
      description: yaml['description'] as String?,
      color: yaml['color'] as int,
      icon: yaml['icon'] as String?,
      repositoryPaths: yaml['repository_paths'] != null
          ? (yaml['repository_paths'] as List).map((e) => e.toString()).toList()
          : [],
      lastSelectedRepository: yaml['last_selected_repository'] as String?,
      createdAt: yaml['created_at'] as String,
      updatedAt: yaml['updated_at'] as String?,
    );
  }
}
