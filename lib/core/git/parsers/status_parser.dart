import 'dart:convert';

import '../models/file_status.dart';

/// Parser for `git status --porcelain` output
class StatusParser {
  StatusParser._();

  /// Parse git status --porcelain output
  ///
  /// Format: XY PATH
  /// Where X = index status, Y = work tree status
  ///
  /// Status codes:
  /// ' ' = unmodified
  /// M = modified
  /// A = added
  /// D = deleted
  /// R = renamed
  /// C = copied
  /// U = updated but unmerged
  /// ? = untracked
  /// ! = ignored
  static List<FileStatus> parse(String output) {
    if (output.trim().isEmpty) {
      return [];
    }

    final lines = output.split('\n').where((line) => line.isNotEmpty);
    final statuses = <FileStatus>[];

    for (final line in lines) {
      if (line.length < 4) continue;

      // Parse status codes
      final indexCode = line[0];
      final workTreeCode = line[1];
      final path = line.substring(3); // Skip "XY "

      // Handle renames (format: "R  old.txt -> new.txt")
      String? oldPath;
      String newPath = _unquotePath(path);

      if (indexCode == 'R' || workTreeCode == 'R') {
        final parts = path.split(' -> ');
        if (parts.length == 2) {
          oldPath = _unquotePath(parts[0].trim());
          newPath = _unquotePath(parts[1].trim());
        }
      }

      final status = FileStatus(
        path: newPath,
        indexStatus: _parseStatus(indexCode),
        workTreeStatus: _parseStatus(workTreeCode),
        oldPath: oldPath,
      );

      statuses.add(status);
    }

    return statuses;
  }

  /// Single-character escapes git emits inside a quoted path, as raw bytes.
  static const Map<String, int> _escapeCodes = {
    'a': 0x07,
    'b': 0x08,
    'f': 0x0C,
    'n': 0x0A,
    'r': 0x0D,
    't': 0x09,
    'v': 0x0B,
    '"': 0x22,
    r'\': 0x5C,
  };

  /// Undo git's C-style quoting of a porcelain path.
  ///
  /// Git wraps any path containing non-ASCII bytes, quotes, backslashes or
  /// control characters in double quotes and escapes the bytes, so `ä.txt`
  /// arrives as `"\303\244.txt"`. Handing that literal to `git add` or to
  /// `File()` would target a name that does not exist, leaving the file
  /// impossible to stage, diff or discard.
  static String _unquotePath(String path) {
    if (path.length < 2 || !path.startsWith('"') || !path.endsWith('"')) {
      return path;
    }

    final body = path.substring(1, path.length - 1);
    final buffer = StringBuffer();
    // Escapes carry raw bytes, so consecutive ones are buffered and decoded as
    // a group; a single non-ASCII character spans several of them.
    final pending = <int>[];

    void flushPending() {
      if (pending.isEmpty) return;
      buffer.write(utf8.decode(pending, allowMalformed: true));
      pending.clear();
    }

    for (var i = 0; i < body.length; i++) {
      final char = body[i];

      if (char != r'\' || i + 1 >= body.length) {
        flushPending();
        buffer.write(char);
        continue;
      }

      i++;
      final escape = body[i];
      final code = _escapeCodes[escape];
      if (code != null) {
        pending.add(code);
        continue;
      }

      // Octal byte escape (\303); the form git uses for every non-ASCII byte.
      final end = i + 3 <= body.length ? i + 3 : body.length;
      final octal = body.substring(i, end);
      final value = octal.length == 3 ? int.tryParse(octal, radix: 8) : null;
      if (value == null) {
        flushPending();
        buffer.write(escape);
        continue;
      }
      pending.add(value);
      i += 2;
    }

    flushPending();
    return buffer.toString();
  }

  /// Parse a single status character
  static FileStatusType _parseStatus(String code) {
    switch (code) {
      case 'M':
        return FileStatusType.modified;
      case 'A':
        return FileStatusType.added;
      case 'D':
        return FileStatusType.deleted;
      case 'R':
        return FileStatusType.renamed;
      case 'C':
        return FileStatusType.copied;
      case '?':
        return FileStatusType.untracked;
      case '!':
        return FileStatusType.ignored;
      case 'U':
        // Unmerged. Without this, the porcelain codes UU/AU/UA/DU/UD all decayed
        // to 'unchanged', so getMergeState() could never see a conflict.
        return FileStatusType.unmerged;
      case ' ':
      default:
        return FileStatusType.unchanged;
    }
  }
}
