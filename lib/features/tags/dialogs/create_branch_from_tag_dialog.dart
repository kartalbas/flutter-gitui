import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_text_field.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_label.dart';

/// Dialog for creating a branch from a tag
class CreateBranchFromTagDialog extends StatefulWidget {
  final String tagName;

  const CreateBranchFromTagDialog({
    super.key,
    required this.tagName,
  });

  @override
  State<CreateBranchFromTagDialog> createState() => _CreateBranchFromTagDialogState();
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
      icon: PhosphorIconsRegular.gitBranch,
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
                      LabelSmallLabel(
                        l10n.sourceTag,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      BodyMediumLabel(widget.tagName),
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
            prefixIcon: PhosphorIconsRegular.gitBranch,
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
            title: BodyMediumLabel(l10n.checkoutBranchAfterCreation),
            subtitle: BodySmallLabel(
              l10n.checkoutBranchAfterCreationHint,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            contentPadding: EdgeInsets.zero,
            dense: true,
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
          label: l10n.createBranch,
          variant: ButtonVariant.primary,
          leadingIcon: PhosphorIconsRegular.gitBranch,
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
    Navigator.of(context).pop({
      'branchName': branchName,
      'checkout': _checkout,
    });
  }
}
