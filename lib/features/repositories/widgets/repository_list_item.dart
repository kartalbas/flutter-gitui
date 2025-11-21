import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../shared/components/base_animated_widgets.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_list_item.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_menu_item.dart';
import '../../../shared/components/base_button.dart';
import '../../../core/workspace/models/workspace_repository.dart';
import '../../../core/workspace/repository_status_provider.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../repository_batch_error_provider.dart';
import '../../../shared/dialogs/batch_result_dialog.dart';

/// List item widget displaying a workspace repository in a compact row format
class RepositoryListItem extends ConsumerWidget {
  final WorkspaceRepository repository;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onToggleSelection;
  final VoidCallback? onEditRemoteUrl;
  final VoidCallback? onRenameRemote;
  final VoidCallback? onPruneRemote;
  final bool isSelected;
  final bool isMultiSelected;
  final bool showCheckbox;

  const RepositoryListItem({
    super.key,
    required this.repository,
    required this.onTap,
    required this.onRemove,
    required this.onToggleFavorite,
    this.onToggleSelection,
    this.onEditRemoteUrl,
    this.onRenameRemote,
    this.onPruneRemote,
    this.isSelected = false,
    this.isMultiSelected = false,
    this.showCheckbox = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isValid = repository.isValidGitRepo;
    final status = ref.watch(repositoryStatusByPathProvider(repository.path));

    // Repository is only selectable if BOTH checks pass:
    // 1. Synchronous check: repository.isValidGitRepo
    // 2. Async status check: !status.isBroken (unless still loading)
    final isSelectable = isValid && (status.isLoading || !status.isBroken);

    return BaseListItem(
      isSelected: isSelected,
      isMultiSelected: isMultiSelected,
      isSelectable: isSelectable,
      onTap: onTap,
      leading: (showCheckbox && isSelectable)
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Multi-selection checkbox
                Checkbox(
                  value: isMultiSelected,
                  onChanged: onToggleSelection != null
                      ? (_) => onToggleSelection!()
                      : null,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: AppTheme.paddingS),
              ],
            )
          : null,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Repository name
          Row(
            children: [
              Flexible(
                child: TitleMediumLabel(
                  repository.displayName,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : null,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Favorite icon
              if (repository.isFavorite) ...[
                const SizedBox(width: AppTheme.paddingS),
                Icon(
                  PhosphorIconsBold.star,
                  size: 14,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.primary,
                ),
              ],

              // Status badges or loading indicator
              const SizedBox(width: AppTheme.paddingS),

              // Batch operation result icon
              _buildBatchResultIcon(context, ref),

              // Show loading while analyzing
              if (status.isLoading) ...[
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ] else ...[
                // Broken
                if (status.isBroken)
                  _buildCompactBadge(
                    context,
                    PhosphorIconsRegular.warningCircle,
                    Theme.of(context).colorScheme.error,
                    isSelected,
                    label: 'Broken',
                  ),

                // Behind (pull)
                if (status.hasIncoming) ...[
                  const SizedBox(width: AppTheme.paddingXS),
                  _buildCompactBadge(
                    context,
                    PhosphorIconsRegular.arrowDown,
                    Theme.of(context).colorScheme.tertiary,
                    isSelected,
                    label: '↓${status.commitsBehind}',
                  ),
                ],

                // Ahead (push)
                if (status.hasOutgoing) ...[
                  const SizedBox(width: AppTheme.paddingXS),
                  _buildCompactBadge(
                    context,
                    PhosphorIconsRegular.arrowUp,
                    Theme.of(context).colorScheme.primary,
                    isSelected,
                    label: '↑${status.commitsAhead}',
                  ),
                ],

                // Uncommitted
                if (status.hasUncommittedChanges) ...[
                  const SizedBox(width: AppTheme.paddingXS),
                  _buildCompactBadge(
                    context,
                    PhosphorIconsRegular.pencilSimple,
                    Theme.of(context).colorScheme.secondary,
                    isSelected,
                    label: 'Changes',
                  ),
                ],

                // Clean status
                if (!status.isBroken && !status.hasIncoming && !status.hasOutgoing && !status.hasUncommittedChanges && status.exists && status.isValidGit) ...[
                  const SizedBox(width: AppTheme.paddingXS),
                  _buildCompactBadge(
                    context,
                    PhosphorIconsRegular.checkCircle,
                    Theme.of(context).colorScheme.primary,
                    isSelected,
                    label: 'Up to date',
                  ),
                ],
              ],
            ],
          ),
          const SizedBox(height: AppTheme.paddingXS),

          // Branch and path
          Row(
            children: [
              // Current branch
              if (status.currentBranch != null) ...[
                Icon(
                  PhosphorIconsRegular.gitBranch,
                  size: AppTheme.iconXS,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppTheme.paddingXS),
                BodySmallLabel(
                  status.currentBranch!,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppTheme.paddingM),
              ],

              Icon(
                PhosphorIconsRegular.folder,
                size: AppTheme.iconXS,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppTheme.paddingXS),
              Flexible(
                child: BodySmallLabel(
                  repository.path,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppTheme.paddingM),
              Icon(
                PhosphorIconsRegular.clock,
                size: AppTheme.iconXS,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppTheme.paddingXS),
              Flexible(
                child: BodySmallLabel(
                  repository.lastAccessed.toDisplayString(Localizations.localeOf(context).languageCode),
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Description
          if (repository.description != null) ...[
            const SizedBox(height: AppTheme.paddingXS),
            BodySmallLabel(
              repository.description!,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : null,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BaseIconButton(
            icon: repository.isFavorite
                ? PhosphorIconsBold.star
                : PhosphorIconsRegular.star,
            onPressed: onToggleFavorite,
            tooltip: repository.isFavorite
                ? AppLocalizations.of(context)!.tooltipRemoveFromFavorites
                : AppLocalizations.of(context)!.tooltipAddToFavorites,
          ),
          BaseIconButton(
            icon: PhosphorIconsRegular.trash,
            onPressed: onRemove,
            tooltip: AppLocalizations.of(context)!.tooltipRemoveFromWorkspace,
          ),
          // Remote management menu - only shown if there's a remote (on far right)
          if (status.hasRemote && (onEditRemoteUrl != null || onRenameRemote != null || onPruneRemote != null))
            BasePopupMenuButton<String>(
              icon: Icon(
                PhosphorIconsRegular.dotsThreeVertical,
                size: AppTheme.iconM,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.6)
                    : null,
              ),
              tooltip: AppLocalizations.of(context)!.moreActions,
              itemBuilder: (context) => [
                if (onEditRemoteUrl != null)
                  PopupMenuItem<String>(
                    value: 'edit_remote_url',
                    child: MenuItemContent(
                      icon: PhosphorIconsRegular.link,
                      label: AppLocalizations.of(context)!.editRemoteUrl('origin'),
                      iconSize: AppTheme.iconM,
                    ),
                  ),
                if (onRenameRemote != null)
                  PopupMenuItem<String>(
                    value: 'rename_remote',
                    child: MenuItemContent(
                      icon: PhosphorIconsRegular.pencil,
                      label: AppLocalizations.of(context)!.renameRemote('origin'),
                      iconSize: AppTheme.iconM,
                    ),
                  ),
                if (onPruneRemote != null)
                  PopupMenuItem<String>(
                    value: 'prune_remote',
                    child: MenuItemContent(
                      icon: PhosphorIconsRegular.broom,
                      label: AppLocalizations.of(context)!.pruneRemote('origin'),
                      iconSize: AppTheme.iconM,
                    ),
                  ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'edit_remote_url':
                    onEditRemoteUrl?.call();
                    break;
                  case 'rename_remote':
                    onRenameRemote?.call();
                    break;
                  case 'prune_remote':
                    onPruneRemote?.call();
                    break;
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBatchResultIcon(BuildContext context, WidgetRef ref) {
    final batchResult = ref.watch(repositoryBatchErrorByPathProvider(repository.path));

    if (batchResult == null) {
      return const SizedBox.shrink();
    }

    final isSuccess = batchResult.success;
    final icon = isSuccess
        ? PhosphorIconsBold.checkCircle
        : PhosphorIconsBold.warningCircle;
    final color = isSuccess
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;

    return GestureDetector(
      onTap: () => _showBatchResultDialog(context, ref, batchResult),
      child: Padding(
        padding: const EdgeInsets.only(right: AppTheme.paddingXS),
        child: Icon(
          icon,
          size: 14,
          color: color,
        ),
      ),
    );
  }

  void _showBatchResultDialog(
    BuildContext context,
    WidgetRef ref,
    RepositoryBatchResult result,
  ) {
    showBatchResultDialog(
      context: context,
      repositoryName: repository.displayName,
      result: result,
      onDismiss: () {
        ref.read(repositoryBatchErrorProvider.notifier).clearResult(repository.path);
      },
    );
  }

  Widget _buildCompactBadge(
    BuildContext context,
    IconData icon,
    Color color,
    bool isSelected, {
    String? label,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: label != null ? 6 : 4,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? color.withValues(alpha: 0.3)
            : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          if (label != null) ...[
            const SizedBox(width: 3),
            LabelSmallLabel(
              label,
              color: color,
            ),
          ],
        ],
      ),
    );
  }
}
