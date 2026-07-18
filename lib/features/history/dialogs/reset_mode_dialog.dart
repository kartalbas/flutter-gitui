import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_label.dart';
import '../../../core/git/models/commit.dart';
import '../../../core/git/git_service.dart';
import '../../../generated/app_localizations.dart';

/// Dialog to choose reset mode when resetting to a commit
class ResetModeDialog extends StatelessWidget {
  final GitCommit commit;

  const ResetModeDialog({
    super.key,
    required this.commit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BaseDialog(
      title: l10n.resetToCommit,
      icon: PhosphorIconsRegular.arrowCounterClockwise,
      variant: DialogVariant.normal,
      maxWidth: 500,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BodyMediumLabel(
            l10n.resetCurrentBranchTo(commit.shortHash),
          ),
          const SizedBox(height: AppTheme.paddingS),
          Container(
            padding: const EdgeInsets.all(AppTheme.paddingM),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Row(
              children: [
                Icon(
                  PhosphorIconsRegular.gitCommit,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppTheme.paddingS),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BodyMediumLabel(
                        commit.shortSubject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      BodySmallLabel(
                        '${commit.shortHash} by ${commit.author}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.paddingL),
          TitleSmallLabel(
            l10n.chooseResetMode,
          ),
          const SizedBox(height: AppTheme.paddingS),
          BodySmallLabel(
            l10n.branchPointerWillMove,
          ),
        ],
      ),
      actions: [
        BaseButton(
          label: l10n.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        BaseButton(
          label: '${l10n.soft}\n(${l10n.keepChangesStagedSoft})',
          variant: ButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(ResetMode.soft),
        ),
        BaseButton(
          label: '${l10n.mixed}\n(${l10n.keepChangesUnstagedMixed})',
          variant: ButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(ResetMode.mixed),
        ),
        BaseButton(
          label: '${l10n.hard}\n(${l10n.discardAllChangesHard})',
          variant: ButtonVariant.danger,
          onPressed: () => Navigator.of(context).pop(ResetMode.hard),
        ),
      ],
    );
  }
}
