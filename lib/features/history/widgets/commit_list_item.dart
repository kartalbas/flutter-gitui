import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_list_item.dart';
import '../../../shared/components/base_label.dart';
import '../../../core/git/models/commit.dart';

/// Individual commit item in the history list
class CommitListItem extends StatelessWidget {
  final GitCommit commit;
  final bool isSelected;
  final bool isMultiSelected;
  final VoidCallback onTap;
  final String? currentBranch;

  const CommitListItem({
    super.key,
    required this.commit,
    required this.isSelected,
    required this.onTap,
    this.isMultiSelected = false,
    this.currentBranch,
  });

  @override
  Widget build(BuildContext context) {
    return BaseListItem(
      isSelected: isSelected,
      isMultiSelected: isMultiSelected,
      onTap: onTap,
      leading:
          // Commit graph line (simplified - just a dot for now)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: commit.isMergeCommit
                    ? Theme.of(context).colorScheme.tertiary
                    : Theme.of(context).colorScheme.primary,
                border: Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 2,
                ),
              ),
            ),
          ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject line
          BodyMediumLabel(
            commit.shortSubject,
            color: isSelected
                ? Theme.of(context).colorScheme.onSecondaryContainer
                : Theme.of(context).colorScheme.onSurface,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: AppTheme.paddingXS),

          // Refs (branches, tags)
          if (commit.refs.isNotEmpty) ...[
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: commit.refs.map((ref) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        ref.contains('tag:')
                            ? PhosphorIconsRegular.tag
                            : PhosphorIconsRegular.gitBranch,
                        size: 10,
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 2),
                      LabelSmallLabel(
                        ref,
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppTheme.paddingXS),
          ],

          // Author and time
          Row(
            children: [
              Icon(
                PhosphorIconsRegular.user,
                size: AppTheme.iconXS,
                color: isSelected
                    ? Theme.of(context).colorScheme.onSecondaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppTheme.paddingXS),
              Flexible(
                child: BodySmallLabel(
                  commit.author,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppTheme.paddingS),
              Icon(
                PhosphorIconsRegular.clock,
                size: AppTheme.iconXS,
                color: isSelected
                    ? Theme.of(context).colorScheme.onSecondaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppTheme.paddingXS),
              Flexible(
                child: BodySmallLabel(
                  commit.authorDateDisplay(Localizations.localeOf(context).languageCode),
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 2),

          // Short hash and current branch
          Row(
            children: [
              LabelMediumLabel(
                commit.shortHash,
                color: isSelected
                    ? Theme.of(context).colorScheme.onSecondaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              if (currentBranch != null) ...[
                const SizedBox(width: AppTheme.paddingS),
                Icon(
                  PhosphorIconsRegular.gitBranch,
                  size: 11,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppTheme.paddingXS),
                LabelMediumLabel(
                  currentBranch!,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
