import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        AvatarSpec,
        ControlScale,
        IconRole,
        Inset,
        MenuAnchorSpec,
        Overlays,
        Proximity,
        Skin,
        SkinScope,
        TextRole,
        Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_card.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_menu_item.dart';
import '../../../core/workspace/default_workspace_text.dart';
import '../../../core/workspace/models/workspace.dart';
import '../../../shared/components/base_layout.dart';

/// Workspace card widget for grid view
class WorkspaceCard extends StatelessWidget {
  final Workspace project;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  /// Whether the grid's roving highlight rests on this card.
  final bool isHighlighted;

  /// Whether the collection holding this card owns keyboard focus. Only the
  /// highlighted card wears the focus ring, and only while the collection is
  /// focused; the selected workspace keeps its tinted background without
  /// claiming the keyboard.
  final bool containerHasFocus;

  const WorkspaceCard({
    super.key,
    required this.project,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    this.onDelete,
    this.isHighlighted = false,
    this.containerHasFocus = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final description = project.displayDescription(l10n);

    // What the overflow menu offers, as language-neutral data - the
    // contract's own entries, so the anchor below hands them to the skin
    // without restatement.
    final List<MenuEntry> menuEntries = <MenuEntry>[
      MenuAction(label: l10n.edit, icon: IconRole.pencil, onPressed: onEdit),
      if (onDelete != null)
        MenuAction(
          label: l10n.delete,
          icon: IconRole.trash,
          onPressed: onDelete,
          role: MenuActionRole.destructive,
        ),
    ];

    return BaseCard(
      isSelected: isSelected || isHighlighted,
      // The focus ring belongs to the roving highlight alone; the selected
      // workspace keeps the muted tinted treatment.
      containerHasFocus: isHighlighted && containerHasFocus,
      onTap: onTap,
      // The workspace's own place in the skin's series, which is what the two
      // `Color`s that stood here were both spelling out: the card's border was
      // `project.color` and its selected fill the same colour at 10 %. The
      // card member draws both from this one word, from the SAME twelve
      // values, because `WorkspaceColors.defaults` and the skin's series
      // palette are the same list in the same order.
      //
      // One state DOES move under Material, deliberately: the RESTING card's
      // 1 px outline. The old `BaseCard` consulted `customBorderColor` only
      // in its focused-selection branch, so an unselected card wore the grey
      // `outlineVariant`; the member draws an identity-bearing card's outline
      // in its identity in every state, so every resting workspace card now
      // carries its own colour at 1 px. That is the member's considered
      // answer to "this card is ABOUT something", not a side effect - the
      // selected fill, the focused ring and the selection wash are unchanged.
      tone: Tone.series(project.colorIndex),
      inset: Inset.normal,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with icon and menu
          Row(
            children: [
              // The workspace's identity mark is `surfaces.avatar`, the member
              // whose own doc names this case: "`Tone.series(n)` is how a
              // per-object identity colour reaches it without the application
              // knowing which colour that is". The tile that stood here was
              // the application drawing an avatar by hand - a fill, a corner,
              // an inset and a glyph size - and every one of those is the
              // member's answer now. The FILL does not move: Material washes
              // the series colour onto the mark at 20 %, which is the exact
              // `alpha: 0.2` this container painted, and the mark keeps the
              // series colour itself.
              //
              // Three things about the picture do move, and each is the
              // member's decision rather than a side effect. The tile becomes
              // a CIRCLE, because that is what an avatar is in Material and
              // the corner was never something this card knew. It becomes 40
              // dp across instead of 56 (24 dp mark inside a 16 dp inset), and
              // the mark 20 dp instead of 24, because the member moves
              // diameter and glyph together off one `ControlScale` rung. And
              // the mark takes the ordinary stroke instead of Bold: the weight
              // was unconditional here - both branches of the ternary drew it
              // - so it distinguished nothing, and `IconRole` hands weight to
              // the skin by construction (#249 conflict C3).
              SkinScope.render(context, (Skin skin, BuildContext inner) {
                return skin.surfaces.avatar(
                  inner,
                  AvatarSpec(
                    glyph: project.isDefaultWorkspace
                        ? IconRole.house
                        : IconRole.folder,
                    tone: Tone.series(project.colorIndex),
                    scale: ControlScale.prominent,
                    semanticsLabel: project.displayName(l10n),
                  ),
                );
              }),
              const Spacer(),
              // The whole anchored pair - the trigger, its measured position
              // and the menu against it - is the SKIN's now, through
              // `overlays.menuAnchor`. This card used to build a Material
              // `PopupMenuButton`, render the entries itself through
              // `materialMenuEntries` and dispatch the chosen index back by
              // hand, which was the application performing skin geometry.
              // What the card still states is everything that is its own: the
              // trigger's meaning, the workspace's own place in the skin's
              // series, the prominent rung the bare mark drew at - and, new,
              // the name every mark-only control owes ("More actions"; the
              // hand-built anchor had no tooltip at all, which was a standing
              // violation of this repository's own rule).
              Overlays.anchor(
                spec: MenuAnchorSpec(
                  icon: IconRole.dotsThreeVertical,
                  tooltip: l10n.moreActions,
                  tone: Tone.series(project.colorIndex),
                  scale: ControlScale.prominent,
                ),
                entries: menuEntries,
              ),
            ],
          ),

          const BaseGap(Proximity.grouped),

          // Project name
          BaseLabel(
            project.displayName(l10n),
            role: TextRole.itemTitle,
            maxLines: 1,
          ),

          if (description != null) ...[
            const BaseGap(Proximity.related),
            BaseLabel(description, role: TextRole.body, maxLines: 2),
          ],

          const BaseGap(Proximity.grouped),

          // Repository count
          Row(
            children: [
              // The mark repeats what the count beside it says and is
              // secondary to it, at the dense scale this footer reads at.
              const BaseIcon(
                IconRole.gitCommit,
                scale: ControlScale.compact,
                tone: Tone.muted,
              ),
              const BaseGap(Proximity.related),
              BaseLabel(
                AppLocalizations.of(
                  context,
                )!.repositoriesCount(project.repositoryPaths.length),
                role: TextRole.detail,
                tone: Tone.muted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
