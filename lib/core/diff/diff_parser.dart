/// Model for a line in a diff
class DiffLine {
  final int? oldLineNumber;
  final int? newLineNumber;
  final String content;
  final DiffLineType type;

  const DiffLine({
    this.oldLineNumber,
    this.newLineNumber,
    required this.content,
    required this.type,
  });
}

/// Type of diff line
enum DiffLineType {
  addition,    // + line
  deletion,    // - line
  context,     // unchanged line
  header,      // @@ line
  fileHeader,  // diff --git, ---, +++
  info,        // index, mode, etc.
}

/// Parser for unified diff format
class DiffParser {
  /// Parse git diff output into structured diff lines
  static List<DiffLine> parse(String diffOutput) {
    if (diffOutput.trim().isEmpty) {
      return [
        const DiffLine(
          content: 'No changes', // Displayed with l10n in UI
          type: DiffLineType.info,
        ),
      ];
    }

    final lines = <DiffLine>[];
    final inputLines = diffOutput.split('\n');

    int oldLineNum = 0;
    int newLineNum = 0;

    for (var line in inputLines) {
      // Remove carriage returns to prevent double line spacing
      line = line.replaceAll('\r', '');

      if (line.startsWith('diff --git')) {
        lines.add(DiffLine(content: line, type: DiffLineType.fileHeader));
      } else if (line.startsWith('index ') ||
                 line.startsWith('new file') ||
                 line.startsWith('deleted file') ||
                 line.startsWith('old mode') ||
                 line.startsWith('new mode')) {
        lines.add(DiffLine(content: line, type: DiffLineType.info));
      } else if (line.startsWith('---') || line.startsWith('+++')) {
        lines.add(DiffLine(content: line, type: DiffLineType.fileHeader));
      } else if (line.startsWith('@@')) {
        // Parse hunk header: @@ -10,7 +10,8 @@
        final match = RegExp(r'@@ -(\d+),?\d* \+(\d+),?\d* @@').firstMatch(line);
        if (match != null) {
          oldLineNum = int.parse(match.group(1)!);
          newLineNum = int.parse(match.group(2)!);
        }
        lines.add(DiffLine(content: line, type: DiffLineType.header));
      } else if (line.startsWith('+')) {
        lines.add(DiffLine(
          newLineNumber: newLineNum++,
          content: line,
          type: DiffLineType.addition,
        ));
      } else if (line.startsWith('-')) {
        lines.add(DiffLine(
          oldLineNumber: oldLineNum++,
          content: line,
          type: DiffLineType.deletion,
        ));
      } else if (line.startsWith(' ') || line.isEmpty) {
        lines.add(DiffLine(
          oldLineNumber: oldLineNum++,
          newLineNumber: newLineNum++,
          content: line,
          type: DiffLineType.context,
        ));
      } else {
        // Other lines (shouldn't happen in well-formed diff)
        lines.add(DiffLine(content: line, type: DiffLineType.info));
      }
    }

    return lines;
  }
}
