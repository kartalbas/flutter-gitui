import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_theme.dart';
import '../../generated/app_localizations.dart';
import '../components/base_label.dart';
import '../components/base_button.dart';

/// Standardized batch operations bar for multi-selection
///
/// Appears at bottom of screen when items are selected.
/// Provides consistent UI for batch operations across all screens.
///
/// Example usage:
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   return Scaffold(
///     appBar: AppBar(title: Text('Tags')),
///     body: _buildTagList(),
///     bottomNavigationBar: _selectedTags.isNotEmpty
///         ? BatchOperationsBar(
///             selectedCount: _selectedTags.length,
///             onClear: () => setState(() => _selectedTags.clear()),
///             actions: [
///               BatchAction(
///                 label: l10n.push,
///                 icon: PhosphorIconsRegular.upload,
///                 onPressed: () => _pushSelectedTags(),
///                 enabled: _canPushSelected(),
///               ),
///               BatchAction(
///                 label: l10n.delete,
///                 icon: PhosphorIconsRegular.trash,
///                 onPressed: () => _deleteSelectedTags(),
///                 isDestructive: true,
///               ),
///             ],
///           )
///         : null,
///   );
/// }
/// ```
class BatchOperationsBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onClear;
  final List<BatchAction> actions;

  const BatchOperationsBar({
    super.key,
    required this.selectedCount,
    required this.onClear,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingM),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Selected count
            Icon(
              PhosphorIconsRegular.checkSquare,
              size: 20,
              color: colorScheme.primary,
            ),
            const SizedBox(width: AppTheme.paddingS),
            BaseLabel(
              l10n.selectedCount(selectedCount),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              color: colorScheme.primary,
            ),

            const Spacer(),

            // Action buttons
            ...actions.map((action) {
              if (action.isDestructive) {
                return Padding(
                  padding: const EdgeInsets.only(left: AppTheme.paddingS),
                  child: BaseButton(
                    label: action.label,
                    variant: ButtonVariant.dangerSecondary,
                    leadingIcon: action.icon,
                    onPressed: action.enabled ? action.onPressed : null,
                  ),
                );
              } else {
                return Padding(
                  padding: const EdgeInsets.only(left: AppTheme.paddingS),
                  child: BaseButton(
                    label: action.label,
                    variant: ButtonVariant.secondary,
                    leadingIcon: action.icon,
                    onPressed: action.enabled ? action.onPressed : null,
                  ),
                );
              }
            }),

            const SizedBox(width: AppTheme.paddingS),

            // Clear selection
            BaseButton(
              label: l10n.clearSelection,
              variant: ButtonVariant.tertiary,
              leadingIcon: PhosphorIconsRegular.x,
              onPressed: onClear,
            ),
          ],
        ),
      ),
    );
  }
}

/// Represents a single batch action button
class BatchAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;
  final bool isDestructive;

  const BatchAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
    this.isDestructive = false,
  });
}
