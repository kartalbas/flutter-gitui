import 'package:equatable/equatable.dart';

/// Search filter for commit history
class HistorySearchFilter extends Equatable {
  final String? query; // General search query
  final String? author; // Filter by author name/email
  final String? committer; // Filter by committer name/email
  final String? filePath; // Filter by file path
  final DateTime? fromDate; // Start date
  final DateTime? toDate; // End date
  final List<String>? hashPrefixes; // Filter by commit hash prefix
  final bool caseSensitive; // Case sensitive search
  final bool useRegex; // Use regex matching
  final bool fuzzyMatch; // Use fuzzy matching
  final String? branch; // Filter by branch
  final List<String>? tags; // Filter by tags

  const HistorySearchFilter({
    this.query,
    this.author,
    this.committer,
    this.filePath,
    this.fromDate,
    this.toDate,
    this.hashPrefixes,
    this.caseSensitive = false,
    this.useRegex = false,
    this.fuzzyMatch = true,
    this.branch,
    this.tags,
  });

  /// Empty filter (no filtering)
  const HistorySearchFilter.empty()
      : query = null,
        author = null,
        committer = null,
        filePath = null,
        fromDate = null,
        toDate = null,
        hashPrefixes = null,
        caseSensitive = false,
        useRegex = false,
        fuzzyMatch = true,
        branch = null,
        tags = null;

  /// Quick filter: commits from today
  factory HistorySearchFilter.today() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return HistorySearchFilter(
      fromDate: startOfDay,
      toDate: now,
    );
  }

  /// Quick filter: commits from this week
  factory HistorySearchFilter.thisWeek() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    return HistorySearchFilter(
      fromDate: startOfDay,
      toDate: now,
    );
  }

  /// Quick filter: commits from this month
  factory HistorySearchFilter.thisMonth() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    return HistorySearchFilter(
      fromDate: startOfMonth,
      toDate: now,
    );
  }

  /// Quick filter: commits from last 30 days
  factory HistorySearchFilter.last30Days() {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    return HistorySearchFilter(
      fromDate: thirtyDaysAgo,
      toDate: now,
    );
  }

  /// Check if filter is empty (no filtering applied)
  bool get isEmpty =>
      query == null &&
      author == null &&
      committer == null &&
      filePath == null &&
      fromDate == null &&
      toDate == null &&
      (hashPrefixes == null || hashPrefixes!.isEmpty) &&
      branch == null &&
      (tags == null || tags!.isEmpty);

  /// Check if filter has any criteria
  bool get isNotEmpty => !isEmpty;

  /// Count of active filters
  int get activeFilterCount {
    int count = 0;
    if (query != null && query!.isNotEmpty) count++;
    if (author != null && author!.isNotEmpty) count++;
    if (committer != null && committer!.isNotEmpty) count++;
    if (filePath != null && filePath!.isNotEmpty) count++;
    if (fromDate != null) count++;
    if (toDate != null) count++;
    if (hashPrefixes != null && hashPrefixes!.isNotEmpty) count++;
    if (branch != null && branch!.isNotEmpty) count++;
    if (tags != null && tags!.isNotEmpty) count++;
    return count;
  }

  HistorySearchFilter copyWith({
    String? query,
    String? author,
    String? committer,
    String? filePath,
    DateTime? fromDate,
    DateTime? toDate,
    List<String>? hashPrefixes,
    bool? caseSensitive,
    bool? useRegex,
    bool? fuzzyMatch,
    String? branch,
    List<String>? tags,
  }) {
    return HistorySearchFilter(
      query: query ?? this.query,
      author: author ?? this.author,
      committer: committer ?? this.committer,
      filePath: filePath ?? this.filePath,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      hashPrefixes: hashPrefixes ?? this.hashPrefixes,
      caseSensitive: caseSensitive ?? this.caseSensitive,
      useRegex: useRegex ?? this.useRegex,
      fuzzyMatch: fuzzyMatch ?? this.fuzzyMatch,
      branch: branch ?? this.branch,
      tags: tags ?? this.tags,
    );
  }

  @override
  List<Object?> get props => [
        query,
        author,
        committer,
        filePath,
        fromDate,
        toDate,
        hashPrefixes,
        caseSensitive,
        useRegex,
        fuzzyMatch,
        branch,
        tags,
      ];
}
