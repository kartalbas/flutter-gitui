import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_dialog.dart';
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
      // Clear, Cancel, Search: the order advanced_search_dialog.dart already
      // uses, with the affirmative action last as M3 arranges it.
      //
      // Applying the filter used to have no button at all: it existed only as
      // onSubmit above, so the row showed no way to complete the dialog and
      // Enter was a shortcut standing in for the action itself. It is now the
      // dialog's one affirmative action, and Enter still fires the same
      // callback.
      //
      // Clear stays neutral, not dismissive, because it leaves the dialog
      // *with a result*: it pops '', the caller drops its filter, and the
      // branch list changes. Escape and Cancel pop null and the caller keeps
      // whatever filter it had. Those are two materially different outcomes,
      // and dismissive is defined as the one Escape is the keyboard
      // equivalent of - so only one of them can hold it, or a skin
      // implementing that rule has two candidates to bind Escape to and may
      // pick the one that wipes the user's filter. Neutral's first clause,
      // "a second way forward that is not *the* way forward", is what Clear
      // is; AdvancedFiltersDialog's Reset all is the same shape and already
      // carries the same role.
      actions: [
        DialogAction(
          label: l10n.clear,
          role: DialogActionRole.neutral,
          onPressed: () => Navigator.of(context).pop(''),
        ),
        DialogAction(
          label: l10n.cancel,
          role: DialogActionRole.dismissive,
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(
          label: l10n.search,
          role: DialogActionRole.affirmative,
          onPressed: _apply,
        ),
      ],
    );
  }
}
