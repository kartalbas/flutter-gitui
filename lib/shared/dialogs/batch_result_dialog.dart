import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_theme.dart';
import '../components/base_label.dart';
import '../components/base_dialog.dart';
import '../components/base_button.dart';
import '../../features/repositories/repository_batch_error_provider.dart';
import '../../core/services/notification_service.dart';

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
  Widget build(BuildContext context) {
    final isSuccess = result.success;
    final icon = isSuccess
        ? PhosphorIconsBold.checkCircle
        : PhosphorIconsBold.warningCircle;
    final color = isSuccess
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;

    return BaseDialog(
      title: isSuccess ? 'Operation Successful' : 'Operation Failed',
      icon: icon,
      variant: isSuccess ? DialogVariant.normal : DialogVariant.destructive,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Repository name
          BodySmallLabel(
            'Repository',
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.paddingXS),
          BodyMediumLabel(
            repositoryName,
            color: Theme.of(context).colorScheme.onSurface,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppTheme.paddingM),

          // Message
          BodySmallLabel(
            'Message',
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.paddingXS),
          Container(
            padding: const EdgeInsets.all(AppTheme.paddingM),
            decoration: BoxDecoration(
              color: isSuccess
                  ? color.withValues(alpha: 0.1)
                  : Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: SelectableText(
              result.message,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Copy button
        BaseButton(
          label: 'Copy',
          variant: ButtonVariant.tertiary,
          leadingIcon: PhosphorIconsRegular.copy,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: result.message));
            NotificationService.showSuccess(context, 'Message copied to clipboard');
          },
        ),
        // Dismiss button
        BaseButton(
          label: 'Dismiss',
          variant: isSuccess ? ButtonVariant.primary : ButtonVariant.danger,
          leadingIcon: PhosphorIconsRegular.x,
          onPressed: () {
            onDismiss();
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

/// Helper function to show the batch result dialog
Future<void> showBatchResultDialog({
  required BuildContext context,
  required String repositoryName,
  required RepositoryBatchResult result,
  required VoidCallback onDismiss,
}) {
  return showDialog(
    context: context,
    builder: (context) => BatchResultDialog(
      repositoryName: repositoryName,
      result: result,
      onDismiss: onDismiss,
    ),
  );
}
