import '../models/remote.dart';

/// Parser for git remote command output
class RemoteParser {
  /// Parse output from `git remote -v`
  ///
  /// Example output:
  /// ```
  /// origin  git@github.com:user/repo.git (fetch)
  /// origin  git@github.com:user/repo.git (push)
  /// upstream  https://github.com:other/repo.git (fetch)
  /// upstream  https://github.com:other/repo.git (push)
  /// ```
  static List<GitRemote> parseRemotes(String output) {
    if (output.trim().isEmpty) {
      return [];
    }

    final Map<String, Map<String, String>> remoteData = {};

    for (final line in output.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Parse: remote_name  url (type)
      final match = RegExp(r'^(\S+)\s+(\S+)\s+\((\w+)\)').firstMatch(trimmed);
      if (match == null) continue;

      final name = match.group(1)!;
      final url = match.group(2)!;
      final type = match.group(3)!; // fetch or push

      if (!remoteData.containsKey(name)) {
        remoteData[name] = {};
      }

      remoteData[name]![type] = url;
    }

    // Convert to GitRemote objects
    final List<GitRemote> remotes = [];
    for (final entry in remoteData.entries) {
      final name = entry.key;
      final urls = entry.value;

      final fetchUrl = urls['fetch'] ?? '';
      final pushUrl = urls['push'] ?? fetchUrl;

      if (fetchUrl.isNotEmpty) {
        remotes.add(GitRemote(
          name: name,
          fetchUrl: fetchUrl,
          pushUrl: pushUrl,
        ));
      }
    }

    return remotes;
  }

  /// Parse list of remote names from `git remote`
  ///
  /// Example output:
  /// ```
  /// origin
  /// upstream
  /// ```
  static List<String> parseRemoteNames(String output) {
    if (output.trim().isEmpty) {
      return [];
    }

    return output
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }
}
