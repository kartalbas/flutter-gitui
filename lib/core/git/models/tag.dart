import '../../extensions/date_time_extensions.dart';

/// Model representing a Git tag
class GitTag {
  /// Tag name
  final String name;

  /// Commit hash the tag points to
  final String commitHash;

  /// Tag type (lightweight or annotated)
  final GitTagType type;

  /// Tag message (for annotated tags)
  final String? message;

  /// Tagger name (for annotated tags)
  final String? taggerName;

  /// Tagger email (for annotated tags)
  final String? taggerEmail;

  /// Tag creation date (for annotated tags)
  final DateTime? date;

  /// Commit message of the tagged commit
  final String? commitMessage;

  const GitTag({
    required this.name,
    required this.commitHash,
    required this.type,
    this.message,
    this.taggerName,
    this.taggerEmail,
    this.date,
    this.commitMessage,
  });

  /// Check if this is an annotated tag
  bool get isAnnotated => type == GitTagType.annotated;

  /// Check if this is a lightweight tag
  bool get isLightweight => type == GitTagType.lightweight;

  /// Short hash (first 7 characters)
  String get shortHash => commitHash.length > 7 ? commitHash.substring(0, 7) : commitHash;

  /// Display name with type indicator
  String get displayName => isAnnotated ? '$name (annotated)' : name;

  /// Display message (tag message or commit message)
  String get displayMessage {
    if (message != null && message!.isNotEmpty) {
      return message!;
    }
    if (commitMessage != null && commitMessage!.isNotEmpty) {
      return commitMessage!;
    }
    return 'No message';
  }

  /// Display tagger info
  String? get displayTagger {
    if (taggerName != null) {
      if (taggerEmail != null) {
        return '$taggerName <$taggerEmail>';
      }
      return taggerName;
    }
    return null;
  }

  /// Display date (relative)
  /// Pass locale code (e.g., 'en', 'ar', 'de') for localized output
  String? displayDate([String? locale]) => date?.toRelativeTime(locale);

  /// Absolute date string (ISO 8601 format)
  String? get absoluteDateString => date?.toIso8601String();

  /// Display formatted date (ISO + relative)
  /// Pass locale code (e.g., 'en', 'ar', 'de') for localized relative time
  String dateDisplay([String? locale]) => date?.toDisplayString(locale) ?? 'No date';

  @override
  String toString() => 'GitTag($name -> $shortHash)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GitTag && other.name == name && other.commitHash == commitHash;
  }

  @override
  int get hashCode => name.hashCode ^ commitHash.hashCode;
}

/// Type of Git tag
enum GitTagType {
  lightweight,
  annotated,
}
