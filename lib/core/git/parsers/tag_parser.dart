import '../models/tag.dart';

/// Parser for git tag output
class TagParser {
  /// Parse git for-each-ref output for tags
  ///
  /// Expected format (|@|-delimited):
  /// name|@|commitHash|@|objectType|@|taggerName|@|taggerEmail|@|taggerDate|@|subject|@|commitMessage
  ///
  /// Example:
  /// v1.0.0|@|a1b2c3d4|@|tag|@|John Doe|@|`<john@example.com>`|@|1234567890|@|Release v1.0.0|@|
  /// v1.0.1|@|b2c3d4e5|@|commit|@||@||@||@||@|Quick fix
  static List<GitTag> parseTagList(String output) {
    if (output.trim().isEmpty) {
      return [];
    }

    final tags = <GitTag>[];
    final lines = output.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      try {
        final parts = trimmed.split('|@|');
        if (parts.length < 8) continue;

        final name = parts[0].trim();
        final commitHash = parts[1].trim();
        final objectType = parts[2].trim();
        final taggerName = parts[3].trim();
        final taggerEmail = parts[4].trim();
        final taggerDateStr = parts[5].trim();
        final subject = parts[6].trim();
        final commitMessage = parts[7].trim();

        // Skip if no name or commit hash
        if (name.isEmpty || commitHash.isEmpty) continue;

        // Determine tag type based on object type
        final type = objectType == 'tag' ? GitTagType.annotated : GitTagType.lightweight;

        // Parse tagger date
        DateTime? taggerDate;
        if (taggerDateStr.isNotEmpty) {
          try {
            final unixTimestamp = int.parse(taggerDateStr);
            taggerDate = DateTime.fromMillisecondsSinceEpoch(unixTimestamp * 1000);
          } catch (_) {
            // If timestamp parsing fails, continue without it
          }
        }

        // Use annotated tag subject, or commit subject for lightweight tags
        String? message;
        if (type == GitTagType.annotated && subject.isNotEmpty) {
          message = subject;
        } else if (commitMessage.isNotEmpty) {
          message = commitMessage;
        }

        tags.add(GitTag(
          name: name,
          commitHash: commitHash,
          type: type,
          message: message,
          taggerName: taggerName.isNotEmpty ? taggerName : null,
          taggerEmail: taggerEmail.isNotEmpty ? _cleanEmail(taggerEmail) : null,
          date: taggerDate,
          commitMessage: commitMessage.isNotEmpty ? commitMessage : null,
        ));
      } catch (e) {
        // Skip malformed lines
        continue;
      }
    }

    return tags;
  }

  /// Parse tag details from git show output
  ///
  /// For annotated tags, extracts:
  /// - Tag name
  /// - Tagger info
  /// - Date
  /// - Message
  /// - Commit info
  static Map<String, dynamic> parseTagDetails(String output) {
    final result = <String, dynamic>{
      'type': 'lightweight',
      'message': '',
      'tagger': '',
      'date': null,
      'commit': '',
    };

    if (output.trim().isEmpty) {
      return result;
    }

    final lines = output.split('\n');
    final messageLines = <String>[];
    bool inMessage = false;
    bool passedHeader = false;

    for (final line in lines) {
      if (line.startsWith('tag ')) {
        result['type'] = 'annotated';
      } else if (line.startsWith('Tagger: ')) {
        result['tagger'] = line.substring(8).trim();
      } else if (line.startsWith('Date: ')) {
        result['date'] = line.substring(6).trim();
      } else if (line.startsWith('commit ')) {
        result['commit'] = line.substring(7).trim();
        if (!passedHeader) {
          inMessage = false;
        }
      } else if (line.trim().isEmpty && result['type'] == 'annotated' && !passedHeader) {
        // Empty line after header starts message
        inMessage = true;
        passedHeader = true;
      } else if (inMessage && passedHeader) {
        messageLines.add(line);
      }
    }

    if (messageLines.isNotEmpty) {
      result['message'] = messageLines.join('\n').trim();
    }

    return result;
  }

  /// Clean email format (remove surrounding < >)
  static String _cleanEmail(String email) {
    if (email.startsWith('<') && email.endsWith('>')) {
      return email.substring(1, email.length - 1);
    }
    return email;
  }

  /// Parse simple tag list (just names)
  ///
  /// From: git tag -l
  static List<String> parseSimpleTagList(String output) {
    if (output.trim().isEmpty) {
      return [];
    }

    return output
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  /// Parse tag commit mapping
  ///
  /// From: git show-ref --tags
  /// Format: `<commit-hash>` refs/tags/`<tag-name>`
  static Map<String, String> parseTagCommitMapping(String output) {
    final mapping = <String, String>{};

    if (output.trim().isEmpty) {
      return mapping;
    }

    final lines = output.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final parts = trimmed.split(' ');
      if (parts.length != 2) continue;

      final commitHash = parts[0];
      final ref = parts[1];

      // Extract tag name from refs/tags/<name>
      if (ref.startsWith('refs/tags/')) {
        final tagName = ref.substring('refs/tags/'.length);
        mapping[tagName] = commitHash;
      }
    }

    return mapping;
  }
}
