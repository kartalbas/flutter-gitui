import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, TextRole, Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
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
          const SizedBox(height: 2),

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
                const SizedBox(width: AppTheme.paddingS),
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
    IconData icon;

    switch (status) {
      case FileStatusType.added:
        icon = PhosphorIconsRegular.plus;
        break;
      case FileStatusType.modified:
        icon = PhosphorIconsRegular.pencilSimple;
        break;
      case FileStatusType.deleted:
        icon = PhosphorIconsRegular.minus;
        break;
      case FileStatusType.renamed:
        icon = PhosphorIconsRegular.arrowsLeftRight;
        break;
      case FileStatusType.copied:
        icon = PhosphorIconsRegular.copy;
        break;
      case FileStatusType.untracked:
        icon = PhosphorIconsRegular.filePlus;
        break;
      default:
        icon = PhosphorIconsRegular.file;
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: status.colorOf(context).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Icon(icon, size: AppTheme.iconS, color: status.colorOf(context)),
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

        const SizedBox(width: AppTheme.paddingXS),

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
          const SizedBox(width: AppTheme.paddingXS),
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
