/// Represents a Git remote repository
class GitRemote {
  /// Remote name (e.g., "origin", "upstream")
  final String name;

  /// Fetch URL
  final String fetchUrl;

  /// Push URL (can be different from fetch URL)
  final String pushUrl;

  const GitRemote({
    required this.name,
    required this.fetchUrl,
    required this.pushUrl,
  });

  /// Whether this remote is the default origin
  bool get isOrigin => name.toLowerCase() == 'origin';

  /// Whether fetch and push URLs are the same
  bool get hasSameUrls => fetchUrl == pushUrl;

  /// Get display URL (shows fetch URL, or both if different)
  String get displayUrl {
    if (hasSameUrls) {
      return fetchUrl;
    }
    return 'Fetch: $fetchUrl\nPush: $pushUrl';
  }

  /// Check if URL is SSH
  bool get isSsh => fetchUrl.startsWith('git@') || fetchUrl.startsWith('ssh://');

  /// Check if URL is HTTPS
  bool get isHttps => fetchUrl.startsWith('https://');

  /// Check if URL is local path
  bool get isLocal => !isSsh && !isHttps;

  /// Extract host from URL (e.g., "github.com", "gitlab.com")
  String? get host {
    if (isSsh) {
      // git@github.com:user/repo.git
      final match = RegExp(r'@([^:]+):').firstMatch(fetchUrl);
      return match?.group(1);
    } else if (isHttps) {
      // https://github.com/user/repo.git
      try {
        final uri = Uri.parse(fetchUrl);
        return uri.host;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Extract repository path (e.g., "user/repo")
  String? get repositoryPath {
    if (isSsh) {
      // git@github.com:user/repo.git
      final match = RegExp(r':(.+?)(\.git)?$').firstMatch(fetchUrl);
      return match?.group(1);
    } else if (isHttps) {
      // https://github.com/user/repo.git
      try {
        final uri = Uri.parse(fetchUrl);
        var path = uri.path;
        if (path.startsWith('/')) path = path.substring(1);
        if (path.endsWith('.git')) path = path.substring(0, path.length - 4);
        return path;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitRemote &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          fetchUrl == other.fetchUrl &&
          pushUrl == other.pushUrl;

  @override
  int get hashCode => Object.hash(name, fetchUrl, pushUrl);

  @override
  String toString() => 'GitRemote(name: $name, fetch: $fetchUrl, push: $pushUrl)';
}
