import '../models/reflog_entry.dart';

/// Parser for Git reflog output
class ReflogParser {
  /// Parse git reflog output
  ///
  /// Expected format:
  /// abc1234 HEAD@{0}: commit: Add new feature
  /// def5678 HEAD@{1}: checkout: moving from main to feature
  static List<ReflogEntry> parse(String output) {
    if (output.trim().isEmpty) {
      return [];
    }

    final entries = <ReflogEntry>[];
    final lines = output.split('\n');

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      final entry = _parseLine(line);
      if (entry != null) {
        entries.add(entry);
      }
    }

    return entries;
  }

  /// Parse a single reflog line
  static ReflogEntry? _parseLine(String line) {
    // Format: <hash> <selector>: <action>: <message>
    // Example: abc1234 HEAD@{0}: commit: Add new feature

    final parts = line.split(' ');
    if (parts.length < 2) return null;

    final hash = parts[0];

    // Find the selector (HEAD@{n})
    String? selector;
    int selectorIndex = -1;
    for (int i = 1; i < parts.length; i++) {
      if (parts[i].contains('HEAD@{') || parts[i].contains('@{')) {
        selector = parts[i].replaceAll(':', '');
        selectorIndex = i;
        break;
      }
    }

    if (selector == null || selectorIndex == -1) return null;

    // Everything after selector is action and message
    final remainingParts = parts.sublist(selectorIndex + 1);
    final remaining = remainingParts.join(' ');

    // Split by first colon to separate action from message
    String action = '';
    String message = '';

    if (remaining.contains(':')) {
      final colonIndex = remaining.indexOf(':');
      action = remaining.substring(0, colonIndex).trim();
      message = remaining.substring(colonIndex + 1).trim();
    } else {
      action = remaining.trim();
    }

    return ReflogEntry(
      hash: hash,
      selector: selector,
      action: action,
      message: message,
    );
  }
}
