import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, Inset, Proximity, TextRole, Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_list_item.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_button.dart';
import '../../../core/workspace/default_workspace_text.dart';
import '../../../core/workspace/models/workspace.dart';
import '../../../shared/components/base_layout.dart';

/// List item widget displaying a workspace in a compact row format
class WorkspaceListItem extends StatelessWidget {
  final Workspace project;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  /// Whether the list's roving highlight rests on this row.
  final bool isHighlighted;

  /// Whether the collection holding this row owns keyboard focus. Only the
  /// highlighted row wears the focus ring, and only while the collection is
  /// focused; the selected workspace keeps its tinted background without
  /// claiming the keyboard.
  final bool containerHasFocus;

  const WorkspaceListItem({
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

    return BaseListItem(
      isSelected: isSelected || isHighlighted,
      // The focus ring belongs to the roving highlight alone; the selected
      // workspace keeps the muted tinted treatment.
      containerHasFocus: isHighlighted && containerHasFocus,
      onTap: onTap,
      leading: Container(
        decoration: BoxDecoration(
          color: project.color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
        ),
        child: BaseInset(
          all: Inset.tight,
          child: Icon(
            project.isDefaultWorkspace
                ? PhosphorIconsBold.house
                : PhosphorIconsBold.folder,
            color: project.color,
            size: AppTheme.iconL,
          ),
        ),
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Workspace name
          BaseLabel(
            project.displayName(l10n),
            role: TextRole.itemTitle,
            tone: Tone.series(project.colorIndex),
            maxLines: 1,
          ),

          // Description
          if (description != null) ...[
            const BaseGap(Proximity.hairline),
            BaseLabel(description, role: TextRole.detail, maxLines: 1),
          ],

          const BaseGap(Proximity.hairline),

          // Repository count
          Row(
            children: [
              // The colour is gone rather than translated, which is the repair
              // repository_list_item.dart:280-285 already made for the same
              // kind of glyph. `BaseListItem` publishes an `IconTheme` for the
              // whole row (base_list_item.dart:340) whose colour IS
              // `onSurfaceVariant`, dropping to a readable fallback on a
              // selected tile where the plain role measures 2.86 : 1 - so
              // spelling the role out again changed nothing on an unselected
              // row and overpainted the correction on a selected one. It is
              // not a `BaseIcon` either: `AppTheme.iconXS` is 12 dp and
              // `ControlScale`'s smallest rung is 16, so naming `compact`
              // would grow this inline mark by a third.
              Icon(PhosphorIconsRegular.gitCommit, size: AppTheme.iconXS),
              const BaseGap(Proximity.hairline),
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BaseIconButton(
            icon: IconRole.pencil,
            onPressed: onEdit,
            tooltip: AppLocalizations.of(context)!.edit,
          ),
          if (onDelete != null)
            BaseIconButton(
              icon: IconRole.trash,
              onPressed: onDelete,
              tooltip: AppLocalizations.of(context)!.delete,
            ),
        ],
      ),
    );
  }
}
