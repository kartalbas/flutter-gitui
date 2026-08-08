import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Inset, Proximity, TextRole, Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_panel.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_layout.dart';
import '../../../shared/components/copyable_text.dart';
import '../../../core/git/models/commit.dart';

/// Panel showing detailed information about a commit
class CommitDetailsPanel extends StatefulWidget {
  final GitCommit commit;

  const CommitDetailsPanel({super.key, required this.commit});

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
          // A panel header's mark: dense, and carrying the application's own
          // colour rather than Material's `primary` slot.
          const BaseIcon(
            IconRole.info,
            scale: ControlScale.compact,
            tone: Tone.accent,
          ),
          const BaseGap(Proximity.related),
          BaseLabel(l10n.commitDetails, role: TextRole.sectionTitle),
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
                // The card's fill and corner stay; only its breathing room is
                // the language's question, and a card is the surface the
                // vocabulary calls deliberately generous: `roomy`.
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: BaseInset(
                  all: Inset.roomy,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const BaseIcon(
                            IconRole.chatText,
                            scale: ControlScale.compact,
                            tone: Tone.accent,
                          ),
                          const BaseGap(Proximity.related),
                          // The brand tint this header spelled out said
                          // nothing the header was not already saying by being a
                          // section title, so it goes rather than being renamed.
                          BaseLabel(
                            l10n.commitMessage,
                            role: TextRole.sectionTitle,
                          ),
                        ],
                      ),
                      const BaseGap(Proximity.grouped),
                      SelectableText(
                        widget.commit.message,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const BaseGap(Proximity.grouped),

              // Expandable details section
              InkWell(
                onTap: () {
                  setState(() {
                    _showDetails = !_showDetails;
                  });
                },
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: BaseInset(
                    child: Row(
                      children: [
                        // The disclosure mark is a row-level one, and secondary
                        // to the words beside it.
                        BaseIcon(
                          _showDetails
                              ? IconRole.caretDown
                              : IconRole.caretRight,
                          scale: ControlScale.compact,
                          tone: Tone.muted,
                        ),
                        const BaseGap(Proximity.related),
                        BaseLabel(l10n.additionalDetails, role: TextRole.body),
                        const Spacer(),
                        BaseLabel(
                          _showDetails ? l10n.hide : l10n.show,
                          role: TextRole.detail,
                          tone: Tone.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Details content (expandable)
              if (_showDetails) ...[
                const BaseGap(Proximity.grouped),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: BaseInset(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Author info
                        _buildSection(
                          context,
                          l10n.authorLabel,
                          IconRole.user,
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
                                widget.commit.authorDateDisplay(
                                  Localizations.localeOf(context).languageCode,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const BaseGap(Proximity.grouped),

                        // Committer info (if different from author)
                        if (widget.commit.committer != widget.commit.author ||
                            widget.commit.committerEmail !=
                                widget.commit.authorEmail) ...[
                          _buildSection(
                            context,
                            l10n.committerLabel,
                            IconRole.userCircle,
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
                                  widget.commit.committerDateDisplay(
                                    Localizations.localeOf(
                                      context,
                                    ).languageCode,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const BaseGap(Proximity.grouped),
                        ],

                        // Commit hash
                        _buildSection(
                          context,
                          l10n.hash,
                          IconRole.hash,
                          child: CopyableText(
                            text: widget.commit.hash,
                            icon: IconRole.gitCommit,
                          ),
                        ),

                        // Parents
                        if (widget.commit.parents.isNotEmpty) ...[
                          const BaseGap(Proximity.grouped),
                          _buildSection(
                            context,
                            widget.commit.parents.length > 1
                                ? l10n.parents
                                : l10n.parent,
                            widget.commit.isMergeCommit
                                ? IconRole.gitMerge
                                : IconRole.gitCommit,
                            child: Column(
                              children: widget.commit.parents.map((parent) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: CopyableText(
                                    text: parent,
                                    icon: IconRole.gitCommit,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],

                        // Refs (branches, tags)
                        if (widget.commit.refs.isNotEmpty) ...[
                          const BaseGap(Proximity.grouped),
                          _buildSection(
                            context,
                            l10n.references,
                            IconRole.gitBranch,
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
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.tertiaryContainer
                                        : Theme.of(
                                            context,
                                          ).colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusL,
                                    ),
                                    border: Border.all(
                                      color: isTag
                                          ? Theme.of(context)
                                                .colorScheme
                                                .tertiary
                                                .withValues(alpha: 0.3)
                                          : Theme.of(context)
                                                .colorScheme
                                                .secondary
                                                .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  // "This ref is a tag rather than a branch" is a
                                  // fact about the CHIP, not about its text
                                  // colour — so the chip chooses the fill and
                                  // states the foreground that pairs with it,
                                  // once, and its label says nothing about
                                  // colour at all.
                                  child: DefaultTextStyle.merge(
                                    style: TextStyle(
                                      color: isTag
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.onTertiaryContainer
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSecondaryContainer,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isTag
                                              ? PhosphorIconsRegular.tag
                                              : PhosphorIconsRegular.gitBranch,
                                          size: 12,
                                          color: isTag
                                              ? Theme.of(context)
                                                    .colorScheme
                                                    .onTertiaryContainer
                                              : Theme.of(context)
                                                    .colorScheme
                                                    .onSecondaryContainer,
                                        ),
                                        const SizedBox(
                                          width: AppTheme.paddingXS,
                                        ),
                                        BaseLabel(ref, role: TextRole.micro),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
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
    IconRole icon, {
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // A section's mark, at the one scale a dense header mark takes.
            // It was 14 here and 16 in the header above it, for the same job.
            BaseIcon(icon, scale: ControlScale.compact, tone: Tone.accent),
            const BaseGap(Proximity.related),
            BaseLabel(
              title,
              role: TextRole.sectionTitle,
              // "This is the configured, resolved value" - the meaning the
              // brand colour was standing in for beside its red-when-unset
              // siblings.
              tone: Tone.accent,
            ),
          ],
        ),
        const BaseGap(Proximity.related),
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
            child: BaseLabel(label, role: TextRole.detail, tone: Tone.muted),
          ),
          const BaseGap(Proximity.grouped),
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
