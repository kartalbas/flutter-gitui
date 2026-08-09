import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        ContentPort,
        ControlScale,
        DisclosureSpec,
        IconRole,
        Inset,
        NoticeSpec,
        Overlays,
        Proximity,
        Skin,
        SkinScope,
        TextRole,
        Tone;
import 'package:google_fonts/google_fonts.dart';
import '../../generated/app_localizations.dart';

import '../theme/app_theme.dart';
import '../components/base_icon.dart';
import '../components/base_label.dart';
import '../components/base_layout.dart';
import '../components/base_card.dart';
import '../components/base_button.dart';
import '../components/base_filter_chip.dart';
import '../components/base_text_field.dart';
import '../../core/config/config_providers.dart';
import '../../core/git/git_command_log_filters.dart';
import '../../core/git/git_command_log_provider.dart';
import '../../core/git/models/git_command_log.dart';
import 'empty_state.dart';

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
          // Not `BaseSeparator`: these two rules are the panel's own chrome,
          // and `height: 1` is a measurement - the rule takes no layout space
          // of its own - that the separator member deliberately does not
          // carry. They leave with the panel when it becomes a member.
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
    // The panel header is a region of its own and owes its row the ordinary
    // reading distance from the panel's edges.
    return BaseInset(
      all: Inset.normal,
      child: Row(
        children: [
          const BaseIcon(IconRole.terminal),
          // The mark and the name of the panel are two halves of one heading.
          const BaseGap(Proximity.related),
          BaseLabel('Git Command Log', role: TextRole.sectionTitle),
          // The heading and the count that qualifies it are two parts of one
          // statement.
          const BaseGap(Proximity.related),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
            ),
            // A pill is barely set in across and reaches as close to its own
            // edge as it can down the page, because it has to stay the height
            // of the line it sits on.
            child: BaseInset(
              x: Inset.tight,
              y: Inset.hairline,
              // The pill states the foreground that pairs with its own fill;
              // the count inside it just reads that.
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                child: BaseLabel(logCount.toString(), role: TextRole.micro),
              ),
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

    // The filter band is a dense strip between two rules, so it is barely set
    // in from them.
    return BaseInset(
      all: Inset.tight,
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
          // The query and the filter that narrows it further are members of
          // one filter band.
          const BaseGap(Proximity.related),
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

  /// The panel before any git command has run.
  ///
  /// It used to lay out the mark, the headline and the sentence itself, and in
  /// doing so it wrote down how big the glyph is (`iconXL * 2`) and which
  /// colour it takes — two decisions an empty state does not get to make.
  /// [EmptyStateWidget] is the facade that becomes `surfaces.emptyState`, and
  /// once the member owns the size the question cannot be asked here at all
  /// (#430).
  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return EmptyStateWidget(
      icon: PhosphorIconsRegular.terminal,
      title: l10n.emptyStateNoCommandsYet,
      message: l10n.emptyStateNoCommandsYetMessage,
    );
  }

  /// The panel when the filter band has excluded every run there is.
  ///
  /// Same member as [_buildEmptyState]: "nothing matches" and "nothing yet"
  /// are one surface with different words, which is exactly what the facade is
  /// for.
  Widget _buildNoMatchState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return EmptyStateWidget(
      icon: PhosphorIconsRegular.magnifyingGlass,
      title: l10n.emptyStateNoResultsFound,
      message: l10n.emptyStateTryAdjustingSearchCriteria,
    );
  }

  Widget _buildLogList(BuildContext context, List<GitCommandLog> logs) {
    // Newest first, then collapse bursts of identical adjacent runs so one
    // screen load cannot fill the panel with indistinguishable rows.
    final groups = groupConsecutiveCommandLogs(logs.reversed.toList());

    return ListView.builder(
      // A viewport's own padding is a property, not a widget: wrapping the
      // list in one would clip the scroll at the padding's edge instead of
      // letting content run under it, so this cannot become a `BaseInset`
      // until the scrollable itself is a member.
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
    final hasOutput = group.entries.any((entry) => entry.fullOutput.isNotEmpty);
    // The card's trailing bottom padding was the space between one run of the
    // log and the next wearing a padding idiom, so the run states it: the card
    // owns nothing, and the gap sits between it and whatever follows.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BaseCard(
          inset: Inset.none,
          // One command, and the output it produced when the user asks to see
          // it: `surfaces.disclosure` said once. The press target, the reveal
          // animation, the caret and the entry's own inset are all the
          // member's now - and with them went the hand-built `InkWell`, the
          // caret glyph swap and the two ways this file used to say "open".
          content: SkinScope.render(context, (Skin skin, BuildContext inner) {
            return skin.surfaces.disclosure(
              inner,
              DisclosureSpec(
                header: ContentPort(_buildHeader(inner)),
                body: ContentPort(_buildOutput(inner)),
                // An entry that produced no output cannot be opened, and a
                // stale `true` from a previous group must not survive into
                // one that has nothing to show.
                expanded: _isExpanded && hasOutput,
                onExpandedChanged: (bool open) =>
                    setState(() => _isExpanded = open),
                enabled: hasOutput,
              ),
            );
          }),
        ),
        // One run of the log and the next.
        const BaseGap(Proximity.related),
      ],
    );
  }

  /// What the entry says whether or not it is open: the outcome, the command,
  /// the copy action and the facts about the run.
  ///
  /// The outcome mark leads the row and the command and its meta line share the
  /// column beside it, so the meta line is aligned under the headline BY THE
  /// LAYOUT rather than by a hanging indent measured against the mark. That
  /// measurement (`AppTheme.paddingM + AppTheme.paddingS` — the mark's own 16
  /// plus the 8 after it) is what the register held for this file, and it dies
  /// here rather than being converted.
  ///
  /// The mark stays in the header port rather than moving to
  /// [DisclosureSpec.leading], and that is now a DECIDED answer rather than a
  /// pending finding (#438): `leading` is the disclosure's own naming mark,
  /// drawn in the language's treatment, while THIS mark is part of what the
  /// header says - a per-entry outcome, at the application's compact scale,
  /// optically aligned to the first line of a two-line headline. The header
  /// is a content port, and the mark reaches the skin through [BaseIcon]'s
  /// IconRole+Tone exactly as any other content does; a tone on `leading`
  /// would be a second way to say this one thing, and it still could not
  /// carry the scale or the first-line alignment the statement needs.
  Widget _buildHeader(BuildContext context) {
    final group = widget.group;
    final log = group.representative;
    final isFailure = log.isFailure;
    final l10n = AppLocalizations.of(context)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Success stays quiet, failure takes the danger tone so a failed push
        // is visible without expanding anything. The nudge above the mark is
        // optical alignment against the first line of the command, not an
        // inset, and the vocabulary has no word for it - see the report.
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: BaseIcon(
            isFailure ? IconRole.xCircle : IconRole.checkCircle,
            scale: ControlScale.compact,
            tone: isFailure ? Tone.danger : Tone.success,
          ),
        ),
        // The outcome mark and the command it judges are two halves of one
        // statement.
        const BaseGap(Proximity.related),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  // The command and the actions on it are members of one row.
                  const BaseGap(Proximity.related),
                  BaseIconButton(
                    icon: IconRole.copy,
                    size: ButtonSize.small,
                    tooltip: l10n.tooltipCopyCommand,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: log.command));
                      // The clipboard holds the command: something that
                      // finished, and finished well. How long "brief" lasts
                      // is the skin's answer, so the one second goes with the
                      // construction.
                      Overlays.notify(
                        context,
                        NoticeSpec(
                          tone: Tone.success,
                          title: l10n.commandCopiedToClipboard,
                        ),
                      );
                    },
                  ),
                ],
              ),
              // The command and the facts about that run are two halves of one
              // entry.
              const BaseGap(Proximity.hairline),
              _buildMeta(context),
            ],
          ),
        ),
      ],
    );
  }

  /// The facts about the run: how many times it repeated, whether it failed,
  /// when it ran and how long it took.
  Widget _buildMeta(BuildContext context) {
    final group = widget.group;
    final log = group.representative;
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (group.count > 1) ...[
          Container(
            // A count pill keeps its own tight horizontal measure, which no
            // rung names - see the report.
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.paddingXS,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: colorScheme.onSecondaryContainer),
              child: BaseLabel('x${group.count}', role: TextRole.micro),
            ),
          ),
          // Two facts about the same run, side by side.
          const BaseGap(Proximity.related),
        ],
        if (log.isFailure) ...[
          Container(
            // Same pill measure as the count beside it.
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.paddingXS,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: colorScheme.onErrorContainer),
              child: BaseLabel(
                '${l10n.failed} (${log.exitCode})',
                role: TextRole.micro,
              ),
            ),
          ),
          // Two facts about the same run, side by side.
          const BaseGap(Proximity.related),
        ],
        Flexible(
          child: BaseLabel(
            log.timestampDisplay(Localizations.localeOf(context).languageCode),
            role: TextRole.micro,
            tone: Tone.muted,
            // A timestamp is one line; the `Flexible` around it exists to let
            // it shrink, not to let it wrap.
            maxLines: 1,
          ),
        ),
        if (log.duration != null) ...[
          // When it ran and how long it took are two facts of one line.
          const BaseGap(Proximity.related),
          BaseLabel(
            '${log.duration!.inMilliseconds}ms',
            role: TextRole.micro,
            tone: Tone.muted,
          ),
        ],
      ],
    );
  }

  /// What the entry reveals: every run of the burst that produced output, so
  /// grouping never hides an individual run's.
  ///
  /// It carries its own horizontal inset because the member insets the HEADER
  /// and reveals the body underneath it unpadded; the trailing gap is the last
  /// run's distance from the card's own bottom edge.
  Widget _buildOutput(BuildContext context) {
    final group = widget.group;
    final colorScheme = Theme.of(context).colorScheme;
    return BaseInset(
      y: Inset.none,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const BaseSeparator(),
          for (final entry in group.entries)
            if (entry.fullOutput.isNotEmpty) ...[
              if (group.count > 1) ...[
                // One run of the burst and the next.
                const BaseGap(Proximity.related),
                BaseLabel(
                  entry.timestampDisplay(
                    Localizations.localeOf(context).languageCode,
                  ),
                  role: TextRole.micro,
                  tone: Tone.muted,
                ),
              ],
              // The run and the output it produced are two parts of one
              // statement.
              const BaseGap(Proximity.related),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                // The output block is a region of its own inside the entry and
                // reads at the ordinary distance from its own edges.
                child: BaseInset(
                  all: Inset.normal,
                  // A dense repeating code surface, one step SMALLER than
                  // `TextRole.code`: the site distinguishes the command
                  // headline (code, bodyMedium) from the output under it
                  // (labelMedium), and the vocabulary has one word for code,
                  // so naming the role here would grow every output line ~16%
                  // - the same class of regression the blame view's inset took
                  // (#426), one axis over. The block is a code-block surface:
                  // its fill, corner, inset and type step all belong to the
                  // member it is waiting for, and the style stays written out
                  // until that member exists.
                  //
                  // Its two colours stay with it. They mean `Tone.danger` and
                  // `Tone.neutral` - "this run failed" against ordinary output
                  // - but a tone is only sayable through `BaseLabel`, and
                  // `BaseLabel` would bring `TextRole.code`'s size with it and
                  // grow every output line. Naming the meaning here would cost
                  // the very regression the paragraph above avoids.
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
              ),
            ],
          // The last run's output and the card's own bottom edge.
          const BaseGap(Proximity.grouped),
        ],
      ),
    );
  }
}
