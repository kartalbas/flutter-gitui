import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_card.dart';

/// Temporary screen to compare repository icon options
class IconComparisonScreen extends StatelessWidget {
  const IconComparisonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final iconOptions = [
      _IconOption(
        name: 'gitCommit',
        icon: PhosphorIconsRegular.gitCommit,
        boldIcon: PhosphorIconsBold.gitCommit,
        description: 'Git commit node - represents a commit in the git graph',
      ),
      _IconOption(
        name: 'circleDashed',
        icon: PhosphorIconsRegular.circleDashed,
        boldIcon: PhosphorIconsBold.circleDashed,
        description: 'Dashed circle - similar to commit node but softer',
      ),
      _IconOption(
        name: 'recordFill',
        icon: PhosphorIconsRegular.record,
        boldIcon: PhosphorIconsBold.record,
        description: 'Record/dot - minimal commit representation',
      ),
      _IconOption(
        name: 'circle',
        icon: PhosphorIconsRegular.circle,
        boldIcon: PhosphorIconsBold.circle,
        description: 'Simple circle - clean commit node',
      ),
      _IconOption(
        name: 'selection',
        icon: PhosphorIconsRegular.selection,
        boldIcon: PhosphorIconsBold.selection,
        description: 'Selection/snapshot - represents a point in time',
      ),
      _IconOption(
        name: 'seal',
        icon: PhosphorIconsRegular.seal,
        boldIcon: PhosphorIconsBold.seal,
        description: 'Seal/badge - represents verified/sealed commit',
      ),
      _IconOption(
        name: 'stamp',
        icon: PhosphorIconsRegular.stamp,
        boldIcon: PhosphorIconsBold.stamp,
        description: 'Stamp - represents marking a point in history',
      ),
      _IconOption(
        name: 'target',
        icon: PhosphorIconsRegular.target,
        boldIcon: PhosphorIconsBold.target,
        description: 'Target - represents a specific point/commit',
      ),
      _IconOption(
        name: 'dot',
        icon: PhosphorIconsRegular.dot,
        boldIcon: PhosphorIconsBold.dot,
        description: 'Simple dot - minimal commit indicator',
      ),
      _IconOption(
        name: 'bookmark',
        icon: PhosphorIconsRegular.bookmark,
        boldIcon: PhosphorIconsBold.bookmark,
        description: 'Bookmark - marks important commits',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const TitleLargeLabel('Repository Icon Options'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingL),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: AppTheme.paddingM,
            mainAxisSpacing: AppTheme.paddingM,
          ),
          itemCount: iconOptions.length,
          itemBuilder: (context, index) {
            final option = iconOptions[index];
            return _IconCard(option: option);
          },
        ),
      ),
    );
  }
}

class _IconOption {
  final String name;
  final IconData icon;
  final IconData boldIcon;
  final String description;

  const _IconOption({
    required this.name,
    required this.icon,
    required this.boldIcon,
    required this.description,
  });
}

class _IconCard extends StatelessWidget {
  final _IconOption option;

  const _IconCard({required this.option});

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      content: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon name
            TitleMediumLabel(
              option.name,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: AppTheme.paddingM),

            // Icons (regular and bold variants)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Regular variant
                Column(
                  children: [
                    Icon(
                      option.icon,
                      size: AppTheme.iconXL * 2,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(height: AppTheme.paddingXS),
                    LabelSmallLabel(
                      'Regular',
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(width: AppTheme.paddingL),
                // Bold variant
                Column(
                  children: [
                    Icon(
                      option.boldIcon,
                      size: AppTheme.iconXL * 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: AppTheme.paddingXS),
                    LabelSmallLabel(
                      'Bold',
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppTheme.paddingM),

            // Description
            BodySmallLabel(
              option.description,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
    );
  }
}
