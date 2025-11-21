import 'dart:io';

/// Represents a Git repository in the workspace
class WorkspaceRepository {
  final String path;
  final String name;
  final String? customAlias;
  final DateTime lastAccessed;
  final bool isFavorite;
  final String? description;

  const WorkspaceRepository({
    required this.path,
    required this.name,
    this.customAlias,
    required this.lastAccessed,
    this.isFavorite = false,
    this.description,
  });

  /// Get display name (custom alias or folder name)
  String get displayName => customAlias ?? name;

  /// Check if repository directory exists
  bool get exists => Directory(path).existsSync();

  /// Check if path is a valid Git repository
  bool get isValidGitRepo {
    final gitDir = Directory('$path/.git');
    return exists && gitDir.existsSync();
  }

  /// Create from JSON
  factory WorkspaceRepository.fromJson(Map<String, dynamic> json) {
    return WorkspaceRepository(
      path: json['path'] as String,
      name: json['name'] as String,
      customAlias: json['customAlias'] as String?,
      lastAccessed: DateTime.parse(json['lastAccessed'] as String),
      isFavorite: json['isFavorite'] as bool? ?? false,
      description: json['description'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'name': name,
      'customAlias': customAlias,
      'lastAccessed': lastAccessed.toIso8601String(),
      'isFavorite': isFavorite,
      'description': description,
    };
  }

  /// Create from YAML
  factory WorkspaceRepository.fromYaml(Map<dynamic, dynamic> yaml) {
    final path = yaml['path'] as String;

    // Extract name from YAML or derive from path
    String name;
    if (yaml['name'] != null) {
      final nameFromYaml = yaml['name'] as String;
      // If name contains path separator, extract just the folder name
      name = nameFromYaml.contains('/') || nameFromYaml.contains('\\')
          ? nameFromYaml.replaceAll('\\', '/').split('/').last
          : nameFromYaml;
    } else {
      // Derive name from path if not present in YAML
      name = path.replaceAll('\\', '/').split('/').last;
    }

    return WorkspaceRepository(
      path: path,
      name: name,
      customAlias: yaml['custom_alias'] as String?,
      isFavorite: yaml['is_favorite'] as bool? ?? false,
      description: yaml['description'] as String?,
      lastAccessed: yaml['last_accessed'] != null
          ? DateTime.parse(yaml['last_accessed'] as String)
          : DateTime.now(),
    );
  }

  /// Convert to YAML
  Map<String, dynamic> toYaml() {
    return {
      'path': path,
      'name': name,
      'custom_alias': customAlias,
      'is_favorite': isFavorite,
      'description': description,
      'last_accessed': lastAccessed.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  WorkspaceRepository copyWith({
    String? path,
    String? name,
    String? customAlias,
    DateTime? lastAccessed,
    bool? isFavorite,
    String? description,
  }) {
    return WorkspaceRepository(
      path: path ?? this.path,
      name: name ?? this.name,
      customAlias: customAlias ?? this.customAlias,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      isFavorite: isFavorite ?? this.isFavorite,
      description: description ?? this.description,
    );
  }

  /// Create from directory path
  static WorkspaceRepository fromPath(String path) {
    // Extract folder name, handling both / and \ separators
    final name = path.replaceAll('\\', '/').split('/').last;

    return WorkspaceRepository(
      path: path,
      name: name,
      lastAccessed: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkspaceRepository &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'WorkspaceRepository(path: $path, name: $displayName)';
}
