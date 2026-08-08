import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Proximity, TextRole, Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_layout.dart';
import '../../../shared/components/base_list_item.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_button.dart';
import '../../../core/git/models/file_status.dart';

/// Individual file item in the changes list
class FileListItem extends StatelessWidget {
  final FileStatus file;
  final bool isStaged;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onStage;
  final VoidCallback? onUnstage;
  final VoidCallback? onDiscard;
  final VoidCallback? onDiff;

  const FileListItem({
    super.key,
    required this.file,
    required this.isStaged,
    this.isSelected = false,
    this.onTap,
    this.onDoubleTap,
    this.onStage,
    this.onUnstage,
    this.onDiscard,
    this.onDiff,
  });

  @override
  Widget build(BuildContext context) {
    final status = file.primaryStatus;
    final isRenamed = status == FileStatusType.renamed;

    return BaseListItem(
      isSelected: isSelected,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      leading: _buildStatusIndicator(status, context),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File path
          BaseLabel(file.path, role: TextRole.body, maxLines: 1),
          // The path and the status beneath it are two halves of one thing, so
          // this is `hairline`. It was written as a literal 2 here and as
          // `paddingXS` (4) at every comparable row in the application, which
          // was one relationship said with two numbers; naming the
          // relationship settles it at the skin's single answer, which under
          // Material is 4.
          const BaseGap(Proximity.hairline),

          // Status and old path for renames
          Row(
            children: [
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: status.colorOf(context).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: BaseLabel(
                  status.displayName,
                  role: TextRole.micro,
                  tone: status.toneOf,
                ),
              ),

              // Old path for renames
              if (isRenamed && file.oldPath != null) ...[
                const BaseGap(Proximity.related),
                Flexible(
                  child: BaseLabel(
                    'from ${file.oldPath}',
                    role: TextRole.detail,
                    tone: Tone.muted,
                    maxLines: 1,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: _buildActions(context),
    );
  }

  Widget _buildStatusIndicator(FileStatusType status, BuildContext context) {
    // What happened to this file, as a mark rather than as a glyph: the switch
    // names the IDEA and the skin picks the drawing, so a language with its
    // own vocabulary for "added" is not stuck with Phosphor's plus.
    final IconRole role = switch (status) {
      FileStatusType.added => IconRole.plus,
      FileStatusType.modified => IconRole.pencilSimple,
      FileStatusType.deleted => IconRole.minus,
      FileStatusType.renamed => IconRole.arrowsLeftRight,
      FileStatusType.copied => IconRole.copy,
      FileStatusType.untracked => IconRole.filePlus,
      _ => IconRole.file,
    };

    return Container(
      // The wash behind the mark, its corner and its 6-pixel inset stay
      // spelled out here on purpose: they are one micro-surface that becomes
      // `surfaces.badge`, and a half-migrated surface whose mark is a meaning
      // while its fill is still a `Color` would be two names for one thing.
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: status.colorOf(context).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      // A row-level mark, which is `compact` - the 16 pixels this site named -
      // carrying the working-tree meaning rather than the git palette's
      // colour. `toneOf` differs from `colorOf` for exactly one status: an
      // unmerged file reaches the conflict tone instead of borrowing the
      // deletion colour, which is the substitution `file_status.dart` already
      // records as the thing the vocabulary removes.
      child: BaseIcon(role, scale: ControlScale.compact, tone: status.toneOf),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Diff button
        if (onDiff != null)
          BaseIconButton(
            icon: IconRole.gitDiff,
            tooltip: AppLocalizations.of(context)!.tooltipViewDiff,
            onPressed: onDiff,
            size: ButtonSize.small,
          ),

        const BaseGap(Proximity.hairline),

        // Stage/Unstage button
        if (isStaged)
          BaseIconButton(
            icon: IconRole.minus,
            tooltip: AppLocalizations.of(context)!.tooltipUnstage,
            onPressed: onUnstage,
            size: ButtonSize.small,
          )
        else
          BaseIconButton(
            icon: IconRole.plus,
            tooltip: AppLocalizations.of(context)!.tooltipStage,
            onPressed: onStage,
            size: ButtonSize.small,
          ),

        // Discard button (only for unstaged files)
        if (!isStaged && onDiscard != null) ...[
          const BaseGap(Proximity.hairline),
          BaseIconButton(
            icon: IconRole.trash,
            tooltip: AppLocalizations.of(context)!.tooltipDiscardChanges,
            onPressed: onDiscard,
            size: ButtonSize.small,
            variant: ButtonVariant.danger,
          ),
        ],
      ],
    );
  }
}
