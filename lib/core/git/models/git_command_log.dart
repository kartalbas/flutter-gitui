import '../../extensions/date_time_extensions.dart';

/// Model for a Git command log entry
class GitCommandLog {
  final String command;
  final DateTime timestamp;
  final String? output;
  final String? error;
  final int? exitCode;
  final Duration? duration;

  const GitCommandLog({
    required this.command,
    required this.timestamp,
    this.output,
    this.error,
    this.exitCode,
    this.duration,
  });

  /// Whether the command was successful
  bool get isSuccess => exitCode == 0;

  /// Whether the command failed
  bool get isFailure => exitCode != null && exitCode != 0;

  /// Get a formatted timestamp with millisecond precision
  String get formattedTime {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final second = timestamp.second.toString().padLeft(2, '0');
    final millisecond = timestamp.millisecond.toString().padLeft(3, '0');
    return '$hour:$minute:$second.$millisecond';
  }

  /// ISO 8601 formatted timestamp
  String get timestampIso => timestamp.toIso8601String();

  /// Display formatted timestamp (ISO + relative)
  /// Pass locale code (e.g., 'en', 'ar', 'de') for localized relative time
  String timestampDisplay([String? locale]) => timestamp.toDisplayString(locale);

  /// Get the full output (stdout + stderr)
  String get fullOutput {
    final parts = <String>[];
    if (output != null && output!.isNotEmpty) {
      parts.add(output!);
    }
    if (error != null && error!.isNotEmpty) {
      parts.add(error!);
    }
    return parts.join('\n');
  }

  /// Get a summary of the command (first line only)
  String get commandSummary {
    final lines = command.split('\n');
    if (lines.length > 1) {
      return '${lines.first}...';
    }
    return command;
  }

  @override
  String toString() {
    return 'GitCommandLog(command: $command, timestamp: $timestamp, exitCode: $exitCode)';
  }
}
