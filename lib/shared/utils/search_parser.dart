/// Search modes for file tree searching
enum SearchMode {
  /// Simple case-insensitive substring match
  simple,

  /// Glob pattern matching with wildcards
  /// Supports: * (any chars), ? (single char), path/patterns
  glob,

  /// Regular expression matching
  regex,
}

/// Utility for parsing and matching search queries based on mode
class SearchParser {
  final String query;
  final SearchMode mode;

  // Cached regex for performance
  RegExp? _cachedRegex;
  String? _cachedPattern;

  SearchParser({
    required this.query,
    required this.mode,
  });

  /// Check if a file/folder name matches the search query
  bool matches(String name, String fullPath) {
    if (query.isEmpty) return true;

    switch (mode) {
      case SearchMode.simple:
        return _matchSimple(name);
      case SearchMode.glob:
        return _matchGlob(name, fullPath);
      case SearchMode.regex:
        return _matchRegex(name, fullPath);
    }
  }

  /// Simple case-insensitive substring match
  bool _matchSimple(String name) {
    return name.toLowerCase().contains(query.toLowerCase());
  }

  /// Glob pattern matching
  /// Supports:
  /// - * matches any characters
  /// - ? matches single character
  /// - path/pattern matches in path
  bool _matchGlob(String name, String fullPath) {
    final lowerQuery = query.toLowerCase();
    final lowerName = name.toLowerCase();
    final lowerPath = fullPath.toLowerCase().replaceAll('\\', '/');

    // Check if query contains path separator
    if (lowerQuery.contains('/')) {
      // Match against full path
      return _globToRegex(lowerQuery).hasMatch(lowerPath);
    } else {
      // Match against name only
      return _globToRegex(lowerQuery).hasMatch(lowerName);
    }
  }

  /// Convert glob pattern to regex
  RegExp _globToRegex(String pattern) {
    if (_cachedPattern == pattern && _cachedRegex != null) {
      return _cachedRegex!;
    }

    // Escape regex special chars except * and ?
    String regexPattern = pattern
        .replaceAll(r'\', r'\\')
        .replaceAll('.', r'\.')
        .replaceAll('^', r'\^')
        .replaceAll(r'$', r'\$')
        .replaceAll('+', r'\+')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)')
        .replaceAll('[', r'\[')
        .replaceAll(']', r'\]')
        .replaceAll('{', r'\{')
        .replaceAll('}', r'\}')
        .replaceAll('|', r'\|');

    // Convert glob wildcards to regex
    regexPattern = regexPattern
        .replaceAll('*', '.*')
        .replaceAll('?', '.');

    _cachedPattern = pattern;
    _cachedRegex = RegExp(regexPattern, caseSensitive: false);
    return _cachedRegex!;
  }

  /// Regular expression matching
  bool _matchRegex(String name, String fullPath) {
    try {
      if (_cachedPattern != query) {
        _cachedPattern = query;
        _cachedRegex = RegExp(query, caseSensitive: false);
      }

      final regex = _cachedRegex!;

      // Try matching both name and full path
      return regex.hasMatch(name) ||
          regex.hasMatch(fullPath.replaceAll('\\', '/'));
    } catch (e) {
      // Invalid regex - fall back to simple match
      return name.toLowerCase().contains(query.toLowerCase());
    }
  }

  /// Get help text for current mode
  static String getHelpText(SearchMode mode) {
    switch (mode) {
      case SearchMode.simple:
        return 'Type to search (case-insensitive)';
      case SearchMode.glob:
        return 'Examples: *.json, *ABN*/config, test?.txt';
      case SearchMode.regex:
        return 'Examples: \\.json\$, ABN.*config, ^test';
    }
  }

  /// Get icon name for mode
  static String getIconName(SearchMode mode) {
    switch (mode) {
      case SearchMode.simple:
        return 'Aa';
      case SearchMode.glob:
        return '*';
      case SearchMode.regex:
        return '.*';
    }
  }
}
