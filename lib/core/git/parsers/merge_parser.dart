import '../models/merge_conflict.dart';

/// Parser for Git merge-related output
class MergeParser {
  /// Parse merge conflicts from git status output
  ///
  /// Expects porcelain v1 format with conflict markers:
  /// UU file.txt (both modified)
  /// DD file.txt (both deleted)
  /// AU file.txt (added by us)
  /// UA file.txt (added by them)
  /// DU file.txt (deleted by us)
  /// UD file.txt (deleted by them)
  /// AA file.txt (both added)
  static List<MergeConflict> parseConflictsFromStatus(String output) {
    final conflicts = <MergeConflict>[];
    final lines = output.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Parse porcelain format: XY file
      if (trimmed.length < 4) continue;

      final statusCode = trimmed.substring(0, 2);
      final filePath = trimmed.substring(3).trim();

      ConflictType? type;

      switch (statusCode) {
        case 'UU': // Both modified
          type = ConflictType.bothModified;
          break;
        case 'AA': // Both added
          type = ConflictType.bothAdded;
          break;
        case 'DD': // Both deleted (rare, but possible)
          // We'll skip these as they don't need resolution
          continue;
        case 'AU': // Added by us
          type = ConflictType.addedByUs;
          break;
        case 'UA': // Added by them
          type = ConflictType.addedByThem;
          break;
        case 'DU': // Deleted by us
          type = ConflictType.deletedByUs;
          break;
        case 'UD': // Deleted by them
          type = ConflictType.deletedByThem;
          break;
        default:
          continue; // Not a conflict
      }

      conflicts.add(MergeConflict(
        filePath: filePath,
        type: type,
      ));
    }

    return conflicts;
  }

  /// Extract conflict markers content from a file
  ///
  /// Returns a map with 'ours', 'theirs', and 'base' sections
  static Map<String, String> parseConflictMarkers(String fileContent) {
    final result = <String, String>{
      'ours': '',
      'theirs': '',
      'base': '',
    };

    final lines = fileContent.split('\n');
    String? currentSection;
    final oursLines = <String>[];
    final theirsLines = <String>[];
    final baseLines = <String>[];

    for (final line in lines) {
      if (line.startsWith('<<<<<<<')) {
        // Start of conflict - ours section
        currentSection = 'ours';
        continue;
      } else if (line.startsWith('|||||||')) {
        // Base section (if diff3 style)
        currentSection = 'base';
        continue;
      } else if (line.startsWith('=======')) {
        // Switch to theirs section
        currentSection = 'theirs';
        continue;
      } else if (line.startsWith('>>>>>>>')) {
        // End of conflict
        currentSection = null;
        continue;
      }

      // Add line to appropriate section
      if (currentSection == 'ours') {
        oursLines.add(line);
      } else if (currentSection == 'theirs') {
        theirsLines.add(line);
      } else if (currentSection == 'base') {
        baseLines.add(line);
      }
    }

    result['ours'] = oursLines.join('\n');
    result['theirs'] = theirsLines.join('\n');
    result['base'] = baseLines.join('\n');

    return result;
  }

  /// Check if file has unresolved conflict markers
  static bool hasConflictMarkers(String fileContent) {
    return fileContent.contains('<<<<<<<') &&
        fileContent.contains('=======') &&
        fileContent.contains('>>>>>>>');
  }

  /// Parse MERGE_HEAD to get merging branch info
  static String? parseMergeHead(String? mergeHeadContent) {
    if (mergeHeadContent == null || mergeHeadContent.isEmpty) {
      return null;
    }

    // MERGE_HEAD contains the commit hash being merged
    // We can't get the branch name directly from this file
    // The branch name would need to come from MERGE_MSG or git status
    return mergeHeadContent.trim();
  }

  /// Parse MERGE_MSG to get merge message and branch info
  static Map<String, String?> parseMergeMsg(String? mergeMsgContent) {
    if (mergeMsgContent == null || mergeMsgContent.isEmpty) {
      return {'message': null, 'branch': null};
    }

    final lines = mergeMsgContent.split('\n');
    final message = lines.first.trim();

    // Try to extract branch name from message
    // Format is usually: "Merge branch 'branch-name' into current-branch"
    String? branch;
    final branchMatch = RegExp(r"Merge branch '([^']+)'").firstMatch(message);
    if (branchMatch != null) {
      branch = branchMatch.group(1);
    } else {
      // Try alternative format: "Merge remote-tracking branch 'origin/branch'"
      final remoteBranchMatch =
          RegExp(r"Merge remote-tracking branch '([^']+)'").firstMatch(message);
      if (remoteBranchMatch != null) {
        branch = remoteBranchMatch.group(1);
      }
    }

    return {
      'message': message,
      'branch': branch,
    };
  }

  /// Get clean content without conflict markers
  ///
  /// Removes all conflict markers and their content
  static String removeConflictMarkers(String fileContent) {
    final lines = fileContent.split('\n');
    final cleanLines = <String>[];
    bool inConflict = false;

    for (final line in lines) {
      if (line.startsWith('<<<<<<<')) {
        inConflict = true;
        continue;
      } else if (line.startsWith('>>>>>>>')) {
        inConflict = false;
        continue;
      } else if (line.startsWith('=======') || line.startsWith('|||||||')) {
        continue;
      }

      if (!inConflict) {
        cleanLines.add(line);
      }
    }

    return cleanLines.join('\n');
  }

  /// Count conflicts in a file
  static int countConflicts(String fileContent) {
    int count = 0;
    final lines = fileContent.split('\n');

    for (final line in lines) {
      if (line.startsWith('<<<<<<<')) {
        count++;
      }
    }

    return count;
  }

  /// Extract conflict sections for display
  ///
  /// Returns a list of conflict sections with line numbers
  static List<Map<String, dynamic>> extractConflictSections(String fileContent) {
    final sections = <Map<String, dynamic>>[];
    final lines = fileContent.split('\n');

    int? conflictStart;
    int? baseStart;
    int? theirsStart;
    final oursLines = <String>[];
    final baseLines = <String>[];
    final theirsLines = <String>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.startsWith('<<<<<<<')) {
        conflictStart = i;
        oursLines.clear();
        baseLines.clear();
        theirsLines.clear();
        baseStart = null;
        theirsStart = null;
        continue;
      } else if (line.startsWith('|||||||')) {
        baseStart = i;
        continue;
      } else if (line.startsWith('=======')) {
        theirsStart = i;
        continue;
      } else if (line.startsWith('>>>>>>>')) {
        if (conflictStart != null) {
          sections.add({
            'startLine': conflictStart + 1,
            'endLine': i + 1,
            'ours': oursLines.join('\n'),
            'base': baseLines.isNotEmpty ? baseLines.join('\n') : null,
            'theirs': theirsLines.join('\n'),
            'hasBase': baseStart != null,
          });
        }
        conflictStart = null;
        continue;
      }

      // Add line to appropriate section
      if (conflictStart != null) {
        if (theirsStart != null) {
          theirsLines.add(line);
        } else if (baseStart != null) {
          baseLines.add(line);
        } else {
          oursLines.add(line);
        }
      }
    }

    return sections;
  }
}
