import '../../../core/git/models/commit.dart';
import '../../../shared/utils/fuzzy_match.dart';
import '../models/history_search_filter.dart';

/// Service for searching and filtering commit history
class HistorySearchService {
  /// Minimum fuzzy match score (0-100)
  static const int fuzzyMatchThreshold = 60;

  /// Filter commits based on search criteria
  List<GitCommit> filterCommits(
    List<GitCommit> commits,
    HistorySearchFilter filter,
  ) {
    if (filter.isEmpty) return commits;

    return commits.where((commit) {
      // Date range filtering
      if (filter.fromDate != null &&
          commit.authorDate.isBefore(filter.fromDate!)) {
        return false;
      }
      if (filter.toDate != null && commit.authorDate.isAfter(filter.toDate!)) {
        return false;
      }

      // Author filtering
      if (filter.author != null && filter.author!.isNotEmpty) {
        if (!_matchesText(
          commit.author,
          filter.author!,
          filter.caseSensitive,
          filter.useRegex,
          filter.fuzzyMatch,
        )) {
          return false;
        }
      }

      // Committer filtering
      if (filter.committer != null && filter.committer!.isNotEmpty) {
        if (!_matchesText(
          commit.author, // Using author as committer for now
          filter.committer!,
          filter.caseSensitive,
          filter.useRegex,
          filter.fuzzyMatch,
        )) {
          return false;
        }
      }

      // Hash prefix filtering
      if (filter.hashPrefixes != null && filter.hashPrefixes!.isNotEmpty) {
        final matches = filter.hashPrefixes!.any(
          (prefix) =>
              commit.hash.toLowerCase().startsWith(prefix.toLowerCase()),
        );
        if (!matches) {
          return false;
        }
      }

      // General query filtering (searches in message, author, hash)
      if (filter.query != null && filter.query!.isNotEmpty) {
        final query = filter.query!;
        final matchesMessage = _matchesText(
          commit.message,
          query,
          filter.caseSensitive,
          filter.useRegex,
          filter.fuzzyMatch,
        );
        final matchesAuthor = _matchesText(
          commit.author,
          query,
          filter.caseSensitive,
          filter.useRegex,
          filter.fuzzyMatch,
        );
        final matchesHash = commit.hash.toLowerCase().contains(
          query.toLowerCase(),
        );

        if (!matchesMessage && !matchesAuthor && !matchesHash) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Check if text matches the search criteria
  bool _matchesText(
    String text,
    String search,
    bool caseSensitive,
    bool useRegex,
    bool fuzzyMatch,
  ) {
    if (useRegex) {
      try {
        final regex = RegExp(search, caseSensitive: caseSensitive);
        return regex.hasMatch(text);
      } catch (e) {
        // Invalid regex, fall back to simple matching
        return _simpleMatch(text, search, caseSensitive);
      }
    } else if (fuzzyMatch) {
      return _fuzzyMatch(text, search, caseSensitive);
    } else {
      return _simpleMatch(text, search, caseSensitive);
    }
  }

  /// Simple text matching
  bool _simpleMatch(String text, String search, bool caseSensitive) {
    if (caseSensitive) {
      return text.contains(search);
    } else {
      return text.toLowerCase().contains(search.toLowerCase());
    }
  }

  /// Fuzzy text matching
  bool _fuzzyMatch(String text, String search, bool caseSensitive) {
    final normalizedText = caseSensitive ? text : text.toLowerCase();
    final normalizedSearch = caseSensitive ? search : search.toLowerCase();

    // Score against the closest-fitting stretch of the text, so a query
    // buried in a long commit message counts as well as one standing alone.
    final score = partialMatchScore(
      normalizedText,
      normalizedSearch,
      minScore: fuzzyMatchThreshold,
    );
    return score > 0;
  }

  /// Parse search query with advanced syntax
  /// Supports: author:name, date:YYYY-MM-DD, hash:abc123, etc.
  HistorySearchFilter parseQuery(String query) {
    if (query.isEmpty) {
      return const HistorySearchFilter.empty();
    }

    String? generalQuery;
    String? author;
    String? filePath;
    DateTime? fromDate;
    DateTime? toDate;
    List<String>? hashPrefixes;
    List<String>? tags;

    // Parse query tokens
    final tokens = _tokenizeQuery(query);

    for (final token in tokens) {
      if (token.contains(':')) {
        final parts = token.split(':');
        if (parts.length != 2) continue;

        final key = parts[0].toLowerCase();
        final value = parts[1];

        switch (key) {
          case 'author':
          case 'a':
            author = value;
            break;
          case 'file':
          case 'f':
            filePath = value;
            break;
          case 'hash':
          case 'h':
            hashPrefixes ??= [];
            hashPrefixes.add(value);
            break;
          case 'tag':
            tags ??= [];
            tags.add(value);
            break;
          case 'from':
          case 'after':
            fromDate = _parseDate(value);
            break;
          case 'to':
          case 'before':
            toDate = _parseDate(value);
            break;
          case 'date':
          case 'd':
            final date = _parseDate(value);
            if (date != null) {
              fromDate = DateTime(date.year, date.month, date.day);
              toDate = DateTime(date.year, date.month, date.day, 23, 59, 59);
            }
            break;
        }
      } else {
        // General query term
        generalQuery = generalQuery == null ? token : '$generalQuery $token';
      }
    }

    return HistorySearchFilter(
      query: generalQuery,
      author: author,
      filePath: filePath,
      fromDate: fromDate,
      toDate: toDate,
      hashPrefixes: hashPrefixes,
      tags: tags,
    );
  }

  /// Tokenize search query (handles quoted strings)
  List<String> _tokenizeQuery(String query) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < query.length; i++) {
      final char = query[i];

      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ' ' && !inQuotes) {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
      } else {
        buffer.write(char);
      }
    }

    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString());
    }

    return tokens;
  }

  /// Parse date from string (supports various formats)
  DateTime? _parseDate(String dateStr) {
    try {
      // Try ISO format first (YYYY-MM-DD)
      if (dateStr.contains('-')) {
        return DateTime.parse(dateStr);
      }

      // Try relative dates
      final now = DateTime.now();
      switch (dateStr.toLowerCase()) {
        case 'today':
          return DateTime(now.year, now.month, now.day);
        case 'yesterday':
          final yesterday = now.subtract(const Duration(days: 1));
          return DateTime(yesterday.year, yesterday.month, yesterday.day);
        case 'week':
        case 'thisweek':
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          return DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        case 'month':
        case 'thismonth':
          return DateTime(now.year, now.month, 1);
        default:
          return null;
      }
    } catch (e) {
      return null;
    }
  }
}
