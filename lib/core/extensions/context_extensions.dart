import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notification_service.dart';
import '../config/config_providers.dart';

/// Extension methods for BuildContext
extension BuildContextExtensions on BuildContext {
  /// Get the current ColorScheme
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Get the current TextTheme
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Get the current ThemeData
  ThemeData get theme => Theme.of(this);

  /// Get screen size
  Size get screenSize => MediaQuery.of(this).size;

  /// Get screen width
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Get screen height
  double get screenHeight => MediaQuery.of(this).size.height;

  /// Check if screen is small (< 600)
  bool get isSmallScreen => screenWidth < 600;

  /// Check if screen is medium (600-1200)
  bool get isMediumScreen => screenWidth >= 600 && screenWidth < 1200;

  /// Check if screen is large (>= 1200)
  bool get isLargeScreen => screenWidth >= 1200;

  /// Show an error notification with optional text editor for opening log files
  void showErrorSnackBar(String message) {
    // Try to get text editor from ProviderScope
    String? textEditor;
    try {
      final container = ProviderScope.containerOf(this, listen: false);
      textEditor = container.read(preferredTextEditorProvider);
    } catch (e) {
      // ProviderScope not available, skip text editor
    }
    NotificationService.showError(this, message, textEditor: textEditor);
  }

  /// Show a warning notification with optional text editor for opening log files
  void showWarningSnackBar(String message) {
    // Try to get text editor from ProviderScope
    String? textEditor;
    try {
      final container = ProviderScope.containerOf(this, listen: false);
      textEditor = container.read(preferredTextEditorProvider);
    } catch (e) {
      // ProviderScope not available, skip text editor
    }
    NotificationService.showWarning(this, message, textEditor: textEditor);
  }

  /// Navigate back if possible
  void popIfCan() {
    if (Navigator.of(this).canPop()) {
      Navigator.of(this).pop();
    }
  }
}
