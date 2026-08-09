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
              BasePopupMenuButton<String>(
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
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: MenuItemContent(
                      icon: IconRole.pencil,
                      label: AppLocalizations.of(context)!.edit,
                    ),
                  ),
                  if (onDelete != null)
                    PopupMenuItem(
                      value: 'delete',
                      child: MenuItemContent(
                        icon: IconRole.trash,
                        label: AppLocalizations.of(context)!.delete,
                        tone: Tone.danger,
                        // The tone above reaches the MARK only:
                        // `MenuItemContent` spends it on its `BaseIcon` and
                        // colours its words from a `Color? labelColor`.
                        // Dropping this half today would leave a destructive
                        // entry with a red glyph and black words - an
                        // appearance change inside a colour rename. It goes
                        // when the component's tone reaches its label, one
                        // edit in `lib/shared/components/base_menu_item.dart`.
                        labelColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                      break;
                    case 'delete':
                      onDelete?.call();
                      break;
                  }
                },
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
