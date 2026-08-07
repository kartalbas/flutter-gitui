import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'app_config.dart';
import 'config_migration.dart';
import '../services/logger_service.dart';
import '../utils/result.dart';

/// Raised when the settings could not be written to disk.
///
/// The underlying failure is a platform exception whose text names an errno
/// and a temporary file the user never asked about. This carries a sentence
/// instead, because a failed save is reported to the user and the platform's
/// own words explain nothing to them.
class ConfigWriteException implements Exception {
  const ConfigWriteException(this.configPath, this.cause);

  /// The file the settings belong in.
  final String configPath;

  /// What the platform actually refused, kept for the log.
  final Object cause;

  @override
  String toString() =>
      'Your settings could not be saved to $configPath. Another program is '
      'holding that file open - an antivirus scanner, a backup agent or a '
      'second copy of this application are the usual causes. The change is '
      'still applied in this session and will be written on the next attempt. '
      '(Underlying error: $cause)';
}

/// Configuration service for loading and saving YAML config
class ConfigService {
  static const String _configFileName = 'config.yaml';
  static const String _configDirName = '.flutter-gitui';

  /// Lock to prevent concurrent YAML writes
  static final _saveLock = _AsyncLock();

  /// How long to keep retrying a rename a transient lock refused.
  ///
  /// On Windows a file that has just been written is opened for scanning by
  /// Defender, the search indexer or a backup agent, and those handles are
  /// usually opened without FILE_SHARE_DELETE - so a rename during the scan
  /// fails with "access is denied". The window is milliseconds wide, and this
  /// code renames immediately after writing, which is the narrowest possible
  /// race with it: the first attempt is the one most likely to lose.
  static const List<Duration> _renameRetryDelays = <Duration>[
    Duration(milliseconds: 20),
    Duration(milliseconds: 40),
    Duration(milliseconds: 80),
    Duration(milliseconds: 160),
    Duration(milliseconds: 320),
  ];

  /// Replaces the rename, so a test can refuse it the way a scanner does
  /// without needing a scanner. Null in production.
  @visibleForTesting
  static Future<void> Function(File temp, String targetPath)?
  debugRenameOverride;

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
      // Before reading, adopt any save that wrote its file but could not move
      // it into place. Skipping this reads settings the user already replaced.
      await _recoverStrandedSave(configPath);
      final file = File(configPath);

      if (!await file.exists()) {
        Logger.info('Config file not found at $configPath, using defaults');
        return AppConfig.defaults;
      }

      final yamlString = await file.readAsString();
      final yamlMap = loadYaml(yamlString) as Map;

      final config = AppConfig.fromYaml(yamlMap);
      Logger.config('Loaded config from: $configPath');

      final storedVersion = yamlMap['config_version'] as int?;
      if (storedVersion == null ||
          storedVersion < AppConfig.currentConfigVersion) {
        return _migrate(config, storedVersion);
      }
      return config;
    });
  }

  /// Repairs data written by an older build and stamps the current schema
  /// version, so each repair judges stored values exactly once. Which repairs
  /// a given file needs is [migrateConfig]'s decision, taken from the version
  /// the file carried.
  static Future<AppConfig> _migrate(
    AppConfig config,
    int? storedVersion,
  ) async {
    final migrated = migrateConfig(config, storedVersion);
    final saveResult = await save(migrated);
    if (saveResult.isFailure) {
      // A config directory that cannot be written must not stop the app from
      // starting: the repair is idempotent and runs again on the next launch.
      Logger.warning(
        'Could not persist config migration: ${saveResult.errorOrNull}',
      );
    }
    return migrated;
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

        try {
          // Write to temporary file first (atomic write pattern)
          await tempFile.writeAsString(yamlString);

          // Atomically replace the original file by renaming
          // This prevents corruption if the app crashes during write
          await _replaceAtomically(tempFile, configPath);
        } on FileSystemException catch (error) {
          // A failed save is reported to the user, and the platform's own
          // wording names an errno and a temporary file they never asked
          // about. Say what happened instead.
          throw ConfigWriteException(configPath, error);
        }

        Logger.config('Saved config to: $configPath');
      });
    });
  }

  /// Moves [temp] over [targetPath], retrying a rename a transient lock
  /// refused, and writing the file directly when every attempt fails.
  ///
  /// The retries handle the scanner race described at [_renameRetryDelays].
  /// The fallback handles the case where the lock outlives them: it gives up
  /// atomicity for this one write rather than giving up the user's change,
  /// which is the worse of the two outcomes. The atomic path exists to survive
  /// a crash halfway through a write, and a crash is far rarer than a scanner.
  ///
  /// The temporary file is removed only after the target has been written, so
  /// a failure at the last step leaves the newer settings on disk for
  /// [_recoverStrandedSave] to adopt on the next launch.
  static Future<void> _replaceAtomically(File temp, String targetPath) async {
    Object? lastError;

    for (var attempt = 0; attempt <= _renameRetryDelays.length; attempt++) {
      try {
        final rename = debugRenameOverride;
        if (rename != null) {
          await rename(temp, targetPath);
        } else {
          await temp.rename(targetPath);
        }
        return;
      } on FileSystemException catch (error) {
        lastError = error;
        if (attempt < _renameRetryDelays.length) {
          await Future<void>.delayed(_renameRetryDelays[attempt]);
        }
      }
    }

    Logger.warning(
      'Could not move the config into place after '
      '${_renameRetryDelays.length + 1} attempts, writing it directly: '
      '$lastError',
    );

    try {
      await File(targetPath).writeAsString(await temp.readAsString());
    } on FileSystemException catch (error) {
      // The target itself is held, not just the temporary file. The settings
      // stay in the temporary file and the next launch adopts them.
      throw ConfigWriteException(targetPath, error);
    }

    await _deleteQuietly(temp);
  }

  /// Adopts a save that completed everywhere except its last step.
  ///
  /// A temporary file that still exists is a write that succeeded and a rename
  /// that did not, so the user's newest settings are sitting beside the ones
  /// the application is about to read. Left alone they are silently lost and
  /// every later launch reads the older file, which is exactly what was
  /// observed in the field.
  ///
  /// **Existence alone decides it, not a timestamp.** A save that lands
  /// consumes its temporary file - the rename moves it, and the fallback
  /// deletes it after writing the target - and a later save rewrites that same
  /// path before renaming. So a surviving temporary file cannot belong to a
  /// save that succeeded, whatever the clock says. Comparing timestamps would
  /// also be unsound here: measured on Windows, [File.lastModified] resolves to
  /// whole seconds, so two writes 60 ms apart carry an identical stamp and any
  /// ordering read from them is a guess.
  ///
  /// It is adopted only when it parses. One that does not parse is the debris
  /// of a write interrupted partway through and is removed, because keeping it
  /// would make every later launch try to adopt it again.
  ///
  /// This never throws: a config that cannot be repaired must not stop the
  /// application from starting.
  static Future<void> _recoverStrandedSave(String configPath) async {
    try {
      final temp = File('$configPath.tmp');
      if (!await temp.exists()) return;

      final config = File(configPath);
      final text = await temp.readAsString();
      try {
        loadYaml(text) as Map;
      } catch (_) {
        Logger.warning(
          'Discarding an unreadable $configPath.tmp: it is the debris of an '
          'interrupted write, not a save that lost its last step.',
        );
        await _deleteQuietly(temp);
        return;
      }

      await config.writeAsString(text);
      await _deleteQuietly(temp);
      Logger.config(
        'Recovered settings from $configPath.tmp: an earlier save wrote them '
        'but could not move them into place.',
      );
    } catch (error) {
      Logger.warning('Could not recover a stranded config save: $error');
    }
  }

  /// Deletes [file], ignoring a failure. Used where the file is already
  /// redundant, so failing to remove it costs nothing.
  static Future<void> _deleteQuietly(File file) async {
    try {
      await file.delete();
    } on FileSystemException catch (error) {
      Logger.warning('Could not remove ${file.path}: $error');
    }
  }

  /// The exact YAML text [save] writes, so the serialisation can be
  /// round-tripped in a test without touching the user's home directory.
  @visibleForTesting
  static String toYamlString(Map<String, dynamic> map) => _toYamlString(map);

  /// [_replaceAtomically] against an explicit path, so a test can drive the
  /// retry and the fallback in a temporary directory rather than in the
  /// user's home.
  @visibleForTesting
  static Future<void> replaceAtomically(File temp, String targetPath) =>
      _replaceAtomically(temp, targetPath);

  /// [_recoverStrandedSave] against an explicit path, for the same reason.
  @visibleForTesting
  static Future<void> recoverStrandedSave(String configPath) =>
      _recoverStrandedSave(configPath);

  /// Convert map to YAML string with proper formatting and comments
  static String _toYamlString(Map<String, dynamic> map, [int indent = 0]) {
    final buffer = StringBuffer();
    final spaces = '  ' * indent;

    if (indent == 0) {
      buffer.writeln('# Flutter GitUI Configuration');
      buffer.writeln('# Edit this file to customize your settings');
      buffer.writeln(
        '# File location: ~/.flutter-gitui/config.yaml (Linux/macOS)',
      );
      buffer.writeln(
        '#                %USERPROFILE%\\.flutter-gitui\\config.yaml (Windows)',
      );
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
                // An absent value has to become a bare YAML null. Falling
                // through to the stringifying branch below wrote the text
                // "null", which the reader hands back as an ordinary non-empty
                // string, so a repository with no alias rendered as "null".
                if (v == null) {
                  buffer.writeln('$spaces    $k: null');
                } else if (v is String) {
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
                      if (element == null) {
                        buffer.writeln('$spaces      - null');
                      } else if (element is bool || element is num) {
                        buffer.writeln('$spaces      - $element');
                      } else {
                        buffer.writeln(
                          '$spaces      - ${_yamlString(element.toString())}',
                        );
                      }
                    }
                  }
                } else {
                  buffer.writeln('$spaces    $k: ${_yamlString(v.toString())}');
                }
              });
            } else if (item == null) {
              buffer.writeln('$spaces  - null');
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
