import 'package:flutter/material.dart';
import '../../../shared/components/base_animated_widgets.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Inset, Proximity, TextRole, Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
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

    // What the overflow menu offers, as language-neutral data. Built once and
    // closed over by both halves of the button, so the index `onSelected`
    // reports always addresses this same list.
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
      customBorderColor: project.color,
      customBackgroundColor: isSelected
          ? project.color.withValues(alpha: 0.1)
          : null,
      inset: Inset.normal,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with icon and menu
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: project.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: BaseInset(
                  all: Inset.normal,
                  child: Icon(
                    project.isDefaultWorkspace
                        ? PhosphorIconsBold.house
                        : PhosphorIconsBold.folder,
                    color: project.color,
                    size: AppTheme.iconL,
                  ),
                ),
              ),
              const Spacer(),
              // The menu is stated as DATA rather than hand-rolled, which is
              // what retires the last Material colour word on this card. The
              // destructive entry used to say its meaning twice - `Tone.danger`
              // for the mark and a spelled-out `colorScheme.error` for the
              // words - because `MenuItemContent` wears its tone on the mark
              // only and paints its label from a raw `Color?`. Deleting the
              // second half at the call site would have left a red glyph beside
              // black words, so the route out is the other one
              // `tag_list_tile.dart` names: `MenuActionRole.destructive`, from
              // which `materialMenuEntries` derives BOTH halves itself
              // (base_menu_item.dart:132-143). The application says what the
              // entry means; the one place that turns menu data into Material
              // widgets keeps answering how that looks.
              //
              // Nothing moves. Both entries already drew at `MenuItemContent`'s
              // default `compact` rung, which is what `materialMenuEntries`
              // builds, and the destructive tint is unchanged because this
              // entry only exists when `onDelete` is non-null - so it is always
              // enabled, and the disabled case where that function drops the
              // tint is unreachable here.
              BasePopupMenuButton<int>(
                // The overflow mark acts on this workspace, so it takes the
                // workspace's own place in the skin's series - the same word
                // the list row states for the workspace's name. The prominent
                // scale is what the bare mark drew under the ambient icon
                // theme.
                icon: BaseIcon(
                  IconRole.dotsThreeVertical,
                  tone: Tone.series(project.colorIndex),
                  scale: ControlScale.prominent,
                ),
                itemBuilder: (context) =>
                    materialMenuEntries(context, menuEntries),
                onSelected: (int index) =>
                    dispatchMenuEntry(menuEntries, index),
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
