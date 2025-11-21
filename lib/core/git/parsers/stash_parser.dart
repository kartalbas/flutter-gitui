import '../models/stash.dart';

/// Parser for git stash output
class StashParser {
  /// Parse git stash list output
  ///
  /// Expected format (using --format):
  /// stash@{0}|hash|timestamp|WIP on branch: message
  ///
  /// Example:
  /// stash@{0}|a1b2c3d4|1234567890|WIP on master: Added feature
  static List<GitStash> parseStashList(String output) {
    if (output.trim().isEmpty) {
      return [];
    }

    final stashes = <GitStash>[];
    final lines = output.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      try {
        final parts = trimmed.split('|');
        if (parts.length < 4) continue;

        final ref = parts[0].trim();
        final hash = parts[1].trim();
        final timestampStr = parts[2].trim();
        final fullMessage = parts[3].trim();

        // Extract index from ref (stash@{0} -> 0)
        final indexMatch = RegExp(r'stash@\{(\d+)\}').firstMatch(ref);
        if (indexMatch == null) continue;
        final index = int.parse(indexMatch.group(1)!);

        // Parse timestamp
        DateTime? timestamp;
        try {
          final unixTimestamp = int.parse(timestampStr);
          timestamp = DateTime.fromMillisecondsSinceEpoch(unixTimestamp * 1000);
        } catch (_) {
          // If timestamp parsing fails, continue without it
        }

        // Extract branch and message from fullMessage
        // Format: "WIP on branch: message" or "On branch: message"
        String branch = 'unknown';
        String message = fullMessage;

        final wipMatch = RegExp(r'^(?:WIP on|On) ([^:]+):(.*)').firstMatch(fullMessage);
        if (wipMatch != null) {
          branch = wipMatch.group(1)?.trim() ?? 'unknown';
          message = wipMatch.group(2)?.trim() ?? '';
        }

        stashes.add(GitStash(
          ref: ref,
          index: index,
          hash: hash,
          branch: branch,
          message: message,
          timestamp: timestamp,
        ));
      } catch (e) {
        // Skip malformed lines
        continue;
      }
    }

    return stashes;
  }

  /// Parse stash show output (file changes)
  ///
  /// Example output:
  ///  file1.dart | 10 +++++-----
  ///  file2.dart | 5 +++--
  ///  2 files changed, 8 insertions(+), 7 deletions(-)
  static Map<String, dynamic> parseStashShow(String output) {
    final result = <String, dynamic>{
      'files': <String>[],
      'stats': <String, int>{},
    };

    if (output.trim().isEmpty) {
      return result;
    }

    final lines = output.split('\n');
    final files = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Parse file line: " file.dart | 10 +++++-----"
      final match = RegExp(r'^\s*([^|]+)\s+\|').firstMatch(line);
      if (match != null) {
        final filePath = match.group(1)?.trim();
        if (filePath != null && filePath.isNotEmpty) {
          files.add(filePath);
        }
      }

      // Parse summary line: "2 files changed, 8 insertions(+), 7 deletions(-)"
      final summaryMatch = RegExp(
        r'(\d+) file[s]? changed(?:, (\d+) insertion[s]?\(\+\))?(?:, (\d+) deletion[s]?\(-\))?'
      ).firstMatch(line);

      if (summaryMatch != null) {
        result['stats'] = {
          'files': int.parse(summaryMatch.group(1) ?? '0'),
          'insertions': int.parse(summaryMatch.group(2) ?? '0'),
          'deletions': int.parse(summaryMatch.group(3) ?? '0'),
        };
      }
    }

    result['files'] = files;
    return result;
  }
}
