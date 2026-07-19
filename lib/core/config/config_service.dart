import 'dart:io';
import 'dart:async';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'app_config.dart';
import '../services/logger_service.dart';
import '../utils/result.dart';

/// Configuration service for loading and saving YAML config
class ConfigService {
  static const String _configFileName = 'config.yaml';
  static const String _configDirName = '.flutter-gitui';

  /// Lock to prevent concurrent YAML writes
  static final _saveLock = _AsyncLock();

  /// Get the user's home directory with proper fallback
  static Future<String> _getHomeDirectory() async {
    if (Platform.isWindows) {
      // On Windows, always try USERPROFILE first
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        return userProfile;
      }
      // If USERPROFILE is not set, use Documents folder
      final docsDir = await getApplicationDocumentsDirectory();
      return docsDir.parent.path; // Go up one level from Documents to user home
    } else {
      // On Unix systems, use HOME
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return home;
      }
      // Fallback to documents directory
      final docsDir = await getApplicationDocumentsDirectory();
      return docsDir.path;
    }
  }

  /// Get the config file path
  /// Linux/macOS: ~/.flutter-gitui/config.yaml
  /// Windows: %USERPROFILE%\.flutter-gitui\config.yaml
  static Future<String> getConfigFilePath() async {
    final home = await _getHomeDirectory();
    final configDir = path.join(home, _configDirName);
    return path.join(configDir, _configFileName);
  }

  /// Get the config directory path
  static Future<String> getConfigDirPath() async {
    final home = await _getHomeDirectory();
    return path.join(home, _configDirName);
  }

  /// Ensure config directory exists
  static Future<Result<void>> ensureConfigDirExists() async {
    return runCatchingAsync(() async {
      final configDir = await getConfigDirPath();
      final dir = Directory(configDir);

      if (!await dir.exists()) {
        await dir.create(recursive: true);
        Logger.config('Created config directory: $configDir');
      }
    });
  }

  /// Load configuration from YAML file
  static Future<Result<AppConfig>> load() async {
    return runCatchingAsync(() async {
      final configPath = await getConfigFilePath();
      final file = File(configPath);

      if (!await file.exists()) {
        Logger.info('Config file not found at $configPath, using defaults');
        return AppConfig.defaults;
      }

      final yamlString = await file.readAsString();
      final yamlMap = loadYaml(yamlString) as Map;

      final config = AppConfig.fromYaml(yamlMap);
      Logger.config('Loaded config from: $configPath');
      return config;
    });
  }

  /// Save configuration to YAML file
  /// Uses a lock to prevent concurrent writes that could cause data loss
  static Future<Result<void>> save(AppConfig config) async {
    return runCatchingAsync(() async {
      await _saveLock.synchronized(() async {
        final ensureResult = await ensureConfigDirExists();
        ensureResult.unwrap(); // Throw on error

        final configPath = await getConfigFilePath();
        final tempPath = '$configPath.tmp';
        final tempFile = File(tempPath);

        // Convert config to YAML string with proper formatting
        final yamlMap = config.toYaml();
        final yamlString = _toYamlString(yamlMap);

        // Write to temporary file first (atomic write pattern)
        await tempFile.writeAsString(yamlString);

        // Atomically replace the original file by renaming
        // This prevents corruption if the app crashes during write
        await tempFile.rename(configPath);

        Logger.config('Saved config to: $configPath');
      });
    });
  }

  /// Convert map to YAML string with proper formatting and comments
  static String _toYamlString(Map<String, dynamic> map, [int indent = 0]) {
    final buffer = StringBuffer();
    final spaces = '  ' * indent;

    if (indent == 0) {
      buffer.writeln('# Flutter GitUI Configuration');
      buffer.writeln('# Edit this file to customize your settings');
      buffer.writeln('# File location: ~/.flutter-gitui/config.yaml (Linux/macOS)');
      buffer.writeln('#                %USERPROFILE%\\.flutter-gitui\\config.yaml (Windows)');
      buffer.writeln();
    }

    map.forEach((key, value) {
      if (value == null) {
        buffer.writeln('$spaces$key: null');
      } else if (value is Map) {
        buffer.writeln('$spaces$key:');
        buffer.write(_toYamlString(value as Map<String, dynamic>, indent + 1));
      } else if (value is List) {
        if (value.isEmpty) {
          buffer.writeln('$spaces$key: []');
        } else {
          buffer.writeln('$spaces$key:');
          for (final item in value) {
            if (item is Map) {
              buffer.writeln('$spaces  -');
              final itemMap = item as Map<String, dynamic>;
              itemMap.forEach((k, v) {
                if (v is String) {
                  buffer.writeln('$spaces    $k: ${_yamlString(v)}');
                } else if (v is bool || v is num) {
                  buffer.writeln('$spaces    $k: $v');
                } else if (v is List) {
                  // A nested list has to stay a YAML sequence: stringifying it
                  // makes the reader's `as List` cast throw, which drops the
                  // entire config back to defaults on the next launch.
                  if (v.isEmpty) {
                    buffer.writeln('$spaces    $k: []');
                  } else {
                    buffer.writeln('$spaces    $k:');
                    for (final element in v) {
                      if (element is bool || element is num) {
                        buffer.writeln('$spaces      - $element');
                      } else {
                        buffer.writeln('$spaces      - ${_yamlString(element.toString())}');
                      }
                    }
                  }
                } else {
                  buffer.writeln('$spaces    $k: ${_yamlString(v.toString())}');
                }
              });
            } else if (item is String) {
              buffer.writeln('$spaces  - ${_yamlString(item)}');
            } else if (item is bool || item is num) {
              buffer.writeln('$spaces  - $item');
            } else {
              buffer.writeln('$spaces  - ${_yamlString(item.toString())}');
            }
          }
        }
      } else if (value is String) {
        buffer.writeln('$spaces$key: ${_yamlString(value)}');
      } else if (value is bool || value is num) {
        buffer.writeln('$spaces$key: $value');
      } else {
        buffer.writeln('$spaces$key: ${_yamlString(value.toString())}');
      }
    });

    return buffer.toString();
  }

  /// Renders [value] as a YAML double-quoted scalar.
  ///
  /// Previously only backslashes were escaped, so a quote, newline or tab in a
  /// repository name or description produced a file the parser rejected on the
  /// next launch. Every character that YAML's double-quoted style treats
  /// specially is escaped here, in one place.
  static String _yamlString(String value) {
    final buffer = StringBuffer('"');
    for (final rune in value.runes) {
      switch (rune) {
        case 0x5C: // backslash
          buffer.write(r'\\');
        case 0x22: // double quote
          buffer.write(r'\"');
        case 0x0A: // line feed
          buffer.write(r'\n');
        case 0x0D: // carriage return
          buffer.write(r'\r');
        case 0x09: // tab
          buffer.write(r'\t');
        default:
          // Remaining C0 control characters have no literal representation.
          if (rune < 0x20) {
            buffer.write('\\x${rune.toRadixString(16).padLeft(2, '0')}');
          } else {
            buffer.writeCharCode(rune);
          }
      }
    }
    buffer.write('"');
    return buffer.toString();
  }
}

/// Simple async lock implementation to prevent concurrent operations
class _AsyncLock {
  Completer<void>? _completer;

  /// Execute a function while holding the lock
  Future<T> synchronized<T>(Future<T> Function() func) async {
    // Wait for any existing operation to complete
    while (_completer != null) {
      await _completer!.future;
    }

    // Acquire the lock
    _completer = Completer<void>();

    try {
      // Execute the function
      return await func();
    } finally {
      // Release the lock
      final completer = _completer;
      _completer = null;
      completer?.complete();
    }
  }
}
