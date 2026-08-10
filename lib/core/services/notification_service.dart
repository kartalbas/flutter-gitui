import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import 'logger_service.dart';
import 'editor_launcher_service.dart';

/// The application's notice vocabulary, stated through `overlays.notify`.
///
/// Four methods, and none of them builds a notice any more: each one says what
/// happened ([NoticeSpec.tone]), whether it may go away on its own
/// ([NoticeSpec.lifetime]) and what the user can do about it
/// ([NoticeSpec.actions]), and the skin draws the whole thing. The `SnackBar`,
/// its fill, its floating behaviour, its 365-day duration, its queue handling
/// and its DISMISS affordance were all re-implemented here by hand; every one
/// of them is now the member's answer, which is why this file no longer reads
/// a single Material colour.
///
/// The methods stay, rather than every caller learning to write a
/// [NoticeSpec]: they are the place the application decides that a failure is
/// worth a copy affordance and a route into the log files, and that decision
/// is the application's, not the skin's.
class NotificationService {
  /// States that something finished, and finished well.
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;
    Overlays.notify(context, NoticeSpec(tone: Tone.success, title: message));
  }

  /// States that something failed, and offers the two ways out of it.
  ///
  /// Persistent, because a failure the user never read is a failure they
  /// cannot act on. The copy action hands the whole message to the clipboard;
  /// the log action opens the two log files, and is offered only when a text
  /// editor is configured to open them with.
  static void showError(
    BuildContext context,
    String message, {
    String? textEditor,
  }) {
    if (!context.mounted) return;
    Overlays.notify(
      context,
      NoticeSpec(
        tone: Tone.danger,
        title: message,
        icon: IconRole.warningCircle,
        lifetime: NoticeLifetime.persistent,
        actions: _actions(message, textEditor, 'Copy error to clipboard'),
      ),
    );
  }

  /// States that something may not have been what the user intended.
  static void showWarning(
    BuildContext context,
    String message, {
    String? textEditor,
  }) {
    if (!context.mounted) return;
    Overlays.notify(
      context,
      NoticeSpec(
        tone: Tone.warning,
        title: message,
        icon: IconRole.warning,
        lifetime: NoticeLifetime.persistent,
        actions: _actions(message, textEditor, 'Copy warning to clipboard'),
      ),
    );
  }

  /// States something worth knowing, with nothing wrong.
  static void showInfo(BuildContext context, String message) {
    if (!context.mounted) return;
    Overlays.notify(context, NoticeSpec(tone: Tone.info, title: message));
  }

  /// States something worth knowing that the user must not MISS.
  ///
  /// The fifth decision, and it is the application's rather than a gap in the
  /// vocabulary: `NoticeLifetime` offers exactly two lifetimes, and `brief` is
  /// defined as "something the user may miss without harm". A release this
  /// build cannot install itself, naming a version and where to get it, is not
  /// that - under Material's two-second brief it vanishes unread - but it is
  /// not a failure either, so it must not dress as one.
  ///
  /// It exists as a method rather than as a `NoticeSpec` written at the call
  /// site for the reason every method here exists: what a notice guarantees is
  /// decided in one place. The site that needed it had drifted to twelve
  /// seconds of its own, which is the same drift by another name.
  static void showStandingInfo(BuildContext context, String message) {
    if (!context.mounted) return;
    Overlays.notify(
      context,
      NoticeSpec(
        tone: Tone.info,
        title: message,
        lifetime: NoticeLifetime.persistent,
      ),
    );
  }

  /// What the user can do about a message they have to read.
  static List<NoticeAction> _actions(
    String message,
    String? textEditor,
    String copyTooltip,
  ) => <NoticeAction>[
    NoticeAction(
      label: 'Copy',
      tooltip: copyTooltip,
      icon: IconRole.copy,
      onPressed: () => Clipboard.setData(ClipboardData(text: message)),
    ),
    if (textEditor != null && Logger.logFilePath != null)
      NoticeAction(
        label: 'Logs',
        tooltip: 'Open log files',
        icon: IconRole.fileText,
        onPressed: _openLogs,
      ),
  ];

  /// Opens both log files in the configured editor.
  static Future<void> _openLogs() async {
    try {
      if (Logger.logFilePath != null) {
        (await EditorLauncherService.openAppLog()).unwrap();
      }
      if (Logger.gitLogFilePath != null) {
        (await EditorLauncherService.openGitLog()).unwrap();
      }
    } catch (e) {
      Logger.error('Failed to open log files', e);
    }
  }
}
