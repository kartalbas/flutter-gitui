import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, TextRole, Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_text_field.dart';
import '../../../shared/components/base_label.dart';

/// Dialog for creating a branch from a tag
class CreateBranchFromTagDialog extends StatefulWidget {
  final String tagName;

  const CreateBranchFromTagDialog({super.key, required this.tagName});

  @override
  State<CreateBranchFromTagDialog> createState() =>
      _CreateBranchFromTagDialogState();
}

class _CreateBranchFromTagDialogState extends State<CreateBranchFromTagDialog> {
  late TextEditingController _branchNameController;
  bool _checkout = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _branchNameController = TextEditingController();
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
      title: l10n.createBranchFromTag,
      icon: IconRole.gitBranch,
      onSubmit: _createBranch,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag info
          Container(
            padding: const EdgeInsets.all(AppTheme.paddingM),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: Row(
              children: [
                Icon(
                  PhosphorIconsRegular.tag,
                  size: AppTheme.iconS,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppTheme.paddingS),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BaseLabel(
                        l10n.sourceTag,
                        role: TextRole.micro,
                        tone: Tone.muted,
                      ),
                      BaseLabel(widget.tagName, role: TextRole.body),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.paddingL),

          // Branch name input
          BaseTextField(
            controller: _branchNameController,
            label: l10n.branchName,
            hintText: l10n.branchNameHint,
            prefixIcon: IconRole.gitBranch,
            autofocus: true,
            errorText: _errorMessage,
            onChanged: (value) {
              setState(() {
                _errorMessage = null;
              });
            },
          ),
          const SizedBox(height: AppTheme.paddingM),

          // Checkout option
          CheckboxListTile(
            value: _checkout,
            onChanged: (value) {
              setState(() {
                _checkout = value ?? true;
              });
            },
            title: BaseLabel(
              l10n.checkoutBranchAfterCreation,
              role: TextRole.body,
            ),
            subtitle: BaseLabel(
              l10n.checkoutBranchAfterCreationHint,
              role: TextRole.detail,
              tone: Tone.muted,
            ),
            contentPadding: EdgeInsets.zero,
            dense: true,
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
          label: l10n.createBranch,
          role: DialogActionRole.affirmative,
          icon: IconRole.gitBranch,
          onPressed: _createBranch,
        ),
      ],
    );
  }

  void _createBranch() {
    final branchName = _branchNameController.text.trim();
    final l10n = AppLocalizations.of(context)!;

    if (branchName.isEmpty) {
      setState(() {
        _errorMessage = l10n.branchNameRequired;
      });
      return;
    }

    // Return the result
    Navigator.of(
      context,
    ).pop({'branchName': branchName, 'checkout': _checkout});
  }
}
