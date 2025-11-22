import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_card.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_animated_widgets.dart';
import '../../../shared/components/base_menu_item.dart';
import '../../../shared/components/base_button.dart';
import '../../../core/workspace/models/workspace_repository.dart';
import '../../../core/workspace/repository_status_provider.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../repository_batch_error_provider.dart';
import '../../../shared/dialogs/batch_result_dialog.dart';

/// Card widget displaying a workspace repository
class RepositoryCard extends ConsumerWidget {
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

  const RepositoryCard({
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

    return BaseCard(
        isSelected: isSelected,
        isMultiSelected: isMultiSelected,
        isSelectable: isSelectable,
        onTap: onTap,
        customBackgroundColor: isSelected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
            : isMultiSelected
                ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1)
                : null,
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with favorite and remove buttons
              Row(
                children: [
                  // Multi-selection checkbox
                  if (showCheckbox && isSelectable)
                    Padding(
                      padding: const EdgeInsets.only(right: AppTheme.paddingS),
                      child: Checkbox(
                        value: isMultiSelected,
                        onChanged: onToggleSelection != null
                            ? (_) => onToggleSelection!()
                            : null,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  const Spacer(),
                  // Batch operation result icon
                  _buildBatchResultIcon(context, ref),
                  BaseIconButton(
                    icon: repository.isFavorite
                        ? PhosphorIconsBold.star
                        : PhosphorIconsRegular.star,
                    onPressed: onToggleFavorite,
                    tooltip: repository.isFavorite
                        ? AppLocalizations.of(context)!.tooltipRemoveFromFavorites
                        : AppLocalizations.of(context)!.tooltipAddToFavorites,
                  ),
                  // Remote management menu
                  if (status.hasRemote && (onEditRemoteUrl != null || onRenameRemote != null || onPruneRemote != null))
                    BasePopupMenuButton<String>(
                      icon: const Icon(
                        PhosphorIconsRegular.dotsThreeVertical,
                        size: AppTheme.iconM,
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
                  BaseIconButton(
                    icon: PhosphorIconsRegular.trash,
                    onPressed: onRemove,
                    tooltip: AppLocalizations.of(context)!.tooltipRemoveFromWorkspace,
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.paddingM),

              // Repository name
              TitleLargeLabel(
                repository.displayName,
                color: isSelected
                    ? Theme.of(context).colorScheme.onSecondaryContainer
                    : Theme.of(context).colorScheme.onSurface,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppTheme.paddingS),

              // Path
              Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.folder,
                    size: 14,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onSecondaryContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppTheme.paddingXS),
                  Flexible(
                    child: BodySmallLabel(
                      repository.path,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onSecondaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Current branch
              if (status.currentBranch != null) ...[
                const SizedBox(height: AppTheme.paddingS),
                Row(
                  children: [
                    Icon(
                      PhosphorIconsRegular.gitBranch,
                      size: 14,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onSecondaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppTheme.paddingXS),
                    Flexible(
                      child: BodyMediumLabel(
                        status.currentBranch!,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onSecondaryContainer
                            : Theme.of(context).colorScheme.onSurface,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // Description if available
              if (repository.description != null) ...[
                const SizedBox(height: AppTheme.paddingS),
                BodyMediumLabel(
                  repository.description!,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Status badges - show loading or actual status
              const SizedBox(height: AppTheme.paddingM),
              if (status.isLoading)
                // Show loading indicator while analyzing
                Row(
                  children: [
                    SizedBox(
                      width: AppTheme.paddingM,
                      height: AppTheme.paddingM,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: AppTheme.paddingS),
                    BodySmallLabel(
                      'Analyzing...',
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ],
                )
              else
                // Show actual status badges after analysis
                Wrap(
                  spacing: AppTheme.paddingXS,
                  runSpacing: AppTheme.paddingXS,
                  children: [
                    // Broken status
                    if (status.isBroken)
                      _buildStatusBadge(
                        context,
                        PhosphorIconsRegular.warningCircle,
                        'Broken',
                        Theme.of(context).colorScheme.error,
                        isSelected,
                      ),

                    // Commits behind (need to pull)
                    if (status.hasIncoming)
                      _buildStatusBadge(
                        context,
                        PhosphorIconsRegular.arrowDown,
                        '↓${status.commitsBehind}',
                        Theme.of(context).colorScheme.tertiary,
                        isSelected,
                      ),

                    // Commits ahead (need to push)
                    if (status.hasOutgoing)
                      _buildStatusBadge(
                        context,
                        PhosphorIconsRegular.arrowUp,
                        '↑${status.commitsAhead}',
                        Theme.of(context).colorScheme.primary,
                        isSelected,
                      ),

                    // Uncommitted changes
                    if (status.hasUncommittedChanges)
                      _buildStatusBadge(
                        context,
                        PhosphorIconsRegular.pencilSimple,
                        'Changes',
                        Theme.of(context).colorScheme.secondary,
                        isSelected,
                      ),

                    // Show "Up to date" if no issues
                    if (!status.isBroken && !status.hasIncoming && !status.hasOutgoing && !status.hasUncommittedChanges && status.exists && status.isValidGit)
                      _buildStatusBadge(
                        context,
                        PhosphorIconsRegular.checkCircle,
                        'Up to date',
                        Theme.of(context).colorScheme.primary,
                        isSelected,
                      ),
                  ],
                ),

              const Spacer(),

              // Invalid repo warning
              if (!isValid) ...[
                const SizedBox(height: AppTheme.paddingM),
                Container(
                  padding: const EdgeInsets.all(AppTheme.paddingS),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIconsRegular.warningCircle,
                        size: AppTheme.iconS,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: AppTheme.paddingS),
                      Expanded(
                        child: BodySmallLabel(
                          'Invalid or missing repository',
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Last accessed
              const SizedBox(height: AppTheme.paddingM),
              Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.clock,
                    size: 14,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onSecondaryContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppTheme.paddingXS),
                  LabelMediumLabel(
                    '${AppLocalizations.of(context)!.accessed} ${repository.lastAccessed.toDisplayString(Localizations.localeOf(context).languageCode)}',
                    color: isSelected
                        ? Theme.of(context).colorScheme.onSecondaryContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
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

    return Padding(
      padding: const EdgeInsets.only(right: AppTheme.paddingS),
      child: BaseIconButton(
        icon: icon,
        onPressed: () => _showBatchResultDialog(context, ref, batchResult),
        tooltip: isSuccess ? 'Operation successful' : 'Operation failed',
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

  Widget _buildStatusBadge(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    bool isSelected,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingS, vertical: AppTheme.paddingXS),
      decoration: BoxDecoration(
        color: isSelected
            ? color.withValues(alpha:0.2)
            : color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha:0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: AppTheme.paddingXS),
          LabelMediumLabel(
            label,
            color: color,
          ),
        ],
      ),
    );
  }
}
