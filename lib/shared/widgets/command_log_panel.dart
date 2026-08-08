import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, TextRole, Tone;
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
          BaseLabel('Git Command Log', role: TextRole.sectionTitle),
          const SizedBox(width: AppTheme.paddingS),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.paddingS,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
            ),
            // The pill states the foreground that pairs with its own fill; the
            // count inside it just reads that.
            child: DefaultTextStyle.merge(
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              child: BaseLabel(logCount.toString(), role: TextRole.micro),
            ),
          ),
          const Spacer(),
          BaseIconButton(
            icon: IconRole.trash,
            tooltip: l10n.clearLog,
            onPressed: () {
              ref.read(gitCommandLogProvider.notifier).clear();
            },
          ),
          BaseIconButton(
            icon: IconRole.x,
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
              prefixIcon: IconRole.magnifyingGlass,
              variant: TextFieldVariant.emphasized,
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
            size: AppTheme.iconXL * 2,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.paddingL),
          BaseLabel(l10n.emptyStateNoCommandsYet, role: TextRole.pageTitle),
          const SizedBox(height: AppTheme.paddingS),
          BaseLabel(
            l10n.emptyStateNoCommandsYetMessage,
            role: TextRole.body,
            tone: Tone.muted,
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
            size: AppTheme.iconXL * 2,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.paddingL),
          BaseLabel(l10n.emptyStateNoResultsFound, role: TextRole.pageTitle),
          const SizedBox(height: AppTheme.paddingS),
          BaseLabel(
            l10n.emptyStateTryAdjustingSearchCriteria,
            role: TextRole.body,
            tone: Tone.muted,
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
                            : context.gitColors.added,
                      ),
                    ),
                    const SizedBox(width: AppTheme.paddingS),
                    // The command is the headline; everything else is meta.
                    Expanded(
                      child: BaseLabel(
                        log.command,
                        // A git command line is code by the role's own
                        // definition, and the monospace family it takes is now
                        // the one the user chose rather than a family name
                        // written into this file.
                        role: TextRole.code,
                        tone: isFailure ? Tone.danger : Tone.neutral,
                        maxLines: _isExpanded ? null : 2,
                      ),
                    ),
                    const SizedBox(width: AppTheme.paddingS),
                    BaseIconButton(
                      icon: IconRole.copy,
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
                          child: DefaultTextStyle.merge(
                            style: TextStyle(
                              color: colorScheme.onSecondaryContainer,
                            ),
                            child: BaseLabel(
                              'x${group.count}',
                              role: TextRole.micro,
                            ),
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
                          child: DefaultTextStyle.merge(
                            style: TextStyle(
                              color: colorScheme.onErrorContainer,
                            ),
                            child: BaseLabel(
                              '${l10n.failed} (${log.exitCode})',
                              role: TextRole.micro,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.paddingS),
                      ],
                      Flexible(
                        child: BaseLabel(
                          log.timestampDisplay(
                            Localizations.localeOf(context).languageCode,
                          ),
                          role: TextRole.micro,
                          tone: Tone.muted,
                          // A timestamp is one line; the `Flexible` around it
                          // exists to let it shrink, not to let it wrap.
                          maxLines: 1,
                        ),
                      ),
                      if (log.duration != null) ...[
                        const SizedBox(width: AppTheme.paddingS),
                        BaseLabel(
                          '${log.duration!.inMilliseconds}ms',
                          role: TextRole.micro,
                          tone: Tone.muted,
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
                        BaseLabel(
                          entry.timestampDisplay(
                            Localizations.localeOf(context).languageCode,
                          ),
                          role: TextRole.micro,
                          tone: Tone.muted,
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
