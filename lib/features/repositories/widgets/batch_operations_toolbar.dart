import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, TextRole, Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_button.dart';

/// Toolbar for batch operations on selected repositories
class BatchOperationsToolbar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onClearSelection;

  const BatchOperationsToolbar({
    super.key,
    required this.selectedCount,
    required this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.all(AppTheme.paddingL),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.paddingL,
        vertical: AppTheme.paddingM,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selection count
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.paddingM,
              vertical: AppTheme.paddingS,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  PhosphorIconsBold.checkSquare,
                  size: 16,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                const SizedBox(width: AppTheme.paddingS),
                // Tone.onAccent, not a dropped override: the count pill
                // behind this text is painted with the accent by the
                // application itself, which is the exact case the tone's doc
                // names. It leaves with the pill when the badge surface
                // migrates.
                BaseLabel(
                  l10n.repositoriesSelected(selectedCount),
                  role: TextRole.emphasis,
                  tone: Tone.onAccent,
                ),
              ],
            ),
          ),

          const SizedBox(width: AppTheme.paddingL),

          // Clear selection button
          BaseIconButton(
            icon: IconRole.x,
            tooltip: l10n.clearSelection,
            onPressed: onClearSelection,
          ),
        ],
      ),
    );
  }
}
