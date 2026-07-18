import '../models/commit.dart';

/// Parser for `git log` output
class LogParser {
  LogParser._();

  /// Custom format string for git log
  /// Format: hash|short|author|email|date|committer|cemail|cdate|parents|refs|subject|body
  static const String gitLogFormat =
      '%H|%h|%an|%ae|%aI|%cn|%ce|%cI|%P|%D|%s|%b';

  /// Separator between commits
  static const String commitSeparator = '<<COMMIT_END>>';

  /// Parse git log output with custom format
  ///
  /// Expected format per commit:
  /// hash|short|author|email|date|committer|cemail|cdate|parents|refs|subject
  /// body (multiple lines)
  /// `<<COMMIT_END>>`
  static List<GitCommit> parse(String output) {
    if (output.trim().isEmpty) {
      return [];
    }

    final commits = <GitCommit>[];
    final commitBlocks = output.split(commitSeparator);

    for (final block in commitBlocks) {
      final trimmed = block.trim();
      if (trimmed.isEmpty) continue;

      try {
        final commit = _parseCommitBlock(trimmed);
        if (commit != null) {
          commits.add(commit);
        }
      } catch (e) {
        // Skip malformed commits
        continue;
      }
    }

    return commits;
  }

  static GitCommit? _parseCommitBlock(String block) {
    final lines = block.split('\n');
    if (lines.isEmpty) return null;

    // First line contains the pipe-separated fields
    final fields = lines[0].split('|');
    if (fields.length < 11) return null; // Need at least 11 fields

    final hash = fields[0].trim();
    final shortHash = fields[1].trim();
    final author = fields[2].trim();
    final authorEmail = fields[3].trim();
    final authorDateStr = fields[4].trim();
    final committer = fields[5].trim();
    final committerEmail = fields[6].trim();
    final committerDateStr = fields[7].trim();
    final parentsStr = fields[8].trim();
    final refsStr = fields[9].trim();
    final subject = fields[10].trim();

    // Body is everything after the first line
    final body = lines.length > 1 ? lines.sublist(1).join('\n').trim() : '';

    // Parse dates
    DateTime? authorDate;
    DateTime? committerDate;

    try {
      authorDate = DateTime.parse(authorDateStr);
    } catch (e) {
      authorDate = DateTime.now();
    }

    try {
      committerDate = DateTime.parse(committerDateStr);
    } catch (e) {
      committerDate = authorDate;
    }

    // Parse parents (space-separated hashes)
    final parents = parentsStr.isEmpty
        ? <String>[]
        : parentsStr.split(' ').where((p) => p.isNotEmpty).toList();

    // Parse refs (comma-separated: HEAD -> main, origin/main, tag: v1.0)
    final refs = refsStr.isEmpty
        ? <String>[]
        : refsStr
            .split(',')
            .map((r) => r.trim())
            .where((r) => r.isNotEmpty)
            .toList();

    return GitCommit(
      hash: hash,
      shortHash: shortHash,
      author: author,
      authorEmail: authorEmail,
      authorDate: authorDate,
      committer: committer,
      committerEmail: committerEmail,
      committerDate: committerDate,
      subject: subject,
      body: body,
      parents: parents,
      refs: refs,
    );
  }

  /// Parse a simple log format (one line per commit)
  /// Format: hash subject
  static List<Map<String, String>> parseSimple(String output) {
    if (output.trim().isEmpty) {
      return [];
    }

    final commits = <Map<String, String>>[];
    final lines = output.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final parts = trimmed.split(' ');
      if (parts.length < 2) continue;

      commits.add({
        'hash': parts[0],
        'subject': parts.sublist(1).join(' '),
      });
    }

    return commits;
  }
}
