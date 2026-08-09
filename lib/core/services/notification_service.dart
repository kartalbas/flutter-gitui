import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show IconRole, Proximity;

import '../../shared/components/base_button.dart';
import 'logger_service.dart';
import 'editor_launcher_service.dart';
import '../../shared/components/base_layout.dart';

/// Centralized notification service for showing consistent snackbars across the app
///
/// **Every Material colour read below waits on one member, and only that
/// member: `overlays.notify`.** It already exists and the Material skin
/// already implements it — `packages/gitui_skin_material/lib/src/facets/
/// material_overlays.dart` names this file in its own doc: "the extraction of
/// `notification_service.dart`". What has not happened is the adoption; no
/// site in `lib/` calls `overlays.notify` yet.
///
/// So the seven reads here are not a colour conversion that was skipped, they
/// are a construction the member deletes whole. None of the three shapes can
/// say a `Tone` from here:
///
///  * `SnackBar.backgroundColor` is the notice's FILL, and the skin's own
///    implementation records why a fill cannot be lifted at this level — a
///    tone may only be resolved inside the host's `build`, so its `SnackBar`
///    shell is painted transparent and `_MaterialNoticeSurface` draws the
///    tone-coloured pill from inside. A call site here has no host to build
///    in, and the application is given no way to resolve a `Tone` to a
///    `Color` for its own decoration — by design, since handing out colours
///    is what the seam exists to stop.
///  * `SnackBarAction.textColor` is a Material `Color` parameter on a
///    Material widget. There is nothing to hand a meaning to.
///  * the two leading marks are `Icons.*` constants, not Phosphor ones, so
///    `BaseIcon` would swap the glyph family inside what is meant to be a
///    rename. Their colours compound it: this notice's foreground pairs with
///    its own fill (`onError`, `onSecondary`), and `Tone.onAccent` resolves
///    to Material's ON-PRIMARY role (`MaterialInk.foreground`), which is a
///    different colour in the dark scheme. Naming the tone would
///    be rounding a meaning onto the nearest available word, which is the
///    mistake #426 cost.
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
        // The notice's own fill. Waits for `overlays.notify`; see the class
        // doc for why a fill cannot state a tone from a call site.
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show an error notification (red)
  /// Has a copy button to copy the complete error message to clipboard
  /// Has an open log files button if text editor is configured
  /// Requires manual dismissal - does not auto-hide
  static void showError(
    BuildContext context,
    String message, {
    String? textEditor,
  }) {
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
            // A Material glyph paired with this notice's own on-colour.
            // `BaseIcon(IconRole.warningCircle, tone: Tone.onAccent)` would
            // change both — Phosphor's mark, and Material's on-primary role
            // instead of `onError`. Waits for `overlays.notify`, which draws
            // the mark from inside the notice surface.
            Icon(Icons.error_outline, color: colorScheme.onError),
            const BaseGap(Proximity.related),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const BaseGap(Proximity.related),
            // Copy button
            _CopyButton(message: message, tooltip: 'Copy error to clipboard'),
            // Open log files button (if text editor configured)
            if (textEditor != null && Logger.logFilePath != null)
              BaseIconButton(
                icon: IconRole.fileText,
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
        // Fill, then the dismiss affordance's own foreground. Both wait for
        // `overlays.notify`: the first because a call site cannot resolve a
        // tone into a decoration, the second because `SnackBarAction.textColor`
        // is a Material `Color` parameter with nothing to hand a meaning to.
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
        // The notice's own fill, as in [showSuccess]. Waits for
        // `overlays.notify`.
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show a warning notification (orange)
  /// Has a copy button to copy the complete warning message to clipboard
  /// Has an open log files button if text editor is configured
  /// Requires manual dismissal - does not auto-hide
  static void showWarning(
    BuildContext context,
    String message, {
    String? textEditor,
  }) {
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
            // As in [showError]: a Material glyph plus this notice's own
            // on-colour, and `Tone.onAccent` resolves to `onPrimary` rather
            // than `onSecondary`. Waits for `overlays.notify`.
            Icon(Icons.warning_amber_outlined, color: colorScheme.onSecondary),
            const BaseGap(Proximity.related),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const BaseGap(Proximity.related),
            // Copy button
            _CopyButton(message: message, tooltip: 'Copy warning to clipboard'),
            // Open log files button (if text editor configured)
            if (textEditor != null && Logger.logFilePath != null)
              BaseIconButton(
                icon: IconRole.fileText,
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
          // A Material `Color` parameter, as in [showError]. Waits for
          // `overlays.notify`.
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
      icon: _copied ? IconRole.check : IconRole.copy,
      tooltip: _copied ? 'Copied to clipboard' : widget.tooltip,
      size: ButtonSize.small,
      onPressed: _copy,
    );
  }
}
