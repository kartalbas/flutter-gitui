import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/components/base_button.dart';
import 'logger_service.dart';
import 'editor_launcher_service.dart';

/// Centralized notification service for showing consistent snackbars across the app
class NotificationService {
  /// Show a success notification (green)
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show an error notification (red)
  /// Has a copy button to copy the complete error message to clipboard
  /// Has an open log files button if text editor is configured
  /// Requires manual dismissal - does not auto-hide
  static void showError(BuildContext context, String message, {String? textEditor}) {
    if (!context.mounted) return;

    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.onError),
            const SizedBox(width: AppTheme.paddingS),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppTheme.paddingS),
            // Copy button
            BaseIconButton(
              icon: Icons.content_copy,
              tooltip: 'Copy error to clipboard',
              size: ButtonSize.small,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: message));
                // Show brief feedback
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Error copied to clipboard'),
                    duration: const Duration(seconds: 1),
                    backgroundColor: colorScheme.primary,
                  ),
                );
              },
            ),
            // Open log files button (if text editor configured)
            if (textEditor != null && Logger.logFilePath != null)
              BaseIconButton(
                icon: Icons.description,
                tooltip: 'Open log files',
                size: ButtonSize.small,
                onPressed: () async {
                  try {
                    // Open app.log
                    if (Logger.logFilePath != null) {
                      await EditorLauncherService.openAppLog();
                    }

                    // Open git.log
                    if (Logger.gitLogFilePath != null) {
                      await EditorLauncherService.openGitLog();
                    }
                  } catch (e) {
                    Logger.error('Failed to open log files', e);
                  }
                },
              ),
          ],
        ),
        backgroundColor: colorScheme.error,
        duration: const Duration(days: 365), // Never auto-dismiss
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: colorScheme.onError,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show an info notification (blue)
  static void showInfo(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show a warning notification (orange)
  /// Has a copy button to copy the complete warning message to clipboard
  /// Has an open log files button if text editor is configured
  /// Requires manual dismissal - does not auto-hide
  static void showWarning(BuildContext context, String message, {String? textEditor}) {
    if (!context.mounted) return;

    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning_amber_outlined, color: colorScheme.onSecondary),
            const SizedBox(width: AppTheme.paddingS),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppTheme.paddingS),
            // Copy button
            BaseIconButton(
              icon: Icons.content_copy,
              tooltip: 'Copy warning to clipboard',
              size: ButtonSize.small,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: message));
                // Show brief feedback
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Warning copied to clipboard'),
                    duration: const Duration(seconds: 1),
                    backgroundColor: colorScheme.primary,
                  ),
                );
              },
            ),
            // Open log files button (if text editor configured)
            if (textEditor != null && Logger.logFilePath != null)
              BaseIconButton(
                icon: Icons.description,
                tooltip: 'Open log files',
                size: ButtonSize.small,
                onPressed: () async {
                  try {
                    // Open app.log
                    if (Logger.logFilePath != null) {
                      await EditorLauncherService.openAppLog();
                    }

                    // Open git.log
                    if (Logger.gitLogFilePath != null) {
                      await EditorLauncherService.openGitLog();
                    }
                  } catch (e) {
                    Logger.error('Failed to open log files', e);
                  }
                },
              ),
          ],
        ),
        backgroundColor: colorScheme.secondary,
        duration: const Duration(days: 365), // Never auto-dismiss
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: colorScheme.onSecondary,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}

