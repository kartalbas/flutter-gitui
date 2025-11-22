import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_panel.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/copyable_text.dart';
import '../../../core/git/models/commit.dart';

/// Panel showing detailed information about a commit
class CommitDetailsPanel extends StatefulWidget {
  final GitCommit commit;

  const CommitDetailsPanel({
    super.key,
    required this.commit,
  });

  @override
  State<CommitDetailsPanel> createState() => _CommitDetailsPanelState();
}

class _CommitDetailsPanelState extends State<CommitDetailsPanel> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BasePanel(
      title: Row(
        children: [
          Icon(
            PhosphorIconsRegular.info,
            size: AppTheme.iconS,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppTheme.paddingS),
          TitleSmallLabel(l10n.commitDetails),
        ],
      ),
      actions: const [],
      content: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Commit message (prominent)
            Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.paddingL),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            PhosphorIconsRegular.chatText,
                            size: AppTheme.iconS,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: AppTheme.paddingS),
                          TitleSmallLabel(
                            l10n.commitMessage,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.paddingM),
                      SelectableText(
                        widget.commit.message,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
            ),

            const SizedBox(height: AppTheme.paddingM),

            // Expandable details section
            InkWell(
              onTap: () {
                setState(() {
                  _showDetails = !_showDetails;
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.paddingM),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _showDetails
                          ? PhosphorIconsRegular.caretDown
                          : PhosphorIconsRegular.caretRight,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppTheme.paddingS),
                    BodyMediumLabel(
                      l10n.additionalDetails,
                    ),
                    const Spacer(),
                    BodySmallLabel(
                      _showDetails ? l10n.hide : l10n.show,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),

            // Details content (expandable)
            if (_showDetails) ...[
              const SizedBox(height: AppTheme.paddingM),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.paddingM),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author info
                    _buildSection(
                      context,
                      l10n.authorLabel,
                      PhosphorIconsRegular.user,
                      child: Column(
                        children: [
                          _buildInfoRow(
                            context,
                            l10n.name,
                            widget.commit.author,
                          ),
                          _buildInfoRow(
                            context,
                            l10n.email,
                            widget.commit.authorEmail,
                          ),
                          _buildInfoRow(
                            context,
                            l10n.date,
                            widget.commit.authorDateDisplay(Localizations.localeOf(context).languageCode),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppTheme.paddingM),

                    // Committer info (if different from author)
                    if (widget.commit.committer != widget.commit.author ||
                        widget.commit.committerEmail != widget.commit.authorEmail) ...[
                      _buildSection(
                        context,
                        l10n.committerLabel,
                        PhosphorIconsRegular.userCircle,
                        child: Column(
                          children: [
                            _buildInfoRow(
                              context,
                              l10n.name,
                              widget.commit.committer,
                            ),
                            _buildInfoRow(
                              context,
                              l10n.email,
                              widget.commit.committerEmail,
                            ),
                            _buildInfoRow(
                              context,
                              l10n.date,
                              widget.commit.committerDateDisplay(Localizations.localeOf(context).languageCode),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.paddingM),
                    ],

                    // Commit hash
                    _buildSection(
                      context,
                      l10n.hash,
                      PhosphorIconsRegular.hash,
                      child: CopyableText(
                        text: widget.commit.hash,
                        isMonospace: true,
                        icon: PhosphorIconsRegular.gitCommit,
                      ),
                    ),

                    // Parents
                    if (widget.commit.parents.isNotEmpty) ...[
                      const SizedBox(height: AppTheme.paddingM),
                      _buildSection(
                        context,
                        widget.commit.parents.length > 1
                            ? l10n.parents
                            : l10n.parent,
                        widget.commit.isMergeCommit
                            ? PhosphorIconsRegular.gitMerge
                            : PhosphorIconsRegular.gitCommit,
                        child: Column(
                          children: widget.commit.parents.map((parent) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: CopyableText(
                                text: parent,
                                isMonospace: true,
                                icon: PhosphorIconsRegular.gitCommit,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],

                    // Refs (branches, tags)
                    if (widget.commit.refs.isNotEmpty) ...[
                      const SizedBox(height: AppTheme.paddingM),
                      _buildSection(
                        context,
                        l10n.references,
                        PhosphorIconsRegular.gitBranch,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: widget.commit.refs.map((ref) {
                            final isTag = ref.contains('tag:');
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.paddingS,
                                vertical: AppTheme.paddingXS,
                              ),
                              decoration: BoxDecoration(
                                color: isTag
                                    ? Theme.of(context).colorScheme.tertiaryContainer
                                    : Theme.of(context).colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isTag
                                      ? Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.3)
                                      : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isTag ? PhosphorIconsRegular.tag : PhosphorIconsRegular.gitBranch,
                                    size: 12,
                                    color: isTag
                                        ? Theme.of(context).colorScheme.onTertiaryContainer
                                        : Theme.of(context).colorScheme.onSecondaryContainer,
                                  ),
                                  const SizedBox(width: AppTheme.paddingXS),
                                  LabelMediumLabel(
                                    ref,
                                    color: isTag
                                        ? Theme.of(context).colorScheme.onTertiaryContainer
                                        : Theme.of(context).colorScheme.onSecondaryContainer,
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
        ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon, {
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: AppTheme.paddingS),
            LabelLargeLabel(
              title,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.paddingS),
        child,
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: BodySmallLabel(
              label,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppTheme.paddingM),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
