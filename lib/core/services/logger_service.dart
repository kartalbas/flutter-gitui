import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Logger service for application-wide logging
/// Replaces print statements with proper logging levels
/// Logs to both console (debugPrint) and file for debugging exe issues
class Logger {
  static const String _prefix = '[FlutterGitUI]';
  static File? _logFile;
  static File? _gitLogFile;
  static bool _initialized = false;

  // Queue to serialize file writes and prevent corruption
  static final List<String> _writeQueue = [];
  static final List<String> _gitWriteQueue = [];
  static bool _isWriting = false;
  static bool _isGitWriting = false;

  /// Get the path to the app.log file
  static String? get logFilePath => _logFile?.path;

  /// Get the path to the git.log file
  static String? get gitLogFilePath => _gitLogFile?.path;

  /// Initialize logger with file output
  static Future<void> init() async {
    if (_initialized) return;

    try {
      // Get user's home directory with proper fallback
      String home;
      if (Platform.isWindows) {
        // On Windows, always try USERPROFILE first
        home = Platform.environment['USERPROFILE'] ?? '';
        // If USERPROFILE is not set, use Documents folder
        if (home.isEmpty) {
          final docsDir = await getApplicationDocumentsDirectory();
          home = docsDir.parent.path; // Go up one level from Documents to user home
        }
      } else {
        // On Unix systems, use HOME
        home = Platform.environment['HOME'] ?? '';
        if (home.isEmpty) {
          final docsDir = await getApplicationDocumentsDirectory();
          home = docsDir.path;
        }
      }

      // Create log file in config directory
      final configDir = path.join(home, '.flutter-gitui');
      await Directory(configDir).create(recursive: true);

      final logPath = path.join(configDir, 'app.log');
      _logFile = File(logPath);

      // Clear old log on startup (keep file size manageable)
      if (await _logFile!.exists()) {
        final size = await _logFile!.length();
        // If log is over 1MB, clear it
        if (size > 1024 * 1024) {
          await _logFile!.writeAsString('');
        }
      }

      // Initialize git.log file
      final gitLogPath = path.join(configDir, 'git.log');
      _gitLogFile = File(gitLogPath);

      // Clear old git log on startup (keep file size manageable)
      if (await _gitLogFile!.exists()) {
        final size = await _gitLogFile!.length();
        // If log is over 5MB, clear it
        if (size > 5 * 1024 * 1024) {
          await _gitLogFile!.writeAsString('');
        }
      }

      _initialized = true;
      _writeToFile('[LOGGER] Logger initialized - log file: $logPath');
      _writeToGitFile('[LOGGER] Git logger initialized - log file: $gitLogPath');
    } catch (e) {
      // If we can't initialize file logging, continue with console only
      debugPrint('$_prefix Failed to initialize file logging: $e');
    }
  }

  /// Write message to log file (queued to prevent corruption)
  static void _writeToFile(String message) {
    if (_logFile == null) return;

    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $message\n';

    // Add to queue and process
    _writeQueue.add(logEntry);
    _processWriteQueue();
  }

  /// Process write queue sequentially to prevent file corruption
  static Future<void> _processWriteQueue() async {
    // If already processing, return (another call will handle it)
    if (_isWriting || _writeQueue.isEmpty) return;

    _isWriting = true;

    try {
      while (_writeQueue.isNotEmpty) {
        final entry = _writeQueue.removeAt(0);

        try {
          // Write synchronously to ensure atomic operation
          await _logFile!.writeAsString(
            entry,
            mode: FileMode.append,
            flush: true,
          );
        } catch (e) {
          // Silently ignore write errors
        }
      }
    } finally {
      _isWriting = false;
    }
  }

  /// Write message to git log file (queued to prevent corruption)
  static void _writeToGitFile(String message) {
    if (_gitLogFile == null) return;

    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $message\n';

    // Add to queue and process
    _gitWriteQueue.add(logEntry);
    _processGitWriteQueue();
  }

  /// Process git write queue sequentially to prevent file corruption
  static Future<void> _processGitWriteQueue() async {
    // If already processing, return (another call will handle it)
    if (_isGitWriting || _gitWriteQueue.isEmpty) return;

    _isGitWriting = true;

    try {
      while (_gitWriteQueue.isNotEmpty) {
        final entry = _gitWriteQueue.removeAt(0);

        try {
          // Write synchronously to ensure atomic operation
          await _gitLogFile!.writeAsString(
            entry,
            mode: FileMode.append,
            flush: true,
          );
        } catch (e) {
          // Silently ignore write errors
        }
      }
    } finally {
      _isGitWriting = false;
    }
  }

  /// Log debug information (only in debug mode)
  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      final msg = '$_prefix [DEBUG] $message';
      debugPrint(msg);
      _writeToFile(msg);
      if (error != null) {
        final errMsg = '$_prefix [DEBUG] Error: $error';
        debugPrint(errMsg);
        _writeToFile(errMsg);
      }
      if (stackTrace != null) {
        final stackMsg = '$_prefix [DEBUG] StackTrace: $stackTrace';
        debugPrint(stackMsg);
        _writeToFile(stackMsg);
      }
    }
  }

  /// Log info messages
  static void info(String message, {bool forceConsole = false}) {
    final msg = '$_prefix [INFO] $message';
    debugPrint(msg);
    _writeToFile(msg);

    // For critical operations (like updates), force output to stdout
    // This ensures visibility when running from terminal in release builds
    if (forceConsole) {
      // ignore: avoid_print
      print(msg);
    }
  }

  /// Log warning messages
  static void warning(String message, [Object? error]) {
    final msg = '$_prefix [WARNING] $message';
    debugPrint(msg);
    _writeToFile(msg);
    if (error != null) {
      final errMsg = '$_prefix [WARNING] Error: $error';
      debugPrint(errMsg);
      _writeToFile(errMsg);
    }
  }

  /// Log error messages
  static void error(String message, [Object? error, StackTrace? stackTrace, bool forceConsole = false]) {
    final msg = '$_prefix [ERROR] $message';
    debugPrint(msg);
    _writeToFile(msg);

    // For critical operations (like updates), force output to stdout
    if (forceConsole) {
      // ignore: avoid_print
      print(msg);
    }

    if (error != null) {
      final errMsg = '$_prefix [ERROR] Error: $error';
      debugPrint(errMsg);
      _writeToFile(errMsg);
      if (forceConsole) {
        // ignore: avoid_print
        print(errMsg);
      }
    }
    if (stackTrace != null) {
      final stackMsg = '$_prefix [ERROR] StackTrace: $stackTrace';
      debugPrint(stackMsg);
      _writeToFile(stackMsg);
      if (forceConsole) {
        // ignore: avoid_print
        print(stackMsg);
      }
    }
  }

  /// Log configuration changes
  static void config(String message) {
    if (kDebugMode) {
      final msg = '$_prefix [CONFIG] $message';
      debugPrint(msg);
      _writeToFile(msg);
    }
  }

  /// Log Git command execution
  /// Logs all Git commands with timestamp, duration, output, and errors to git.log
  static void git({
    required String command,
    required DateTime timestamp,
    required Duration duration,
    String? output,
    String? error,
    int? exitCode,
  }) {
    final buffer = StringBuffer();

    // Command header with timestamp and duration
    buffer.writeln('='.padRight(80, '='));
    buffer.writeln('[${timestamp.toIso8601String()}] Git Command Executed');
    buffer.writeln('Command: $command');
    buffer.writeln('Duration: ${duration.inMilliseconds}ms');
    buffer.writeln('Exit Code: ${exitCode ?? 'N/A'}');

    // Output section
    if (output != null && output.isNotEmpty) {
      buffer.writeln('-'.padRight(80, '-'));
      buffer.writeln('STDOUT:');
      buffer.writeln(output.trim());
    }

    // Error section
    if (error != null && error.isNotEmpty) {
      buffer.writeln('-'.padRight(80, '-'));
      buffer.writeln('STDERR:');
      buffer.writeln(error.trim());
    }

    buffer.writeln('='.padRight(80, '='));
    buffer.writeln(); // Empty line for readability

    // Write to git log file
    _writeToGitFile(buffer.toString());

    // Also log to console in debug mode
    if (kDebugMode) {
      final consoleMsg = '$_prefix [GIT] $command (${duration.inMilliseconds}ms, exit: ${exitCode ?? 'N/A'})';
      debugPrint(consoleMsg);
    }
  }
}
