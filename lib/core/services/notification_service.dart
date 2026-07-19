import 'dart:async';

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

    // ScaffoldMessenger queues snackbars: a still-visible error, which never
    // auto-dismisses, would otherwise keep this one hidden indefinitely.
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
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
    // Resolve the messenger now: the snackbar outlives this context, so
    // button callbacks must not look it up after the widget is disposed.
    final messenger = ScaffoldMessenger.of(context);
    // A queued snackbar stays invisible until the current one is gone, so drop
    // anything pending and let the newest problem be the one on screen.
    messenger.clearSnackBars();
    messenger.showSnackBar(
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
            _CopyButton(
              message: message,
              tooltip: 'Copy error to clipboard',
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
                      (await EditorLauncherService.openAppLog()).unwrap();
                    }

                    // Open git.log
                    if (Logger.gitLogFilePath != null) {
                      (await EditorLauncherService.openGitLog()).unwrap();
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
            messenger.hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show an info notification (blue)
  static void showInfo(BuildContext context, String message) {
    if (!context.mounted) return;

    // ScaffoldMessenger queues snackbars: a still-visible error, which never
    // auto-dismisses, would otherwise keep this one hidden indefinitely.
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
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
    // Resolve the messenger now: the snackbar outlives this context, so
    // button callbacks must not look it up after the widget is disposed.
    final messenger = ScaffoldMessenger.of(context);
    // A queued snackbar stays invisible until the current one is gone, so drop
    // anything pending and let the newest problem be the one on screen.
    messenger.clearSnackBars();
    messenger.showSnackBar(
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
            _CopyButton(
              message: message,
              tooltip: 'Copy warning to clipboard',
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
                      (await EditorLauncherService.openAppLog()).unwrap();
                    }

                    // Open git.log
                    if (Logger.gitLogFilePath != null) {
                      (await EditorLauncherService.openGitLog()).unwrap();
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
            messenger.hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}

/// Copy button that confirms in place rather than posting a snackbar.
///
/// A confirmation snackbar would be queued behind the error or warning
/// snackbar hosting this button, so it could never be seen while the message
/// it belongs to is still on screen.
class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.message, required this.tooltip});

  final String message;
  final String tooltip;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  Timer? _resetTimer;
  bool _copied = false;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.message));
    _resetTimer?.cancel();
    setState(() => _copied = true);
    _resetTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BaseIconButton(
      icon: _copied ? Icons.check : Icons.content_copy,
      tooltip: _copied ? 'Copied to clipboard' : widget.tooltip,
      size: ButtonSize.small,
      onPressed: _copy,
    );
  }
}

