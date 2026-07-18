/// Extension methods for String
extension StringExtensions on String {
  /// Truncate string to max length with ellipsis
  String truncate(int maxLength, {String ellipsis = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}$ellipsis';
  }

  /// Get the first line of a string
  String get firstLine {
    final index = indexOf('\n');
    if (index == -1) return this;
    return substring(0, index);
  }

  /// Get all lines as a list
  List<String> get lines => split('\n');

  /// Check if string is empty or only whitespace
  bool get isBlank => trim().isEmpty;

  /// Check if string is not empty and not only whitespace
  bool get isNotBlank => trim().isNotEmpty;

  /// Capitalize first character
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Convert to title case
  String toTitleCase() {
    if (isEmpty) return this;
    return split(' ')
        .map((word) => word.isEmpty ? word : word.capitalize())
        .join(' ');
  }

  /// Remove extra whitespace
  String removeExtraWhitespace() {
    return replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Check if string contains only alphanumeric characters
  bool get isAlphanumeric => RegExp(r'^[a-zA-Z0-9]+$').hasMatch(this);

  /// Check if string is a valid email (basic check)
  bool get isValidEmail => RegExp(
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
      ).hasMatch(this);

  /// Indent each line with spaces
  String indent(int spaces) {
    final indentation = ' ' * spaces;
    return split('\n').map((line) => '$indentation$line').join('\n');
  }

  /// Wrap text to a maximum line length
  String wrap(int maxLength) {
    if (length <= maxLength) return this;

    final words = split(' ');
    final lines = <String>[];
    var currentLine = '';

    for (final word in words) {
      if (currentLine.isEmpty) {
        currentLine = word;
      } else if ('$currentLine $word'.length <= maxLength) {
        currentLine = '$currentLine $word';
      } else {
        lines.add(currentLine);
        currentLine = word;
      }
    }

    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }

    return lines.join('\n');
  }
}

/// Extension methods for nullable String
extension NullableStringExtensions on String? {
  /// Check if string is null or empty
  bool get isNullOrEmpty => this == null || this!.isEmpty;

  /// Check if string is null, empty, or only whitespace
  bool get isNullOrBlank => this == null || this!.isBlank;

  /// Get value or default if null
  String orDefault(String defaultValue) => this ?? defaultValue;

  /// Get value or empty string if null
  String get orEmpty => this ?? '';
}
