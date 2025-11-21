import '../../extensions/date_time_extensions.dart';

/// Git commit information
class GitCommit {
  final String hash;
  final String shortHash;
  final String author;
  final String authorEmail;
  final DateTime authorDate;
  final String committer;
  final String committerEmail;
  final DateTime committerDate;
  final String subject;
  final String body;
  final List<String> parents;
  final List<String> refs; // branches, tags, etc.

  const GitCommit({
    required this.hash,
    required this.shortHash,
    required this.author,
    required this.authorEmail,
    required this.authorDate,
    required this.committer,
    required this.committerEmail,
    required this.committerDate,
    required this.subject,
    required this.body,
    required this.parents,
    required this.refs,
  });

  /// Full commit message (subject + body)
  String get message {
    if (body.isEmpty) return subject;
    return '$subject\n\n$body';
  }

  /// Whether this is a merge commit
  bool get isMergeCommit => parents.length > 1;

  /// First line of subject (truncated if too long)
  String get shortSubject {
    if (subject.length <= 72) return subject;
    return '${subject.substring(0, 69)}...';
  }

  /// Time since commit (e.g., "2 hours ago")
  /// Pass locale code (e.g., 'en', 'ar', 'de') for localized output
  String timeAgo([String? locale]) => authorDate.toRelativeTime(locale);

  /// Author date in ISO 8601 format (e.g., "2024-01-15T14:30:45")
  String get authorDateIso => authorDate.toIso8601String();

  /// Committer date in ISO 8601 format (e.g., "2024-01-15T14:30:45")
  String get committerDateIso => committerDate.toIso8601String();

  /// Author date with both ISO format and relative time (e.g., "2024-01-15T14:30:45 (2 hours ago)")
  /// Pass locale code (e.g., 'en', 'ar', 'de') for localized relative time
  String authorDateDisplay([String? locale]) => authorDate.toDisplayString(locale);

  /// Committer date with both ISO format and relative time (e.g., "2024-01-15T14:30:45 (2 hours ago)")
  /// Pass locale code (e.g., 'en', 'ar', 'de') for localized relative time
  String committerDateDisplay([String? locale]) => committerDate.toDisplayString(locale);

  /// Branch and tag names for this commit
  String get refsString {
    if (refs.isEmpty) return '';
    return refs.join(', ');
  }

  @override
  String toString() => '$shortHash $shortSubject';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitCommit &&
          runtimeType == other.runtimeType &&
          hash == other.hash;

  @override
  int get hashCode => hash.hashCode;
}
