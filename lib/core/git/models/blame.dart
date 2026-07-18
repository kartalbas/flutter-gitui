import 'package:freezed_annotation/freezed_annotation.dart';

part 'blame.freezed.dart';

/// Represents a single line's blame information from git blame
@freezed
class BlameLine with _$BlameLine {
  const factory BlameLine({
    required int lineNumber,
    required String commitHash,
    required String author,
    required String authorEmail,
    required DateTime authorTime,
    required String summary,
    required String lineContent,
    String? filename,
  }) = _BlameLine;

  const BlameLine._();

  /// Get short commit hash (first 7 characters)
  String get shortHash => commitHash.substring(0, 7);

  /// Get author initials for avatar
  String get authorInitials {
    final parts = author.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return author.length >= 2 ? author.substring(0, 2).toUpperCase() : author.toUpperCase();
  }
}

/// Represents the complete blame information for a file
@freezed
class FileBlame with _$FileBlame {
  const factory FileBlame({
    required String filePath,
    required List<BlameLine> lines,
  }) = _FileBlame;

  const FileBlame._();

  /// Get unique authors in this file
  List<String> get uniqueAuthors {
    final authors = <String>{};
    for (final line in lines) {
      authors.add(line.author);
    }
    return authors.toList()..sort();
  }

  /// Get unique commits in this file
  List<String> get uniqueCommits {
    final commits = <String>{};
    for (final line in lines) {
      commits.add(line.commitHash);
    }
    return commits.toList();
  }

  /// Get lines by commit
  Map<String, List<BlameLine>> get linesByCommit {
    final map = <String, List<BlameLine>>{};
    for (final line in lines) {
      map.putIfAbsent(line.commitHash, () => []).add(line);
    }
    return map;
  }

  /// Get lines by author
  Map<String, List<BlameLine>> get linesByAuthor {
    final map = <String, List<BlameLine>>{};
    for (final line in lines) {
      map.putIfAbsent(line.author, () => []).add(line);
    }
    return map;
  }

  /// Get total number of lines
  int get totalLines => lines.length;
}
