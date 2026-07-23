import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../generated/app_localizations.dart';

import '../theme/app_theme.dart';
import '../components/base_label.dart';
import '../components/base_card.dart';
import '../components/base_button.dart';
import '../components/base_filter_chip.dart';
import '../components/base_text_field.dart';
import '../../core/config/config_providers.dart';
import '../../core/git/git_command_log_filters.dart';
import '../../core/git/git_command_log_provider.dart';
import '../../core/git/models/git_command_log.dart';

/// Expandable panel showing git command log history
class CommandLogPanel extends ConsumerStatefulWidget {
  const CommandLogPanel({super.key});

  @override
  ConsumerState<CommandLogPanel> createState() => _CommandLogPanelState();
}

class _CommandLogPanelState extends ConsumerState<CommandLogPanel> {
  bool _failuresOnly = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final isVisible = ref.watch(commandLogPanelVisibleProvider);
    final width = ref.watch(commandLogPanelWidthProvider);
    final logs = ref.watch(gitCommandLogProvider);

    if (!isVisible) return const SizedBox.shrink();

    final visibleLogs = filterCommandLogs(
      logs,
      failuresOnly: _failuresOnly,
      query: _query,
    );

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(context, logs.length),
          const Divider(height: 1),
          _buildFilterBar(context, logs),
          const Divider(height: 1),
          Expanded(
            child: logs.isEmpty
                ? _buildEmptyState(context)
                : visibleLogs.isEmpty
                ? _buildNoMatchState(context)
                : _buildLogList(context, visibleLogs),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int logCount) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingM),
      child: Row(
        children: [
          const Icon(PhosphorIconsRegular.terminal, size: 20),
          const SizedBox(width: AppTheme.paddingS),
          TitleMediumLabel('Git Command Log'),
          const SizedBox(width: AppTheme.paddingS),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.paddingS,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: LabelMediumLabel(
              logCount.toString(),
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const Spacer(),
          BaseIconButton(
            icon: PhosphorIconsRegular.trash,
            tooltip: l10n.clearLog,
            onPressed: () {
              ref.read(gitCommandLogProvider.notifier).clear();
            },
          ),
          BaseIconButton(
            icon: PhosphorIconsRegular.x,
            tooltip: l10n.close,
            onPressed: () {
              ref
                  .read(configProvider.notifier)
                  .setCommandLogPanelVisible(false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, List<GitCommandLog> logs) {
    final l10n = AppLocalizations.of(context)!;
    final failureCount = logs.where((log) => log.isFailure).length;

    return Padding(
      padding: const EdgeInsets.all(AppTheme.paddingS),
      child: Row(
        children: [
          Expanded(
            child: BaseTextField(
              hintText: l10n.search,
              prefixIcon: PhosphorIconsRegular.magnifyingGlass,
              variant: TextFieldVariant.filled,
              showClearButton: true,
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          const SizedBox(width: AppTheme.paddingS),
          BaseFilterChip(
            label: l10n.failed,
            icon: PhosphorIconsRegular.xCircle,
            selected: _failuresOnly,
            count: failureCount,
            showCount: true,
            onSelected: (selected) => setState(() => _failuresOnly = selected),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.terminal,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.paddingL),
          TitleLargeLabel(l10n.emptyStateNoCommandsYet),
          const SizedBox(height: AppTheme.paddingS),
          BodyMediumLabel(
            l10n.emptyStateNoCommandsYetMessage,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _buildNoMatchState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.magnifyingGlass,
            size: AppTheme.iconSizeXL,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.paddingL),
          TitleLargeLabel(l10n.emptyStateNoResultsFound),
          const SizedBox(height: AppTheme.paddingS),
          BodyMediumLabel(
            l10n.emptyStateTryAdjustingSearchCriteria,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _buildLogList(BuildContext context, List<GitCommandLog> logs) {
    // Newest first, then collapse bursts of identical adjacent runs so one
    // screen load cannot fill the panel with indistinguishable rows.
    final groups = groupConsecutiveCommandLogs(logs.reversed.toList());

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.paddingS),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        // Key on the newest underlying entry so a row keeps its expansion
        // state when new commands are prepended above it.
        return _LogEntryCard(
          key: ObjectKey(group.representative),
          group: group,
        );
      },
    );
  }
}

/// Card widget for one command, or one burst of identical consecutive runs
class _LogEntryCard extends StatefulWidget {
  final GitCommandLogGroup group;

  const _LogEntryCard({super.key, required this.group});

  @override
  State<_LogEntryCard> createState() => _LogEntryCardState();
}

class _LogEntryCardState extends State<_LogEntryCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final log = group.representative;
    final isFailure = log.isFailure;
    final hasOutput = group.entries.any((entry) => entry.fullOutput.isNotEmpty);
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final commandStyle = GoogleFonts.getFont(
      'JetBrains Mono',
      textStyle: Theme.of(context).textTheme.bodyMedium,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.paddingS),
      child: BaseCard(
        padding: EdgeInsets.zero,
        content: InkWell(
          onTap: hasOutput
              ? () => setState(() => _isExpanded = !_isExpanded)
              : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.paddingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Success stays quiet, failure takes the theme error role
                    // so a failed push is visible without expanding anything.
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        isFailure
                            ? PhosphorIconsRegular.xCircle
                            : PhosphorIconsRegular.checkCircle,
                        size: AppTheme.iconS,
                        color: isFailure
                            ? colorScheme.error
                            : AppTheme.gitAdded,
                      ),
                    ),
                    const SizedBox(width: AppTheme.paddingS),
                    // The command is the headline; everything else is meta.
                    Expanded(
                      child: BaseLabel(
                        log.command,
                        style: commandStyle,
                        color: isFailure
                            ? colorScheme.error
                            : colorScheme.onSurface,
                        maxLines: _isExpanded ? null : 2,
                        overflow: _isExpanded ? null : TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppTheme.paddingS),
                    BaseIconButton(
                      icon: PhosphorIconsRegular.copy,
                      size: ButtonSize.small,
                      tooltip: l10n.tooltipCopyCommand,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: log.command));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.commandCopiedToClipboard),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    if (hasOutput) ...[
                      const SizedBox(width: AppTheme.paddingXS),
                      Padding(
                        padding: const EdgeInsets.only(top: AppTheme.paddingS),
                        child: Icon(
                          _isExpanded
                              ? PhosphorIconsRegular.caretUp
                              : PhosphorIconsRegular.caretDown,
                          size: AppTheme.iconS,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppTheme.paddingXS),
                // Meta row, aligned under the command headline.
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppTheme.paddingM + AppTheme.paddingS,
                  ),
                  child: Row(
                    children: [
                      if (group.count > 1) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.paddingXS,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusS,
                            ),
                          ),
                          child: LabelSmallLabel(
                            'x${group.count}',
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(width: AppTheme.paddingS),
                      ],
                      if (isFailure) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.paddingXS,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusS,
                            ),
                          ),
                          child: LabelSmallLabel(
                            '${l10n.failed} (${log.exitCode})',
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                        const SizedBox(width: AppTheme.paddingS),
                      ],
                      Flexible(
                        child: LabelSmallLabel(
                          log.timestampDisplay(
                            Localizations.localeOf(context).languageCode,
                          ),
                          color: colorScheme.onSurfaceVariant,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (log.duration != null) ...[
                        const SizedBox(width: AppTheme.paddingS),
                        LabelSmallLabel(
                          '${log.duration!.inMilliseconds}ms',
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
                ),
                // Output (expandable); a collapsed burst lists every run so
                // grouping never hides an individual run's output.
                if (_isExpanded && hasOutput) ...[
                  const SizedBox(height: AppTheme.paddingS),
                  const Divider(),
                  for (final entry in group.entries)
                    if (entry.fullOutput.isNotEmpty) ...[
                      if (group.count > 1) ...[
                        const SizedBox(height: AppTheme.paddingS),
                        LabelSmallLabel(
                          entry.timestampDisplay(
                            Localizations.localeOf(context).languageCode,
                          ),
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                      const SizedBox(height: AppTheme.paddingS),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppTheme.paddingM),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                        ),
                        child: SelectableText(
                          entry.fullOutput,
                          style: GoogleFonts.getFont(
                            'JetBrains Mono',
                            textStyle: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: entry.isFailure
                                      ? colorScheme.error
                                      : colorScheme.onSurface,
                                ),
                          ),
                        ),
                      ),
                    ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
