import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, Proximity, TextRole, Tone;
import '../theme/app_theme.dart';
import '../components/base_label.dart';
import '../components/base_dialog.dart';
import '../../features/repositories/repository_batch_error_provider.dart';
import '../../core/services/notification_service.dart';
import '../components/base_layout.dart';

/// Dialog for displaying batch operation results with copy and dismiss actions
class BatchResultDialog extends StatelessWidget {
  final String repositoryName;
  final RepositoryBatchResult result;
  final VoidCallback onDismiss;

  const BatchResultDialog({
    super.key,
    required this.repositoryName,
    required this.result,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) =>
      _dialog(context, repositoryName, result, onDismiss);

  static BaseDialog _dialog(
    BuildContext context,
    String repositoryName,
    RepositoryBatchResult result,
    VoidCallback onDismiss,
  ) {
    final isSuccess = result.success;
    // Both marks were drawn at Phosphor BOLD before the conversion and now
    // take the ordinary stroke, because a role carries no weight (#249
    // conflict C3) and `BaseDialog` has no state to re-decide one from.
    // The sibling dialog that reports exactly the same thing —
    // `git_output_dialog.dart`, "the git command succeeded / failed" — always
    // drew its header mark at the ordinary stroke, and so does
    // `batch_operation_progress_dialog.dart`, so this dialog was the odd one
    // of three rather than the one carrying a distinction. Recorded and
    // pinned by `test/shared/icons/icon_weight_census_test.dart`.
    final icon = isSuccess ? IconRole.checkCircle : IconRole.warningCircle;
    // Not a foreground and therefore not a tone: every read of this `Color`
    // paints the message box's surface. In the success branch it is read
    // twice - a 10% wash for the fill and a 30% one for the border; in the
    // failure branch it feeds only the 30% border wash, and the fill is a
    // separate `errorContainer` wash (bucket B, like the rest of the box).
    //
    // **The two branches of one box disagree, and the box cannot yet be the
    // thing that settles them.** The success fill washes a FOREGROUND role
    // (`primary`) at 10 %; the failure fill washes a CONTAINER role
    // (`errorContainer`) at 30 %; and the failure border then washes the
    // foreground role again. One box, two role families, two alphas. Picking
    // between them here would be this dialog choosing a length and a colour,
    // which is the decision the seam exists to take away - and the member
    // that should take it does not reach far enough: the box holds machine
    // output, so its ink is `surfaces.codeBlock`, and that member draws the
    // ink with no ground at all (see the same finding written out at
    // `command_log_panel.dart`). The disagreement is reported rather than
    // rounded, and it goes when the ground has a member.
    final color = isSuccess
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;

    return BaseDialog(
      title: isSuccess ? 'Operation Successful' : 'Operation Failed',
      icon: icon,
      variant: isSuccess ? DialogVariant.normal : DialogVariant.destructive,
      onSubmit: () {
        onDismiss();
        Navigator.of(context).pop();
      },
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Repository name
          BaseLabel('Repository', role: TextRole.detail, tone: Tone.muted),
          const BaseGap(Proximity.hairline),
          BaseLabel(repositoryName, role: TextRole.body, maxLines: 2),
          const BaseGap(Proximity.grouped),

          // Message
          BaseLabel('Message', role: TextRole.detail, tone: Tone.muted),
          const BaseGap(Proximity.hairline),
          Container(
            decoration: BoxDecoration(
              color: isSuccess
                  ? color.withValues(alpha: 0.1)
                  : Theme.of(
                      context,
                    ).colorScheme.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
            ),
            // Command output, which is what the monospace family and the
            // spelled-out `onSurface` between them were saying: alignment is
            // meaning here, and the ink is this surface's ordinary foreground.
            // The hand-set ramp step goes with them: which step this text
            // lands on is the role's answer, not this dialog's.
            child: BaseInset(
              child: BaseLabel(
                result.message,
                role: TextRole.code,
                selectable: true,
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Copying the message leaves the dialog open, so it is a peer of the
        // dismissal rather than a second way to finish.
        DialogAction(
          label: 'Copy',
          role: DialogActionRole.neutral,
          icon: IconRole.copy,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: result.message));
            NotificationService.showSuccess(
              context,
              'Message copied to clipboard',
            );
          },
        ),
        // Acknowledging the result is all this dialog asks for, so Dismiss is
        // its affirmative action - in both outcomes. It used to switch to the
        // danger variant when the batch had failed, which said "this button
        // destroys something" to express "the operation failed": the failure
        // is a property of the dialog, already carried by the destructive
        // DialogVariant and the warning icon above, not of the button that
        // closes it.
        DialogAction(
          label: 'Dismiss',
          role: DialogActionRole.affirmative,
          icon: IconRole.x,
          onPressed: () {
            onDismiss();
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

/// Reports a batch result, on the skin's own dialog route.
///
/// The frame is decided once from [result] and both actions only pop, so the
/// whole dialog can be stated before it exists - which is what lets it reach
/// `Overlays.dialog` rather than Material's `showDialog`.
Future<void> showBatchResultDialog({
  required BuildContext context,
  required String repositoryName,
  required RepositoryBatchResult result,
  required VoidCallback onDismiss,
}) {
  return BaseDialog.show<void>(
    context: context,
    dialog: BatchResultDialog._dialog(
      context,
      repositoryName,
      result,
      onDismiss,
    ),
  );
}
