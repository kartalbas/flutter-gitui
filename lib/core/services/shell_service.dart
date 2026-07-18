import 'dart:io';
import 'package:process_run/shell.dart';

import '../utils/result.dart';

/// Service for running shell commands in a GUI-safe manner
///
/// Windows GUI apps don't have a console, so stdout/stderr handles are invalid.
/// This service provides a Shell that doesn't try to output to these handles.
class ShellService {
  static bool? _hasConsole;

  /// Check if the app has a valid console (stdout/stderr)
  static bool get hasConsole {
    if (_hasConsole != null) return _hasConsole!;

    // On Windows, GUI apps (subsystem:windows) don't have a console
    // We can detect this by checking if stdout is connected to a terminal
    // or by trying to write and catching the error
    if (Platform.isWindows) {
      try {
        // Check if stdout has a valid terminal
        // For GUI apps, this will be false or throw
        _hasConsole = stdout.hasTerminal;
      } catch (e) {
        _hasConsole = false;
      }
    } else {
      // On macOS/Linux, apps typically have console access
      _hasConsole = true;
    }

    return _hasConsole!;
  }

  /// Create a Shell that's safe for GUI apps
  ///
  /// Returns a Shell with verbose=false and null stdout/stderr
  /// to prevent "handle is invalid" errors on Windows GUI apps.
  static Shell createShell({String? workingDirectory}) {
    return Shell(
      verbose: false,
      stdout: null,
      stderr: null,
      workingDirectory: workingDirectory,
    );
  }

  /// Run a command and return the result
  ///
  /// This is a convenience method that creates a silent shell and runs the command.
  static Future<Result<List<ProcessResult>>> run(
    String script, {
    String? workingDirectory,
  }) async {
    return runCatchingAsync(() async {
      final shell = createShell(workingDirectory: workingDirectory);
      return shell.run(script);
    });
  }
}
