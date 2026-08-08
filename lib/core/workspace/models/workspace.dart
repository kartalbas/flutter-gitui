import 'package:flutter/material.dart';

/// A workspace that groups multiple repositories
class Workspace {
  /// Identifier of the one workspace the application creates by itself.
  ///
  /// It exists on every installation, cannot be deleted, and is the fallback
  /// selection, so several call sites have to recognise it. Its name and
  /// description are supplied by the application rather than the user; see
  /// `default_workspace_text.dart` for how they reach the screen.
  static const String defaultId = 'default';

  final String id;
  final String name;
  final String? description;
  final Color color;
  final String? icon;
  final List<String> repositoryPaths;
  final String?
  lastSelectedRepository; // Remember last selected repository for this workspace
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Workspace({
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

  /// The workspace the application creates on an installation that has none.
  ///
  /// It deliberately carries no name and no description. Those two words are
  /// written by the application rather than by the user, so storing them would
  /// freeze one language into the user's config file and render it there in
  /// every locale from then on; instead they are resolved from the active
  /// locale at display time (`default_workspace_text.dart`).
  factory Workspace.createDefault() => Workspace(
    id: defaultId,
    name: '',
    color: WorkspaceColors.defaults[0],
    repositoryPaths: const [],
    createdAt: DateTime.now(),
  );

  /// Create a copy with updated fields
  Workspace copyWith({
    String? name,
    String? description,
    Color? color,
    String? icon,
    List<String>? repositoryPaths,
    String? lastSelectedRepository,
    DateTime? updatedAt,
  }) {
    return Workspace(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      repositoryPaths: repositoryPaths ?? this.repositoryPaths,
      lastSelectedRepository:
          lastSelectedRepository ?? this.lastSelectedRepository,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color.toARGB32(),
      'icon': icon,
      'repositoryPaths': repositoryPaths,
      'lastSelectedRepository': lastSelectedRepository,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Create from JSON
  factory Workspace.fromJson(Map<String, dynamic> json) {
    return Workspace(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      color: Color(json['color'] as int),
      icon: json['icon'] as String?,
      repositoryPaths: (json['repositoryPaths'] as List<dynamic>)
          .cast<String>(),
      lastSelectedRepository: json['lastSelectedRepository'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  /// Add a repository to this workspace
  Workspace addRepository(String path) {
    if (repositoryPaths.contains(path)) {
      return this;
    }
    return copyWith(
      repositoryPaths: [...repositoryPaths, path],
      updatedAt: DateTime.now(),
    );
  }

  /// Remove a repository from this workspace
  Workspace removeRepository(String path) {
    return copyWith(
      repositoryPaths: repositoryPaths.where((p) => p != path).toList(),
      updatedAt: DateTime.now(),
    );
  }

  /// Check if this workspace contains a repository
  bool containsRepository(String path) {
    return repositoryPaths.contains(path);
  }

  /// Which member of the skin's colour series this workspace wears.
  ///
  /// The model persists the colour as an ARGB value picked from
  /// [WorkspaceColors.defaults], so the index is derived rather than stored.
  /// `Tone.series` needs the index because the palette itself is the skin's
  /// (`MaterialInk.seriesPalette` carries the same twelve values today, and a
  /// different skin may carry others). A legacy value that is not in the
  /// palette lands on the last slot via the series' modulo rather than
  /// throwing; storing the index outright - and deleting this palette - is
  /// the `controls.seriesPicker` conversion's job, because only then does the
  /// application stop being able to enumerate the swatches at all.
  int get colorIndex => WorkspaceColors.defaults.indexOf(color);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Workspace && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Workspace(id: $id, name: $name, repos: ${repositoryPaths.length})';
}

/// Predefined workspace colors
class WorkspaceColors {
  static const List<Color> defaults = [
    Color(0xFF2196F3), // Blue
    Color(0xFF4CAF50), // Green
    Color(0xFFF44336), // Red
    Color(0xFFFF9800), // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFF00BCD4), // Cyan
    Color(0xFFFFEB3B), // Yellow
    Color(0xFF795548), // Brown
    Color(0xFF607D8B), // Blue Grey
    Color(0xFFE91E63), // Pink
    Color(0xFF3F51B5), // Indigo
    Color(0xFF009688), // Teal
  ];

  static Color random() {
    return defaults[DateTime.now().millisecondsSinceEpoch % defaults.length];
  }
}
