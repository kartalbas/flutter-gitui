import 'package:timeago/timeago.dart' as timeago;

/// Extension methods for DateTime
extension DateTimeExtensions on DateTime {
  /// Format as ISO 8601 string with full date and time (e.g., "2024-01-15T14:30:45")
  String toIso8601String() {
    final year = this.year.toString().padLeft(4, '0');
    final month = this.month.toString().padLeft(2, '0');
    final day = this.day.toString().padLeft(2, '0');
    final hour = this.hour.toString().padLeft(2, '0');
    final minute = this.minute.toString().padLeft(2, '0');
    final second = this.second.toString().padLeft(2, '0');
    return '$year-$month-${day}T$hour:$minute:$second';
  }

  /// Format as ISO date string (e.g., "2024-01-15")
  String toIsoDateString() {
    final year = this.year.toString().padLeft(4, '0');
    final month = this.month.toString().padLeft(2, '0');
    final day = this.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Format as ISO time string (e.g., "14:30:45")
  String toIsoTimeString() {
    final hour = this.hour.toString().padLeft(2, '0');
    final minute = this.minute.toString().padLeft(2, '0');
    final second = this.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  /// Format as display string with ISO date and relative time (e.g., "2024-01-15T14:30:45 (2 hours ago)")
  /// Pass locale code (e.g., 'en', 'ar', 'de') for localized relative time
  String toDisplayString([String? locale]) {
    return '${toIso8601String()} (${toRelativeTime(locale)})';
  }

  /// Format as relative time (e.g., "2 hours ago", "45 days ago")
  /// Uses timeago package which supports multiple languages
  /// Pass locale code (e.g., 'en', 'ar', 'de') for localized output
  String toRelativeTime([String? locale]) {
    return timeago.format(this, locale: locale ?? 'en');
  }

  /// Format as short date (e.g., "Jan 15, 2024")
  String toShortDateString() {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[month - 1]} $day, $year';
  }

  /// Format as short time (e.g., "3:45 PM")
  String toShortTimeString() {
    final period = hour < 12 ? 'AM' : 'PM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $period';
  }

  /// Check if date is today
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Check if date is yesterday
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }

  /// Check if date is within last week
  bool get isWithinLastWeek {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return isAfter(weekAgo) && isBefore(now);
  }

  /// Check if date is in the past
  bool get isPast => isBefore(DateTime.now());

  /// Check if date is in the future
  bool get isFuture => isAfter(DateTime.now());
}
