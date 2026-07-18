import 'dart:io';
import 'package:flutter/material.dart';
import '../../generated/app_localizations.dart';
import 'package:path/path.dart' as path;

/// Utility class for validating Windows filenames and detecting reserved names
class WindowsFilenameValidator {
  /// Windows reserved device names (case-insensitive)
  static const Set<String> _reservedNames = {
    'CON', 'PRN', 'AUX', 'NUL',
    'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
    'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
  };

  /// Invalid characters in Windows filenames
  static const Set<String> _invalidChars = {
    '<', '>', ':', '"', '/', '\\', '|', '?', '*'
  };

  /// Check if running on Windows
  static bool get isWindows => Platform.isWindows;

  /// Check if a filename is a Windows reserved name
  /// Returns true if the filename (without extension) is a reserved device name
  static bool isReservedName(String filename) {
    if (!isWindows) return false;

    // Get just the filename without path
    final basename = path.basename(filename);

    // Split filename and extension
    final nameWithoutExtension = path.basenameWithoutExtension(basename).toUpperCase();

    return _reservedNames.contains(nameWithoutExtension);
  }

  /// Check if a file path contains any Windows reserved names
  static bool hasReservedName(String filePath) {
    if (!isWindows) return false;

    // Check each component of the path
    final parts = path.split(filePath);
    for (final part in parts) {
      if (isReservedName(part)) {
        return true;
      }
    }

    return false;
  }

  /// Extract the reserved name from a file path
  /// Returns null if no reserved name is found
  static String? getReservedName(String filePath) {
    if (!isWindows) return null;

    final parts = path.split(filePath);
    for (final part in parts) {
      if (isReservedName(part)) {
        return path.basenameWithoutExtension(part).toUpperCase();
      }
    }

    return null;
  }

  /// Check if a filename contains invalid Windows characters
  static bool hasInvalidChars(String filename) {
    if (!isWindows) return false;

    for (final char in _invalidChars) {
      if (filename.contains(char)) {
        return true;
      }
    }

    return false;
  }

  /// Get a user-friendly error message for a reserved filename
  static String getErrorMessage(String filePath, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reservedName = getReservedName(filePath);

    if (reservedName != null) {
      return l10n.windowsReservedNameError(
        filePath,
        reservedName,
        _reservedNames.join(', '),
      );
    }

    return l10n.invalidWindowsFilename(filePath);
  }

  /// Check if a Git error message indicates a Windows reserved name issue
  static bool isReservedNameError(String errorMessage) {
    return errorMessage.contains('open("') &&
           errorMessage.contains('"): No such file or directory') ||
           errorMessage.contains('unable to index file');
  }

  /// Extract problematic filename from Git error message
  static String? extractFilenameFromError(String errorMessage) {
    // Pattern: open("path/to/file"): No such file or directory
    final openPattern = RegExp(r'open\("([^"]+)"\)');
    final match = openPattern.firstMatch(errorMessage);

    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }

    // Pattern: unable to index file 'path/to/file'
    final indexPattern = RegExp(r"unable to index file '([^']+)'");
    final indexMatch = indexPattern.firstMatch(errorMessage);

    if (indexMatch != null && indexMatch.groupCount >= 1) {
      return indexMatch.group(1);
    }

    return null;
  }
}
