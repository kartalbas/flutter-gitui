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
      String newPath = path;

      if (indexCode == 'R' || workTreeCode == 'R') {
        final parts = path.split(' -> ');
        if (parts.length == 2) {
          oldPath = parts[0].trim();
          newPath = parts[1].trim();
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
      case ' ':
      default:
        return FileStatusType.unchanged;
    }
  }
}
