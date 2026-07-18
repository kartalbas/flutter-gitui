import 'package:flutter/material.dart';

/// A project that groups multiple repositories
class Project {
  final String id;
  final String name;
  final String? description;
  final Color color;
  final String? icon;
  final List<String> repositoryPaths;
  final String? lastSelectedRepository; // Remember last selected repository for this project
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Project({
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

  /// Create a copy with updated fields
  Project copyWith({
    String? name,
    String? description,
    Color? color,
    String? icon,
    List<String>? repositoryPaths,
    String? lastSelectedRepository,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      repositoryPaths: repositoryPaths ?? this.repositoryPaths,
      lastSelectedRepository: lastSelectedRepository ?? this.lastSelectedRepository,
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
  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      color: Color(json['color'] as int),
      icon: json['icon'] as String?,
      repositoryPaths: (json['repositoryPaths'] as List<dynamic>).cast<String>(),
      lastSelectedRepository: json['lastSelectedRepository'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  /// Add a repository to this project
  Project addRepository(String path) {
    if (repositoryPaths.contains(path)) {
      return this;
    }
    return copyWith(
      repositoryPaths: [...repositoryPaths, path],
      updatedAt: DateTime.now(),
    );
  }

  /// Remove a repository from this project
  Project removeRepository(String path) {
    return copyWith(
      repositoryPaths: repositoryPaths.where((p) => p != path).toList(),
      updatedAt: DateTime.now(),
    );
  }

  /// Check if this project contains a repository
  bool containsRepository(String path) {
    return repositoryPaths.contains(path);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Project && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Project(id: $id, name: $name, repos: ${repositoryPaths.length})';
}

/// Predefined project colors
class ProjectColors {
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
