import '../../../core/git/models/tag.dart';
import '../dialogs/advanced_filters_dialog.dart' show DateRangeFilter;
import '../tags_screen.dart' show TagFilterType, TagSortBy, TagGroupBy;

/// Service class for tag-related business logic
/// Handles filtering, sorting, grouping, and searching tags
class TagsService {
  const TagsService();

  /// Filter tags based on filter criteria
  List<GitTag> filterTags({
    required List<GitTag> tags,
    required TagFilterType filterType,
    String searchQuery = '',
    bool useRegex = false,
    DateRangeFilter dateFilter = DateRangeFilter.all,
    DateTime? customDateStart,
    DateTime? customDateEnd,
    String? authorFilter,
  }) {
    return tags.where((tag) {
      // Apply type filter
      if (filterType == TagFilterType.annotated && !tag.isAnnotated) {
        return false;
      }
      if (filterType == TagFilterType.lightweight && !tag.isLightweight) {
        return false;
      }

      // Apply date filter
      if (dateFilter != DateRangeFilter.all && tag.date != null) {
        final now = DateTime.now();
        switch (dateFilter) {
          case DateRangeFilter.today:
            if (!_isSameDay(tag.date!, now)) return false;
            break;
          case DateRangeFilter.lastWeek:
            if (now.difference(tag.date!).inDays > 7) return false;
            break;
          case DateRangeFilter.lastMonth:
            if (now.difference(tag.date!).inDays > 30) return false;
            break;
          case DateRangeFilter.lastYear:
            if (now.difference(tag.date!).inDays > 365) return false;
            break;
          case DateRangeFilter.custom:
            if (customDateStart != null && tag.date!.isBefore(customDateStart)) {
              return false;
            }
            if (customDateEnd != null && tag.date!.isAfter(customDateEnd)) {
              return false;
            }
            break;
          case DateRangeFilter.all:
            break;
        }
      } else if (dateFilter != DateRangeFilter.all) {
        // If we're filtering by date but tag has no date, exclude it
        return false;
      }

      // Apply author filter
      if (authorFilter != null && authorFilter.isNotEmpty) {
        if (tag.taggerName == null ||
            !tag.taggerName!.toLowerCase().contains(authorFilter.toLowerCase())) {
          return false;
        }
      }

      // Apply search filter
      if (searchQuery.isEmpty) return true;

      if (useRegex) {
        try {
          final regex = RegExp(searchQuery, caseSensitive: false);
          return regex.hasMatch(tag.name) ||
                 regex.hasMatch(tag.displayMessage) ||
                 regex.hasMatch(tag.commitHash);
        } catch (e) {
          // If regex is invalid, fall back to normal search
          final query = searchQuery.toLowerCase();
          return tag.name.toLowerCase().contains(query) ||
                 tag.displayMessage.toLowerCase().contains(query) ||
                 tag.commitHash.toLowerCase().contains(query);
        }
      } else {
        final query = searchQuery.toLowerCase();
        return tag.name.toLowerCase().contains(query) ||
               tag.displayMessage.toLowerCase().contains(query) ||
               tag.commitHash.toLowerCase().contains(query);
      }
    }).toList();
  }

  /// Sort tags based on sort criteria
  List<GitTag> sortTags({
    required List<GitTag> tags,
    required TagSortBy sortBy,
  }) {
    final sorted = List<GitTag>.from(tags);
    sorted.sort((a, b) {
      switch (sortBy) {
        case TagSortBy.nameAsc:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case TagSortBy.nameDesc:
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        case TagSortBy.dateNewest:
          if (a.date == null && b.date == null) return 0;
          if (a.date == null) return 1;
          if (b.date == null) return -1;
          return b.date!.compareTo(a.date!);
        case TagSortBy.dateOldest:
          if (a.date == null && b.date == null) return 0;
          if (a.date == null) return 1;
          if (b.date == null) return -1;
          return a.date!.compareTo(b.date!);
        case TagSortBy.versionAsc:
          return compareVersions(a.name, b.name);
        case TagSortBy.versionDesc:
          return compareVersions(b.name, a.name);
      }
    });
    return sorted;
  }

  /// Group tags based on grouping criteria
  Map<String, List<GitTag>> groupTags({
    required List<GitTag> tags,
    required TagGroupBy groupBy,
  }) {
    if (groupBy == TagGroupBy.none) {
      return {'All Tags': tags};
    }

    final Map<String, List<GitTag>> grouped = {};

    for (final tag in tags) {
      String groupKey;

      switch (groupBy) {
        case TagGroupBy.none:
          groupKey = 'All Tags';
          break;
        case TagGroupBy.prefix:
          groupKey = extractPrefix(tag.name);
          break;
        case TagGroupBy.version:
          groupKey = extractVersionGroup(tag.name);
          break;
        case TagGroupBy.author:
          groupKey = tag.displayTagger ?? 'Unknown';
          break;
        case TagGroupBy.date:
          if (tag.date == null) {
            groupKey = 'No Date';
          } else {
            groupKey = getDateGroupLabel(tag.date!);
          }
          break;
      }

      grouped.putIfAbsent(groupKey, () => []);
      grouped[groupKey]!.add(tag);
    }

    // Sort group keys
    final sortedKeys = grouped.keys.toList()..sort();
    return Map.fromEntries(
      sortedKeys.map((key) => MapEntry(key, grouped[key]!)),
    );
  }

  /// Compare two tag names as semantic versions
  /// Handles standard semantic versioning (v1.2.3, 1.2.3)
  int compareVersions(String a, String b) {
    final aVersion = extractVersion(a);
    final bVersion = extractVersion(b);

    if (aVersion == null && bVersion == null) {
      return a.toLowerCase().compareTo(b.toLowerCase());
    }
    if (aVersion == null) return 1;
    if (bVersion == null) return -1;

    // Compare major, minor, patch
    for (int i = 0; i < 3; i++) {
      final aNum = i < aVersion.length ? aVersion[i] : 0;
      final bNum = i < bVersion.length ? bVersion[i] : 0;
      if (aNum != bNum) {
        return aNum.compareTo(bNum);
      }
    }

    return 0;
  }

  /// Extract version numbers from a tag name (e.g., "v1.2.3" -> [1, 2, 3])
  List<int>? extractVersion(String tagName) {
    // Remove 'v' or 'V' prefix if present
    String cleaned = tagName.replaceFirst(RegExp(r'^[vV]'), '');

    // Try to extract semantic version pattern
    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)').firstMatch(cleaned);
    if (match != null) {
      return [
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      ];
    }

    // Try to extract major.minor pattern
    final match2 = RegExp(r'^(\d+)\.(\d+)').firstMatch(cleaned);
    if (match2 != null) {
      return [
        int.parse(match2.group(1)!),
        int.parse(match2.group(2)!),
        0,
      ];
    }

    // Try to extract single number
    final match3 = RegExp(r'^(\d+)').firstMatch(cleaned);
    if (match3 != null) {
      return [
        int.parse(match3.group(1)!),
        0,
        0,
      ];
    }

    return null;
  }

  /// Extract prefix from tag name (e.g., "v1.2.3" -> "v1", "release/1.0" -> "release")
  String extractPrefix(String tagName) {
    // Try semantic version pattern first
    final versionMatch = RegExp(r'^v?(\d+)').firstMatch(tagName);
    if (versionMatch != null) {
      return 'v${versionMatch.group(1)}';
    }

    // Try slash-separated prefix
    if (tagName.contains('/')) {
      return tagName.split('/').first;
    }

    // Try hyphen or underscore separated
    if (tagName.contains('-') || tagName.contains('_')) {
      final separator = tagName.contains('-') ? '-' : '_';
      return tagName.split(separator).first;
    }

    // Default: first word or "Other"
    return tagName.split(RegExp(r'[^a-zA-Z0-9]')).first.isEmpty
        ? 'Other'
        : tagName.split(RegExp(r'[^a-zA-Z0-9]')).first;
  }

  /// Extract version group (major.minor pattern)
  String extractVersionGroup(String tagName) {
    final versionMatch = RegExp(r'v?(\d+)\.(\d+)').firstMatch(tagName);
    if (versionMatch != null) {
      return 'v${versionMatch.group(1)}.${versionMatch.group(2)}.x';
    }

    final majorMatch = RegExp(r'v?(\d+)').firstMatch(tagName);
    if (majorMatch != null) {
      return 'v${majorMatch.group(1)}.x';
    }

    return 'Non-versioned';
  }

  /// Get date group label for grouping by date
  String getDateGroupLabel(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays <= 7) {
      return 'This Week';
    } else if (difference.inDays <= 30) {
      return 'This Month';
    } else if (difference.inDays <= 365) {
      return 'This Year';
    } else {
      final years = (difference.inDays / 365).floor();
      return years == 1 ? '1 Year Ago' : '$years Years Ago';
    }
  }

  /// Get human-readable label for date filter
  String getDateFilterLabel(DateRangeFilter filter) {
    switch (filter) {
      case DateRangeFilter.today:
        return 'Today';
      case DateRangeFilter.lastWeek:
        return 'Last Week';
      case DateRangeFilter.lastMonth:
        return 'Last Month';
      case DateRangeFilter.lastYear:
        return 'Last Year';
      case DateRangeFilter.custom:
        return 'Custom Range';
      case DateRangeFilter.all:
        return 'All Time';
    }
  }

  /// Check if two dates are the same day
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
