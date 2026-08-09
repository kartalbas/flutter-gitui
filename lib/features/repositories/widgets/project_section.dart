import 'package:flutter/material.dart';
import '../../../shared/components/base_animated_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Inset, Proximity, TextRole, Tone;
import 'package:riverpod/legacy.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_menu_item.dart';
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
        // Project header
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
                  // Color indicator
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

                  // Repository count
                  Container(
                    decoration: BoxDecoration(
                      color: isUnassigned
                          ? Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest
                          : project!.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusL),
                    ),
                    child: BaseInset(
                      x: Inset.normal,
                      y: Inset.tight,
                      child: BaseLabel(
                        '$repositoryCount',
                        role: TextRole.micro,
                        tone: isUnassigned
                            ? Tone.neutral
                            : Tone.series(project!.colorIndex),
                      ),
                    ),
                  ),

                  // Actions (only for projects, not unassigned)
                  if (!isUnassigned) ...[
                    const BaseGap(Proximity.related),
                    BasePopupMenuButton<String>(
                      // The overflow mark acts on this workspace, so it wears
                      // the workspace's own place in the skin's series like
                      // everything else in the header.
                      icon: BaseIcon(
                        IconRole.dotsThreeVertical,
                        tone: Tone.series(project!.colorIndex),
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: MenuItemContent(
                            icon: IconRole.pencil,
                            label: AppLocalizations.of(context)!.editProject,
                            scale: ControlScale.compact,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: MenuItemContent(
                            icon: IconRole.trash,
                            label: AppLocalizations.of(context)!.deleteProject,
                            scale: ControlScale.compact,
                            tone: Tone.danger,
                            // The tone above reaches the MARK only:
                            // `MenuItemContent` spends it on its `BaseIcon`
                            // and colours its words from a `Color?
                            // labelColor`. Dropping this half today would
                            // leave a destructive entry with a red glyph and
                            // black words - an appearance change inside a
                            // colour rename. It goes when the component's
                            // tone reaches its label, one edit in
                            // `lib/shared/components/base_menu_item.dart`.
                            labelColor: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            onEdit?.call();
                            break;
                          case 'delete':
                            onDelete?.call();
                            break;
                        }
                      },
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
