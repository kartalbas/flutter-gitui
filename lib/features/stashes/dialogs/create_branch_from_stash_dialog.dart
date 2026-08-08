import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show IconRole;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_text_field.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_label.dart';
import '../../../core/git/models/stash.dart';

/// Dialog for creating a branch from a stash
class CreateBranchFromStashDialog extends StatefulWidget {
  final GitStash stash;

  const CreateBranchFromStashDialog({super.key, required this.stash});

  @override
  State<CreateBranchFromStashDialog> createState() =>
      _CreateBranchFromStashDialogState();
}

class _CreateBranchFromStashDialogState
    extends State<CreateBranchFromStashDialog> {
  late final TextEditingController _branchNameController;

  @override
  void initState() {
    super.initState();
    _branchNameController = TextEditingController(
      text: 'stash-${widget.stash.index}',
    );
  }

  @override
  void dispose() {
    _branchNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BaseDialog(
      title: l10n.createBranchFromStash,
      icon: IconRole.gitBranch,
      variant: DialogVariant.normal,
      onSubmit: () => Navigator.of(context).pop(_branchNameController.text),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BodyMediumLabel(
            l10n.createBranchFromStashDescription(widget.stash.ref),
          ),
          const SizedBox(height: AppTheme.paddingM),
          BaseTextField(
            controller: _branchNameController,
            label: l10n.branchNameLabel,
            autofocus: true,
          ),
        ],
      ),
      actions: [
        DialogAction(
          label: l10n.cancel,
          role: DialogActionRole.dismissive,
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(
          label: l10n.create,
          role: DialogActionRole.affirmative,
          onPressed: () =>
              Navigator.of(context).pop(_branchNameController.text),
        ),
      ],
    );
  }
}
