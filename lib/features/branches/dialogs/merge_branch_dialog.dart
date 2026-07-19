import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_label.dart';
import '../../../core/git/models/branch.dart';
import '../../../core/git/git_providers.dart';

/// Dialog to confirm merging a branch into the current branch
class MergeBranchDialog extends ConsumerWidget {
  final GitBranch branch;

  const MergeBranchDialog({super.key, required this.branch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // Name the branch that actually receives the merge. Passing the literal
    // 'current' showed the untranslated English word as the target.
    final targetBranch = ref.watch(currentBranchProvider).value ?? 'HEAD';

    return BaseDialog(
      title: l10n.mergeBranchDialog,
      icon: PhosphorIconsRegular.gitMerge,
      variant: DialogVariant.confirmation,
      content: BodyMediumLabel(
        l10n.mergeBranchConfirm(branch.shortName, targetBranch),
      ),
      actions: [
        BaseButton(
          label: l10n.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        BaseButton(
          label: l10n.merge,
          variant: ButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
