import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_text_field.dart';
import '../../../core/git/models/branch.dart';

/// Dialog for renaming a branch
class RenameBranchDialog extends StatefulWidget {
  final GitBranch branch;

  const RenameBranchDialog({
    super.key,
    required this.branch,
  });

  @override
  State<RenameBranchDialog> createState() => _RenameBranchDialogState();
}

class _RenameBranchDialogState extends State<RenameBranchDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.branch.shortName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Don't allow renaming protected branches
    if (widget.branch.isProtected) {
      return BaseDialog(
        title: l10n.renameBranch(widget.branch.shortName),
        icon: PhosphorIconsRegular.lock,
        variant: DialogVariant.normal,
        content: const Text(
          'Cannot rename protected branch. This branch is protected from being renamed.',
        ),
      );
    }

    return BaseDialog(
      title: l10n.renameBranch(widget.branch.shortName),
      icon: PhosphorIconsRegular.pencil,
      variant: DialogVariant.normal,
      content: Form(
        key: _formKey,
        child: BaseTextField(
          controller: _controller,
          autofocus: true,
          label: l10n.newBranchName,
          prefixIcon: PhosphorIconsRegular.pencil,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return l10n.enterBranchName;
            }
            return null;
          },
        ),
      ),
      actions: [
        BaseButton(
          label: l10n.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        BaseButton(
          label: l10n.rename,
          variant: ButtonVariant.primary,
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_controller.text.trim());
            }
          },
        ),
      ],
    );
  }
}
