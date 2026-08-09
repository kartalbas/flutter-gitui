import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show BadgeSpec, IconRole, Inset, Proximity, Skin, SkinScope, Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
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
    // Nothing in this `BoxDecoration` converts, and none of it is an
    // oversight: a fill, a shadow and a 1 px stroke are what a SURFACE is made
    // of, and a surface leaves whole when the floating bar becomes its own
    // member. `Tone` says what a mark or a word MEANS and is only ever read
    // back inside a skin, so the application cannot resolve one into the
    // `Color` a `BoxDecoration` demands - the seam is right to forbid that.
    // The two marks and the two labels inside the bar have already crossed;
    // the box they sit in has not.
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
              // Selection count: "how many, riding on something else", which
              // is `surfaces.badge` in the member's own words. The pill the
              // bar was painting - the accent fill, the corner and both
              // insets - is the member's geometry now, and so are the mark's
              // size and the gap between mark and words.
              //
              // `Tone.onAccent` leaves with the fill, exactly as the two notes
              // that stood here predicted: it was truthful only while the
              // APPLICATION painted the accent behind the words, and it is the
              // skin that paints the pill now. What the bar states instead is
              // that the count MEANS the accent, and Material answers that
              // with its own badge treatment - the accent washed to 15 %
              // behind an accent-coloured mark and label, where the pill used
              // to be solid `primary` under `onPrimary`. Quieter, and it is
              // the same pill every other badge in the application draws.
              //
              // The Bold stroke does NOT survive, and that is measured rather
              // than overlooked. It was unconditional here - one mark, no
              // second state to tell apart - so it drew no distinction; the
              // same check-square IS a state elsewhere
              // (git_status_tree_view.dart:374, 481, where Bold means
              // "staged"), and that is the case a weight has to be kept for.
              // Recorded in test/shared/icons/icon_weight_census_test.dart.
              SkinScope.render(context, (Skin skin, BuildContext inner) {
                return skin.surfaces.badge(
                  inner,
                  BadgeSpec(
                    label: l10n.repositoriesSelected(selectedCount),
                    icon: IconRole.checkSquare,
                    tone: Tone.accent,
                  ),
                );
              }),

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
