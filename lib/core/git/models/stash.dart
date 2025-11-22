import '../../extensions/date_time_extensions.dart';

/// Model representing a Git stash entry
class GitStash {
  /// Stash reference (e.g., "stash@{0}")
  final String ref;

  /// Stash index number (e.g., 0 for "stash@{0}")
  final int index;

  /// Stash commit hash
  final String hash;

  /// Branch where stash was created
  final String branch;

  /// Stash message/description
  final String message;

  /// Timestamp when stash was created
  final DateTime? timestamp;

  const GitStash({
    required this.ref,
    required this.index,
    required this.hash,
    required this.branch,
    required this.message,
    this.timestamp,
  });

  /// Display title for the stash
  String get displayTitle {
    if (message.isNotEmpty) {
      return message;
    }
    return 'WIP on $branch';
  }

  /// Display subtitle with timestamp
  /// Pass locale code (e.g., 'en', 'ar', 'de') for localized relative time
  String displaySubtitle([String? locale]) {
    final parts = <String>[];
    parts.add('on $branch');

    if (timestamp != null) {
      parts.add(timestamp!.toRelativeTime(locale));
    }

    return parts.join(' • ');
  }

  /// ISO 8601 formatted timestamp
  String get timestampIso => timestamp?.toIso8601String() ?? '';

  /// Display formatted timestamp (ISO + relative)
  /// Pass locale code (e.g., 'en', 'ar', 'de') for localized relative time
  String timestampDisplay([String? locale]) => timestamp?.toDisplayString(locale) ?? 'No timestamp';

  /// Short hash (first 7 characters)
  String get shortHash => hash.length > 7 ? hash.substring(0, 7) : hash;

  /// Check if this is the most recent stash
  bool get isLatest => index == 0;

  @override
  String toString() => 'GitStash($ref: $message)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GitStash && other.ref == ref && other.hash == hash;
  }

  @override
  int get hashCode => ref.hashCode ^ hash.hashCode;
}
