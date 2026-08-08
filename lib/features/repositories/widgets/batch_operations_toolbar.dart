import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Inset, Proximity, TextRole, Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_layout.dart';

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

    // The floating bar's margin is the distance between it and the screen
    // it hovers over - an inset owed by what surrounds the bar rather than a
    // fourth number inside it.
    return BaseInset(
      all: Inset.roomy,
      child: Container(
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
        child: BaseInset(
          x: Inset.roomy,
          y: Inset.normal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Selection count
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(AppTheme.radiusL),
                ),
                child: BaseInset(
                  x: Inset.normal,
                  y: Inset.tight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tone.onAccent for the same reason the words beside it
                      // take it: the pill behind both is painted with the
                      // accent by the application itself, three lines up. 16 is
                      // exactly the `compact` rung, so the mark does not change
                      // size.
                      //
                      // The Bold stroke does NOT survive, and that is measured
                      // rather than overlooked. It was unconditional here - one
                      // mark, no second state to tell apart - so it drew no
                      // distinction; the same check-square IS a state elsewhere
                      // (git_status_tree_view.dart:374, 481, where Bold means
                      // "staged"), and that is the case a weight has to be kept
                      // for. Recorded in test/shared/icons/
                      // icon_weight_census_test.dart.
                      BaseIcon(
                        IconRole.checkSquare,
                        scale: ControlScale.compact,
                        tone: Tone.onAccent,
                      ),
                      const BaseGap(Proximity.related),
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
              ),

              const BaseGap(Proximity.separate),

              // Clear selection button
              BaseIconButton(
                icon: IconRole.x,
                tooltip: l10n.clearSelection,
                onPressed: onClearSelection,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
