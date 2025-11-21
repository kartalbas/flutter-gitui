import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_card.dart';

/// Empty state for repositories screen
class RepositoriesEmptyState extends StatelessWidget {
  final VoidCallback onOpenRepository;
  final VoidCallback onCloneRepository;
  final VoidCallback onInitRepository;

  const RepositoriesEmptyState({
    super.key,
    required this.onOpenRepository,
    required this.onCloneRepository,
    required this.onInitRepository,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsBold.gitBranch,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: AppTheme.paddingL),
          HeadlineMediumLabel(
            AppLocalizations.of(context)!.noRepositoriesYet,
          ),
          const SizedBox(height: AppTheme.paddingS),
          BodyLargeLabel(
            AppLocalizations.of(context)!.addRepositoryToGetStarted,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.paddingXL),
          Wrap(
            spacing: AppTheme.paddingM,
            runSpacing: AppTheme.paddingM,
            children: [
              _ActionCard(
                icon: PhosphorIconsRegular.folderOpen,
                title: AppLocalizations.of(context)!.openRepository,
                description: AppLocalizations.of(context)!.browseExistingRepository,
                onTap: onOpenRepository,
              ),
              _ActionCard(
                icon: PhosphorIconsRegular.downloadSimple,
                title: AppLocalizations.of(context)!.cloneRepository,
                description: AppLocalizations.of(context)!.cloneFromRemoteUrl,
                onTap: onCloneRepository,
              ),
              _ActionCard(
                icon: PhosphorIconsRegular.plus,
                title: AppLocalizations.of(context)!.initializeRepository,
                description: AppLocalizations.of(context)!.createNewGitRepository,
                onTap: onInitRepository,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Action card for quick actions
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: BaseCard(
        onTap: onTap,
        content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: AppTheme.paddingM),
                TitleMediumLabel(
                  title,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.paddingS),
                BodySmallLabel(
                  description,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
      ),
    );
  }
}
