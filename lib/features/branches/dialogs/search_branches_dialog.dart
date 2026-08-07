import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_text_field.dart';

/// Dialog for searching branches by name.
///
/// Returns the typed query, an empty string when the filter is cleared, and
/// null when the dialog is cancelled.
class SearchBranchesDialog extends StatefulWidget {
  const SearchBranchesDialog({super.key});

  @override
  State<SearchBranchesDialog> createState() => _SearchBranchesDialogState();
}

class _SearchBranchesDialogState extends State<SearchBranchesDialog> {
  final _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _apply() => Navigator.of(context).pop(_queryController.text);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BaseDialog(
      title: l10n.searchBranchesDialog,
      icon: PhosphorIconsRegular.magnifyingGlass,
      variant: DialogVariant.normal,
      // Enter applies the filter from anywhere in the dialog. The field's own
      // onSubmitted used to be the only path, so Enter died the moment focus
      // moved off the field - to the Clear button, to the close X - which is
      // exactly the "from anywhere" half of the contract.
      onSubmit: _apply,
      content: BaseTextField(
        controller: _queryController,
        autofocus: true,
        hintText: l10n.branchName,
        prefixIcon: PhosphorIconsRegular.magnifyingGlass,
        onSubmitted: (_) => _apply(),
      ),
      actions: [
        BaseButton(
          label: l10n.clear,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(''),
        ),
        BaseButton(
          label: l10n.cancel,
          variant: ButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
