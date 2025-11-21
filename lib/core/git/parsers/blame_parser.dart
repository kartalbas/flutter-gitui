import '../models/blame.dart';

class BlameParser {
  /// Parse the output of `git blame --line-porcelain <file>`
  ///
  /// The porcelain format provides one line per source line with detailed metadata.
  /// Format:
  /// ```
  /// <commit-hash> <original-line> <final-line> <group-size>
  /// author <author-name>
  /// author-mail <author-email>
  /// author-time <timestamp>
  /// author-tz <timezone>
  /// committer <committer-name>
  /// committer-mail <committer-email>
  /// committer-time <timestamp>
  /// committer-tz <timezone>
  /// summary <commit-summary>
  /// filename <filename>
  ///  <line-content>
  /// ```
  static FileBlame parse(String output, String filePath) {
    final lines = <BlameLine>[];
    final rawLines = output.split('\n');

    String? commitHash;
    String? author;
    String? authorEmail;
    DateTime? authorTime;
    String? summary;
    String? filename;
    int? lineNumber;

    for (var i = 0; i < rawLines.length; i++) {
      final line = rawLines[i];

      if (line.isEmpty) continue;

      // First line of each block: <commit-hash> <original-line> <final-line> <group-size>
      if (!line.startsWith('\t') && !line.startsWith(' ') && !line.contains(' ')) {
        // This is a continuation of previous data, skip
        continue;
      }

      if (line.startsWith('\t')) {
        // This is the actual line content
        final lineContent = line.substring(1).replaceAll('\r', ''); // Remove leading tab and carriage returns

        if (commitHash != null &&
            author != null &&
            authorEmail != null &&
            authorTime != null &&
            summary != null &&
            lineNumber != null) {
          lines.add(
            BlameLine(
              lineNumber: lineNumber,
              commitHash: commitHash,
              author: author,
              authorEmail: authorEmail,
              authorTime: authorTime,
              summary: summary,
              lineContent: lineContent,
              filename: filename,
            ),
          );
        }

        // Reset for next line
        commitHash = null;
        author = null;
        authorEmail = null;
        authorTime = null;
        summary = null;
        filename = null;
        lineNumber = null;
        continue;
      }

      // Parse metadata lines
      if (line.contains(' ')) {
        final parts = line.split(' ');
        final key = parts[0];
        final value = parts.sublist(1).join(' ');

        switch (key) {
          case 'author':
            author = value;
            break;
          case 'author-mail':
            // Remove < and >
            authorEmail = value.replaceAll(RegExp(r'[<>]'), '');
            break;
          case 'author-time':
            final timestamp = int.tryParse(value);
            if (timestamp != null) {
              authorTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
            }
            break;
          case 'summary':
            summary = value;
            break;
          case 'filename':
            filename = value;
            break;
          default:
            // Check if this is the commit hash line
            if (commitHash == null && !line.contains(':')) {
              // Format: <commit-hash> <original-line> <final-line> <group-size>
              final hashParts = line.split(' ');
              if (hashParts.isNotEmpty) {
                commitHash = hashParts[0];
                if (hashParts.length >= 3) {
                  lineNumber = int.tryParse(hashParts[2]);
                }
              }
            }
        }
      }
    }

    return FileBlame(
      filePath: filePath,
      lines: lines,
    );
  }

  /// Parse the output of `git blame <file>` (non-porcelain format)
  ///
  /// Simpler format but less detailed:
  /// ```
  /// abc1234 (Author Name 2024-01-15 10:30:45 +0000 1) Line content
  /// ```
  static FileBlame parseSimple(String output, String filePath) {
    final lines = <BlameLine>[];
    final rawLines = output.split('\n');

    for (var i = 0; i < rawLines.length; i++) {
      final line = rawLines[i];
      if (line.isEmpty) continue;

      // Regular expression to parse: <hash> (<author> <date> <time> <tz> <line>) <content>
      final regex = RegExp(
        r'^([0-9a-f]+)\s+\((.+?)\s+(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2})\s+([+-]\d{4})\s+(\d+)\)\s*(.*)$',
      );
      final match = regex.firstMatch(line);

      if (match != null) {
        final commitHash = match.group(1)!;
        final author = match.group(2)!.trim();
        final date = match.group(3)!;
        final time = match.group(4)!;
        final lineNumber = int.parse(match.group(6)!);
        final lineContent = (match.group(7) ?? '').replaceAll('\r', ''); // Remove carriage returns

        final authorTime = DateTime.parse('$date $time');

        lines.add(
          BlameLine(
            lineNumber: lineNumber,
            commitHash: commitHash,
            author: author,
            authorEmail: '', // Not available in simple format
            authorTime: authorTime,
            summary: '', // Not available in simple format
            lineContent: lineContent,
          ),
        );
      }
    }

    return FileBlame(
      filePath: filePath,
      lines: lines,
    );
  }
}
