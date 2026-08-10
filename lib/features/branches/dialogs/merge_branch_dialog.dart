import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show IconRole, TextRole;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_dialog.dart';
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
      icon: IconRole.gitMerge,
      variant: DialogVariant.confirmation,
      onSubmit: () => Navigator.of(context).pop(true),
      content: BaseLabel(
        l10n.mergeBranchConfirm(branch.shortName, targetBranch),
        role: TextRole.body,
      ),
      actions: [
        DialogAction(
          label: l10n.cancel,
          role: DialogActionRole.dismissive,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        DialogAction(
          label: l10n.merge,
          role: DialogActionRole.affirmative,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
