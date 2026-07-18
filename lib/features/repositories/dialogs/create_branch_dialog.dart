import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_text_field.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_list_item.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_filter_chip.dart';
import '../../../core/workspace/models/workspace_repository.dart';
import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_menu_item.dart';

/// Branch prefix options
enum BranchPrefix {
  none('', 'No prefix'),
  feature('feature/', 'Feature'),
  release('release/', 'Release'),
  hotfix('hotfix/', 'Hotfix'),
  bugfix('bugfix/', 'Bugfix'),
  custom('', 'Custom');

  final String prefix;
  final String label;

  const BranchPrefix(this.prefix, this.label);
}

/// Result of the create branch dialog
class CreateBranchDialogResult {
  final String branchName;
  final String prefix;
  final bool setUpstream;
  final bool checkout;

  const CreateBranchDialogResult({
    required this.branchName,
    required this.prefix,
    required this.setUpstream,
    required this.checkout,
  });

  String get fullBranchName => prefix.isEmpty ? branchName : '$prefix$branchName';
}

/// Dialog for creating a branch across multiple repositories
Future<CreateBranchDialogResult?> showCreateBranchDialog(
  BuildContext context, {
  required List<WorkspaceRepository> repositories,
}) {
  return showDialog<CreateBranchDialogResult>(
    context: context,
    builder: (context) => _CreateBranchDialog(repositories: repositories),
  );
}

class _CreateBranchDialog extends StatefulWidget {
  final List<WorkspaceRepository> repositories;

  const _CreateBranchDialog({required this.repositories});

  @override
  State<_CreateBranchDialog> createState() => _CreateBranchDialogState();
}

class _CreateBranchDialogState extends State<_CreateBranchDialog> {
  late TextEditingController _branchNameController;
  late TextEditingController _customPrefixController;
  BranchPrefix _selectedPrefix = BranchPrefix.feature;
  bool _setUpstream = true;
  bool _checkout = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _branchNameController = TextEditingController();
    _customPrefixController = TextEditingController();

    // Listen to text changes to clear errors and update preview
    _branchNameController.addListener(_onTextChanged);
    _customPrefixController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _branchNameController.dispose();
    _customPrefixController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      // Clear error message if present
      if (_errorMessage != null) {
        _errorMessage = null;
      }
      // Trigger rebuild to update full branch name preview
    });
  }

  String _getCurrentPrefix() {
    if (_selectedPrefix == BranchPrefix.custom) {
      return _customPrefixController.text.trim();
    }
    return _selectedPrefix.prefix;
  }

  String _getFullBranchName() {
    final branchName = _branchNameController.text.trim();
    final prefix = _getCurrentPrefix();
    return prefix.isEmpty ? branchName : '$prefix$branchName';
  }

  String _getPrefixLabel(AppLocalizations l10n, BranchPrefix prefix) {
    switch (prefix) {
      case BranchPrefix.none:
        return l10n.noPrefix;
      case BranchPrefix.feature:
        return l10n.featurePrefix;
      case BranchPrefix.release:
        return l10n.releasePrefix;
      case BranchPrefix.hotfix:
        return l10n.hotfixPrefix;
      case BranchPrefix.bugfix:
        return l10n.bugfixPrefix;
      case BranchPrefix.custom:
        return l10n.customPrefix;
    }
  }

  void _createBranch() {
    final l10n = AppLocalizations.of(context)!;
    final branchName = _branchNameController.text.trim();

    if (branchName.isEmpty) {
      setState(() {
        _errorMessage = l10n.branchNameCannotBeEmpty;
      });
      return;
    }

    // Validate branch name (no spaces, special chars)
    final validBranchName = RegExp(r'^[a-zA-Z0-9_\-\.]+$');
    if (!validBranchName.hasMatch(branchName)) {
      setState(() {
        _errorMessage = l10n.branchNameInvalidCharacters;
      });
      return;
    }

    // Validate custom prefix if selected
    if (_selectedPrefix == BranchPrefix.custom) {
      final customPrefix = _customPrefixController.text.trim();
      if (customPrefix.isNotEmpty && !customPrefix.endsWith('/')) {
        setState(() {
          _errorMessage = l10n.customPrefixMustEndWithSlash;
        });
        return;
      }
    }

    Navigator.of(context).pop(CreateBranchDialogResult(
      branchName: branchName,
      prefix: _getCurrentPrefix(),
      setUpstream: _setUpstream,
      checkout: _checkout,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fullBranchName = _getFullBranchName();

    return BaseDialog(
      title: l10n.createBranchDialogTitle,
      icon: PhosphorIconsRegular.gitBranch,
      variant: DialogVariant.normal,
      maxWidth: 600,
      content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(AppTheme.paddingM),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIconsRegular.warningCircle,
                      color: Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.paddingM),
                    Expanded(
                      child: MenuItemLabel(
                        _errorMessage!,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.paddingM),
            ],

            // Branch prefix selector
            TitleSmallLabel(
              l10n.branchPrefixLabel,
            ),
            const SizedBox(height: AppTheme.paddingS),

            Wrap(
              spacing: AppTheme.paddingS,
              runSpacing: AppTheme.paddingS,
              children: BranchPrefix.values.map((prefix) {
                final isSelected = _selectedPrefix == prefix;
                return BaseChoiceChip(
                  label: _getPrefixLabel(l10n, prefix),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedPrefix = prefix;
                      });
                    }
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: AppTheme.paddingM),

            // Custom prefix input (only shown when custom is selected)
            if (_selectedPrefix == BranchPrefix.custom) ...[
              BaseTextField(
                controller: _customPrefixController,
                label: l10n.customPrefixLabel,
                hintText: l10n.customPrefixHint,
                helperText: l10n.customPrefixHelper,
              ),
              const SizedBox(height: AppTheme.paddingM),
            ],

            // Branch name input
            BaseTextField(
              controller: _branchNameController,
              label: l10n.branchNameLabel,
              hintText: l10n.branchNameHint,
              autofocus: true,
              onSubmitted: (_) => _createBranch(),
            ),

            const SizedBox(height: AppTheme.paddingM),

            // Full branch name preview
            Container(
              padding: const EdgeInsets.all(AppTheme.paddingM),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LabelSmallLabel(
                    l10n.fullBranchNameLabel,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppTheme.paddingXS),
                  TitleMediumLabel(
                    fullBranchName.isEmpty ? l10n.enterBranchNameLabel : fullBranchName,
                    color: fullBranchName.isEmpty
                        ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                        : Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.paddingL),

            // Repository list
            TitleSmallLabel(
              l10n.willCreateInRepositories(widget.repositories.length, widget.repositories.length == 1 ? l10n.repository : '${l10n.repository}ies', widget.repositories.length),
            ),
            const SizedBox(height: AppTheme.paddingS),

            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.repositories.length,
                itemBuilder: (context, index) {
                  final repo = widget.repositories[index];
                  return BaseListItem(
                    leading: Icon(
                      PhosphorIconsRegular.folderSimple,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    content: BodyMediumLabel(
                      repo.displayName,
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: AppTheme.paddingL),

            // Options
            CheckboxListTile(
              value: _setUpstream,
              onChanged: (value) {
                setState(() {
                  _setUpstream = value ?? false;
                });
              },
              title: BodyMediumLabel(l10n.setUpstreamLabel),
              subtitle: BodySmallLabel(l10n.setUpstreamDescription),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            ),

            CheckboxListTile(
              value: _checkout,
              onChanged: (value) {
                setState(() {
                  _checkout = value ?? false;
                });
              },
              title: BodyMediumLabel(l10n.checkoutAfterCreationLabel),
              subtitle: BodySmallLabel(l10n.checkoutAfterCreationDescription),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
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
          label: l10n.createBranchButton,
          variant: ButtonVariant.primary,
          onPressed: _createBranch,
        ),
      ],
    );
  }
}
