import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_text_field.dart';

/// Dialog for searching branches by name
class SearchBranchesDialog extends StatelessWidget {
  const SearchBranchesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BaseDialog(
      title: l10n.searchBranchesDialog,
      icon: PhosphorIconsRegular.magnifyingGlass,
      variant: DialogVariant.normal,
      content: BaseTextField(
        autofocus: true,
        hintText: l10n.branchName,
        prefixIcon: PhosphorIconsRegular.magnifyingGlass,
        onSubmitted: (value) => Navigator.of(context).pop(value),
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
