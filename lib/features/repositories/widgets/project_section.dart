import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        BadgeSpec,
        IconRole,
        Inset,
        MenuAction,
        MenuActionRole,
        MenuAnchorSpec,
        MenuEntry,
        Overlays,
        Proximity,
        Skin,
        SkinScope,
        TextRole,
        Tone;
import 'package:riverpod/legacy.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_label.dart';
import '../../../core/workspace/default_workspace_text.dart';
import '../../../core/workspace/models/workspace.dart';
import '../../../shared/components/base_layout.dart';

/// Provider for tracking expanded state of projects
final projectExpandedProvider = StateProvider.family<bool, String>(
  (ref, projectId) => true,
);

/// Section header for a project group
class ProjectSection extends ConsumerWidget {
  final Workspace? project; // null for "Unassigned"
  final int repositoryCount;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Widget child;

  const ProjectSection({
    super.key,
    this.project,
    required this.repositoryCount,
    this.onEdit,
    this.onDelete,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUnassigned = project == null;
    final projectId = project?.id ?? 'unassigned';
    final isExpanded = ref.watch(projectExpandedProvider(projectId));
    final l10n = AppLocalizations.of(context)!;
    final description = project?.displayDescription(l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Project header. NOT converted, and reported as a contract finding
        // rather than rounded onto the nearest member.
        //
        // What this is, is `surfaces.disclosure`: a header the user presses to
        // see more of something. What it also is, is the one place the
        // workspace's own colour states which workspace this whole group
        // belongs to - a 10 % wash of it behind the header and a 30 % edge
        // around it - and `DisclosureSpec` carries no tone at all, by an
        // explicit decision recorded on `DisclosureSpec.leading`. The obvious
        // escape, wrapping the disclosure in a `surfaces.card` carrying
        // `Tone.series(n)` the way the settings sections wrap theirs, does not
        // reach it either: the Material card paints an identity tint only
        // while the card is SELECTED (material_surfaces.dart, `backgroundColor`)
        // and a resting one keeps `surfaceContainerHigh` with the identity in
        // its 1 px outline, so the wash would simply be gone.
        //
        // So the press target, the fill, the edge and both corners stay here
        // until a member can say "this expandable region is ABOUT something".
        InkWell(
          onTap: () {
            ref.read(projectExpandedProvider(projectId).notifier).state =
                !isExpanded;
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          child: Container(
            decoration: BoxDecoration(
              color: isUnassigned
                  ? Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                  : project!.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(
                color: isUnassigned
                    ? Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.3)
                    : project!.color.withValues(alpha: 0.3),
              ),
            ),
            child: BaseInset(
              x: Inset.roomy,
              y: Inset.normal,
              child: Row(
                children: [
                  // Colour indicator. NOT converted, and reported with the
                  // header above: a 4 by 32 bar of the workspace's own colour
                  // is not a mark (`surfaces.avatar` is one glyph or one
                  // monogram inside a shape the skin owns), not a count
                  // (`surfaces.badge`) and not a removable pill
                  // (`surfaces.tag`). No member draws "a rule in this object's
                  // identity colour", and the same shape stands a second time
                  // in `project_dialog.dart`'s preview at 4 by 16, so it is a
                  // pattern rather than a one-off.
                  Container(
                    width: 4,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isUnassigned
                          ? Theme.of(context).colorScheme.outline
                          : project!.color,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                    ),
                  ),
                  const BaseGap(Proximity.grouped),

                  // Expand/Collapse icon. It belongs to the workspace whose
                  // header it opens, so it takes that workspace's place in the
                  // skin's series - the same word the name and the count below
                  // already use - and the ordinary foreground where there is no
                  // workspace to belong to.
                  BaseIcon(
                    isExpanded ? IconRole.caretDown : IconRole.caretRight,
                    tone: isUnassigned
                        ? Tone.neutral
                        : Tone.series(project!.colorIndex),
                  ),
                  const BaseGap(Proximity.related),

                  // Project icon. NOT converted, and the review put it back
                  // after a conversion shipped two visible changes inside a
                  // colour rename. First, the Bold stroke: this is a section
                  // header's mark beside a `sectionTitle` label - the weight
                  // is the header's prominence, not a state the glyph ternary
                  // distinguishes, and `IconRole` re-decides weight inside the
                  // skin (conflict C3), so converting drops it silently.
                  // Second, the unassigned branch's colour: `Tone.neutral`
                  // does not resolve to the `onSurface` written here - for a
                  // mark it means "take the ambient IconTheme"
                  // (material_type.dart:168), and no theme in this application
                  // sets one, so it lands on Flutter's own black87/white
                  // default, which is measurably not the scheme's foreground.
                  // Until the ambient icon colour is the skin's answer, an
                  // explicit `onSurface` is a meaning the vocabulary cannot
                  // say about a bare mark. The assigned branch's
                  // `project!.color` leaves with the swatch palette when
                  // `controls.seriesPicker` lands in P5; the mark converts as
                  // one piece then.
                  Icon(
                    isUnassigned
                        ? PhosphorIconsBold.package
                        : PhosphorIconsBold.folder,
                    size: AppTheme.iconM,
                    color: isUnassigned
                        ? Theme.of(context).colorScheme.onSurface
                        : project!.color,
                  ),
                  const BaseGap(Proximity.grouped),

                  // Project name and description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BaseLabel(
                          isUnassigned
                              ? l10n.unassignedRepositories
                              : project!.displayName(l10n),
                          role: TextRole.sectionTitle,
                          tone: isUnassigned
                              ? Tone.neutral
                              : Tone.series(project!.colorIndex),
                        ),
                        if (!isUnassigned && description != null) ...{
                          const BaseGap(Proximity.hairline),
                          BaseLabel(
                            description,
                            role: TextRole.detail,
                            tone: Tone.muted,
                            maxLines: 1,
                          ),
                        },
                      ],
                    ),
                  ),

                  // How many repositories this workspace holds: a count riding
                  // on the header it names, which is `surfaces.badge` down to
                  // the word. The pill it was hand-painting is the member's
                  // whole geometry now - the fill, the corner and the two
                  // insets - and the tone it already carried is the only thing
                  // the header still states about it.
                  //
                  // The unassigned branch does not move a pixel: `Tone.neutral`
                  // IS the `surfaceContainerHighest` chip on `onSurface` that
                  // this container painted by hand (material_surfaces.dart's
                  // `_pill`). The workspace branch's fill goes from the series
                  // colour at 20 % to the member's 15 %, which is the wash
                  // every other badge in the application already draws at and
                  // the one `git_colors_contrast_test.dart` measures. The pill
                  // also loses 8 dp of height (the member's `normal` rung sets
                  // 4 dp above and below where `Inset.tight` resolved to 8),
                  // and the count is set at the badge's own 12 px rather than
                  // at `micro` - a badge is nearly a symbol, and its type is
                  // part of what the member owns.
                  SkinScope.render(context, (Skin skin, BuildContext inner) {
                    return skin.surfaces.badge(
                      inner,
                      BadgeSpec(
                        label: '$repositoryCount',
                        tone: isUnassigned
                            ? Tone.neutral
                            : Tone.series(project!.colorIndex),
                      ),
                    );
                  }),

                  // Actions (only for projects, not unassigned)
                  if (!isUnassigned) ...[
                    const BaseGap(Proximity.related),
                    // The anchored pair is the skin's: it builds the
                    // trigger, measures it and opens the menu against it.
                    // The overflow mark acts on this workspace, so it wears
                    // the workspace's own place in the skin's series like
                    // everything else in the header - which `MenuAnchorSpec`
                    // carries as a tone, and the anchor now also carries the
                    // name every mark-only control owes; the hand-built one
                    // had none at all.
                    Overlays.anchor(
                      spec: MenuAnchorSpec(
                        icon: IconRole.dotsThreeVertical,
                        tooltip: AppLocalizations.of(context)!.moreActions,
                        tone: Tone.series(project!.colorIndex),
                      ),
                      entries: <MenuEntry>[
                        MenuAction(
                          icon: IconRole.pencil,
                          label: AppLocalizations.of(context)!.editProject,
                          onPressed: onEdit,
                        ),
                        // Its ROLE says it destroys something; how a
                        // destructive row reads is the skin's answer.
                        MenuAction(
                          icon: IconRole.trash,
                          label: AppLocalizations.of(context)!.deleteProject,
                          role: MenuActionRole.destructive,
                          onPressed: onDelete,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Repositories (shown when expanded)
        if (isExpanded) ...[const BaseGap(Proximity.related), child],
        const BaseGap(Proximity.grouped),
      ],
    );
  }
}
