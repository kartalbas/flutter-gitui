import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../generated/app_localizations.dart';

import '../theme/app_theme.dart';
import '../components/base_label.dart';
import '../components/base_card.dart';
import '../components/base_button.dart';
import '../../core/git/git_command_log_provider.dart';
import '../../core/git/models/git_command_log.dart';

/// Expandable panel showing git command log history
class CommandLogPanel extends ConsumerWidget {
  const CommandLogPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisible = ref.watch(commandLogPanelVisibleProvider);
    final width = ref.watch(commandLogPanelWidthProvider);
    final logs = ref.watch(gitCommandLogProvider);

    if (!isVisible) return const SizedBox.shrink();

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
            color: Theme.of(context).colorScheme.scrim.withValues(alpha:0.1),
            blurRadius: 8,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(context, ref, logs.length),
          const Divider(height: 1),
          Expanded(
            child: logs.isEmpty
                ? _buildEmptyState(context)
                : _buildLogList(context, logs),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, int logCount) {
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
              ref.read(commandLogPanelVisibleProvider.notifier).state = false;
            },
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

  Widget _buildLogList(BuildContext context, List<GitCommandLog> logs) {
    // Reverse to show most recent first
    final reversedLogs = logs.reversed.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.paddingS),
      itemCount: reversedLogs.length,
      itemBuilder: (context, index) {
        return _LogEntryCard(log: reversedLogs[index]);
      },
    );
  }
}

/// Card widget for a single log entry
class _LogEntryCard extends StatefulWidget {
  final GitCommandLog log;

  const _LogEntryCard({required this.log});

  @override
  State<_LogEntryCard> createState() => _LogEntryCardState();
}

class _LogEntryCardState extends State<_LogEntryCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final hasOutput = log.fullOutput.isNotEmpty;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.paddingS),
      child: BaseCard(
        padding: EdgeInsets.zero,
        content: InkWell(
        onTap: hasOutput ? () => setState(() => _isExpanded = !_isExpanded) : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.paddingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Status icon
                  Icon(
                    log.isSuccess
                        ? PhosphorIconsRegular.checkCircle
                        : PhosphorIconsRegular.xCircle,
                    size: 16,
                    color: log.isSuccess ? AppTheme.gitAdded : AppTheme.gitDeleted,
                  ),
                  const SizedBox(width: AppTheme.paddingS),
                  // Timestamp
                  Flexible(
                    child: BodySmallLabel(
                      log.timestampDisplay(Localizations.localeOf(context).languageCode),
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppTheme.paddingS),
                  // Duration
                  if (log.duration != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.paddingXS,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: LabelSmallLabel('${log.duration!.inMilliseconds}ms'),
                    ),
                  const Spacer(),
                  // Copy button
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
                    const SizedBox(width: AppTheme.paddingS),
                    Icon(
                      _isExpanded
                          ? PhosphorIconsRegular.caretUp
                          : PhosphorIconsRegular.caretDown,
                      size: 16,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppTheme.paddingS),
              // Command
              SelectableText(
                log.command,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              // Output (expandable)
              if (_isExpanded && hasOutput) ...[
                const SizedBox(height: AppTheme.paddingS),
                const Divider(),
                const SizedBox(height: AppTheme.paddingS),
                Container(
                  padding: const EdgeInsets.all(AppTheme.paddingM),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: SelectableText(
                    log.fullOutput,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: log.isFailure
                              ? AppTheme.gitDeleted
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }
}

