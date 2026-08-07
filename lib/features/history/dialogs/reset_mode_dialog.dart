import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_label.dart';
import '../../../core/git/models/commit.dart';
import '../../../core/git/git_service.dart';
import '../../../generated/app_localizations.dart';

/// Dialog to choose reset mode when resetting to a commit
class ResetModeDialog extends StatelessWidget {
  final GitCommit commit;

  const ResetModeDialog({super.key, required this.commit});

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
          BodyMediumLabel(l10n.resetCurrentBranchTo),
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
                      BodySmallLabel('${commit.shortHash} by ${commit.author}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.paddingL),
          TitleSmallLabel(l10n.chooseResetMode),
          const SizedBox(height: AppTheme.paddingS),
          BodySmallLabel(l10n.branchPointerWillMove),
        ],
      ),
      // Soft, mixed and hard are three different resets, not one action with
      // two alternatives, so none of them is the affirmative one and Enter
      // must not pick for the user (see the null onSubmit above). The two
      // recoverable modes are peers; only the hard reset destroys work, and
      // saying so on the action is what lets a language that has no red fill
      // still mark it (Cupertino's isDestructiveAction).
      actions: [
        DialogAction(
          label: l10n.cancel,
          role: DialogActionRole.dismissive,
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(
          label: '${l10n.soft}\n(${l10n.keepChangesStagedSoft})',
          role: DialogActionRole.neutral,
          onPressed: () => Navigator.of(context).pop(ResetMode.soft),
        ),
        DialogAction(
          label: '${l10n.mixed}\n(${l10n.keepChangesUnstagedMixed})',
          role: DialogActionRole.neutral,
          onPressed: () => Navigator.of(context).pop(ResetMode.mixed),
        ),
        DialogAction(
          label: '${l10n.hard}\n(${l10n.discardAllChangesHard})',
          role: DialogActionRole.destructive,
          onPressed: () => Navigator.of(context).pop(ResetMode.hard),
        ),
      ],
    );
  }
}
