import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Inset, Proximity, TextRole, Tone;
import 'package:path/path.dart' as path;
import 'package:timeago/timeago.dart' as timeago;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_layout.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_viewer_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../core/git/git_providers.dart';
import '../../../core/git/models/blame.dart';
import '../../history/widgets/commit_details_panel.dart';
import '../../history/widgets/file_tree_panel.dart';

/// GitHub-style Git Blame panel with two-column layout
/// Left: Commit metadata (grouped by commit)
/// Right: Full code with line numbers
class FileBlamePanel extends ConsumerWidget {
  final String filePath;

  const FileBlamePanel({super.key, required this.filePath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileName = path.basename(filePath);
    final blameAsync = ref.watch(fileBlameProvider(filePath));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.blame),
            BaseLabel(fileName, role: TextRole.detail, tone: Tone.muted),
          ],
        ),
        actions: [
          BaseIconButton(
            icon: IconRole.info,
            tooltip: AppLocalizations.of(context)!.tooltipBlameStatistics,
            onPressed: () => blameAsync.value != null
                ? _showBlameInfo(context, blameAsync.value!)
                : null,
          ),
          BaseIconButton(
            icon: IconRole.arrowClockwise,
            tooltip: AppLocalizations.of(context)!.refresh,
            onPressed: () {
              ref.invalidate(fileBlameProvider(filePath));
            },
          ),
        ],
      ),
      body: blameAsync.when(
        data: (blame) {
          if (blame == null) {
            return _buildError(
              context,
              AppLocalizations.of(context)!.couldNotLoadBlame,
            );
          }
          return _buildBlameView(context, blame);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildError(context, error.toString()),
      ),
    );
  }

  Widget _buildBlameView(BuildContext context, FileBlame blame) {
    if (blame.lines.isEmpty) {
      return _buildEmptyState(context);
    }

    // Group consecutive lines by commit
    final groups = _groupLinesByCommit(blame.lines);

    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return _buildCommitGroup(context, group, index);
      },
    );
  }

  /// Groups consecutive lines that share the same commit hash
  List<CommitGroup> _groupLinesByCommit(List<BlameLine> lines) {
    final groups = <CommitGroup>[];

    if (lines.isEmpty) return groups;

    var currentCommit = lines[0].commitHash;
    var currentLines = <BlameLine>[lines[0]];

    for (var i = 1; i < lines.length; i++) {
      if (lines[i].commitHash == currentCommit) {
        // Same commit, add to current group
        currentLines.add(lines[i]);
      } else {
        // Different commit, save current group and start new one
        groups.add(
          CommitGroup(
            commitHash: currentCommit,
            lines: List.from(currentLines),
          ),
        );
        currentCommit = lines[i].commitHash;
        currentLines = [lines[i]];
      }
    }

    // Add last group
    groups.add(CommitGroup(commitHash: currentCommit, lines: currentLines));

    return groups;
  }

  Widget _buildCommitGroup(
    BuildContext context,
    CommitGroup group,
    int groupIndex,
  ) {
    final firstLine = group.lines.first;
    final lineCount = group.lines.length;

    // Alternate background colors for better visual separation
    final isEven = groupIndex % 2 == 0;
    final backgroundColor = isEven
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Theme.of(context).colorScheme.surface;

    return Container(
      decoration: BoxDecoration(color: backgroundColor),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left column: Commit metadata (fixed width)
            Container(
              width: 240,
              decoration: BoxDecoration(
                color: backgroundColor,
                border: Border(
                  right: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
              ),
              child: _buildCommitMetadata(context, firstLine, lineCount),
            ),

            // Right column: Code lines
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: group.lines.map((line) {
                  return _buildCodeLine(context, line);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommitMetadata(
    BuildContext context,
    BlameLine line,
    int lineCount,
  ) {
    final relativeTime = timeago.format(line.authorTime, locale: 'en_short');

    return Tooltip(
      message: _buildFullCommitTooltip(line),
      preferBelow: false,
      child: InkWell(
        onTap: () => _showCommitDetails(context, line),
        child: BaseInset(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Author with avatar
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    // The avatar's fill decides its own foreground; saying
                    // the pairing here was Material's on-colour model leaking
                    // into a screen.
                    child: BaseLabel(line.authorInitials, role: TextRole.micro),
                  ),
                  const BaseGap(Proximity.related),
                  Expanded(
                    child: BaseLabel(
                      line.author,
                      role: TextRole.detail,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),

              const BaseGap(Proximity.related),

              // Relative time
              Row(
                children: [
                  // The inline-metadata mark beside a detail line, at the one
                  // scale the application uses for that job everywhere:
                  // `compact`. It was drawn here at 12 and at 16 in the branch
                  // list, which was one meaning said with two numbers.
                  const BaseIcon(
                    IconRole.clock,
                    scale: ControlScale.compact,
                    tone: Tone.muted,
                  ),
                  const BaseGap(Proximity.hairline),
                  BaseLabel(
                    relativeTime,
                    role: TextRole.detail,
                    tone: Tone.muted,
                  ),
                ],
              ),

              const BaseGap(Proximity.related),

              // Commit hash (clickable)
              Container(
                // The chip's fill and corner stay: they are the surface. Its
                // inset stays a literal: 6 sits between `hairline` and
                // `tight` on a ladder that skips it, and the chip rides the
                // blame gutter, where a line's height is how much code fits
                // on the screen - rounding either axis would resize every
                // gutter chip.
                //
                // Decided in #438: it does NOT wait for `surfaces.badge` any
                // more. Its fill names a Material CONTAINER role
                // (`secondaryContainer`), and a contract tone for a container
                // role is un-promisable - neither Fluent nor macOS has a
                // paired-container concept (the vocabulary's own `Tone.
                // onAccent` note records that asymmetry), so the word would
                // be Material's containment model crossing the seam under a
                // neutral name. Nor is a hash chip a badge at all: its
                // content is code the user reads, its label rides the type
                // ramp, and its geometry rides the gutter. If a word ever
                // earns its place here it is an inline-code span - every
                // language has that idiom - which is a new member to derive
                // from need, not a growth of the badge.
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                // The chip paints its own fill and states the foreground
                // that pairs with it; the hash inside reads it.
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  child: BaseLabel(line.shortHash, role: TextRole.micro),
                ),
              ),

              const BaseGap(Proximity.related),

              // Commit summary (first line)
              BaseLabel(line.summary, role: TextRole.detail, maxLines: 2),

              // Line count indicator if group has multiple lines
              if (lineCount > 1) ...[
                const BaseGap(Proximity.related),
                BaseLabel(
                  AppLocalizations.of(context)!.linesCount(lineCount),
                  role: TextRole.micro,
                  tone: Tone.muted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeLine(BuildContext context, BlameLine line) {
    return BaseInset(
      // A code line is as dense vertically as a row can be and reads at the
      // ordinary distance from the gutter: the two axes genuinely answer
      // differently, which is why `inset` takes them separately.
      x: Inset.normal,
      y: Inset.hairline,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line number
          SizedBox(
            width: 50,
            // "Secondary", said once. The alpha on top was the same
            // statement a second time, in numbers - and how faint secondary
            // text is belongs to the skin.
            child: BaseLabel(
              line.lineNumber.toString(),
              role: TextRole.detail,
              tone: Tone.muted,
              align: TextAlign.right,
            ),
          ),

          const BaseGap(Proximity.grouped),

          // Code content
          Expanded(
            // The colour word is gone and nothing else moved, which is the
            // point. `Tone.neutral` is "whatever this surface's ordinary
            // foreground is", and the ramp this style is built from already
            // carries exactly that - `_brightnessCorrectedTextTheme` stamps the
            // scheme's on-surface role on every step of it - so naming that
            // role again here was the ambient answer restated in Material's
            // words.
            // The rest of the style stays hand-built and stays a finding:
            // `TextRole.code` is the only member that can say "this is code",
            // and it renders bodyMedium in the user's mono family with no 1.2
            // line height, which would make every blame line taller and wider.
            // That is #426 exactly, so the style waits for the member that can
            // carry a gutter's density.
            child: SelectableText(
              line.lineContent,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // The facade rather than a fourth hand-built copy of it (#430). The `64`
    // and the on-surface-variant role that stood here are one decision,
    // and it is the member's: `EmptyStateSpec` takes an icon, a headline, a
    // sentence and the ways out, and no size, so a size at a call site is a
    // leak by construction and the colour paired with it goes the same way.
    return EmptyStateWidget(
      icon: PhosphorIconsRegular.file,
      title: l10n.emptyFile,
      message: l10n.noContent,
    );
  }

  Widget _buildError(BuildContext context, String error) {
    // The facade, now that the one fact holding this column back is sayable
    // (#431). The mark stood here hand-built because `EmptyStateWidget`
    // painted every hero in the supporting foreground, so adopting it would
    // have repainted a red failure mark neutral - and no read could move on
    // its own either, because a colour reaches a mark only through a member
    // or `BaseIcon`. `Tone.danger` is that colour said as a meaning: the mark
    // stays red because the STATE says failure, not because this panel named
    // the scheme's error role. The `64` goes with it, for the reason
    // `_buildEmptyState` above already records - a member that accepts no size
    // owns the size - and the roomy hold-off around the message becomes the
    // member's own, which is where an empty state's breathing room belonged
    // all along.
    return EmptyStateWidget(
      icon: PhosphorIconsRegular.warningCircle,
      title: AppLocalizations.of(context)!.errorLoadingBlame,
      message: error,
      tone: Tone.danger,
    );
  }

  String _buildFullCommitTooltip(BlameLine line) {
    return '''
Commit: ${line.commitHash}
Author: ${line.author} <${line.authorEmail}>
Date: ${line.authorTime}

${line.summary}
''';
  }

  void _showCommitDetails(BuildContext context, BlameLine line) async {
    // Fetch the full commit details using the git service
    final ref = ProviderScope.containerOf(context);
    final gitService = ref.read(gitServiceProvider);

    if (gitService == null) {
      return;
    }

    try {
      // Get the full commit object by specifying the commit hash directly
      // Don't use range syntax (^..) as it fails for boundary commits
      final result = await gitService.getLog(limit: 1, branch: line.commitHash);

      final commits = result.unwrapOr([]);

      if (commits.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Commit not found in repository history'),
            ),
          );
        }
        return;
      }

      final commit = commits.first;

      if (!context.mounted) return;

      // Show commit details with files in a dialog (similar to History screen)
      final l10n = AppLocalizations.of(context)!;
      BaseViewerDialog.show(
        context: context,
        dialog: BaseViewerDialog(
          icon: IconRole.gitCommit,
          title: l10n.commitShortHash(line.shortHash),
          subtitle: commit.subject,
          content: Row(
            children: [
              // Left: Commit details panel
              Expanded(
                flex: 1,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: CommitDetailsPanel(commit: commit),
                ),
              ),

              // Right: Changed files panel
              Expanded(
                flex: 1,
                child: FileTreePanel(commitHash: line.commitHash),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.snackbarErrorLoadingCommit(e.toString())),
          ),
        );
      }
    }
  }

  /// The label/value pairs of the statistics, as a two-column grid.
  ///
  /// The label column sizes itself to the longest label and every row shares
  /// that width, so the values line up. It used to be a fixed 60 pixels, which
  /// is narrower than "Total Lines:" even in English: the label wrapped inside
  /// the word and the top-aligned value ended up beside its first line, reading
  /// as a superscript. A fixed width could not hold anyway - the same labels are
  /// longer in every other locale ("Zeilen gesamt:", "Líneas Totales:").
  Widget _buildStatistics(BuildContext context, FileBlame blame) {
    final l10n = AppLocalizations.of(context)!;
    return Table(
      columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _buildStatisticRow(context, l10n.totalLines, '${blame.totalLines}'),
        _buildStatisticRow(
          context,
          l10n.authors,
          '${blame.uniqueAuthors.length}',
        ),
        _buildStatisticRow(
          context,
          l10n.commitsLabel,
          '${blame.uniqueCommits.length}',
        ),
      ],
    );
  }

  TableRow _buildStatisticRow(
    BuildContext context,
    String label,
    String value,
  ) {
    return TableRow(
      children: [
        BaseInset(
          x: Inset.none,
          y: Inset.tight,
          child: BaseLabel('$label:', role: TextRole.sectionTitle),
        ),
        // The value column is indented from its label and set off vertically
        // by the same amount as the label beside it. Said as two axes rather
        // than as three sides, which is what `inset` can express without a
        // per-side rung being minted for it.
        BaseInset(
          x: Inset.normal,
          y: Inset.tight,
          // The whole of this site's style was one colour word, so there is
          // nothing left for a hand-built `TextStyle` to carry: the value the
          // statistic states is ordinary prose the user reads, and staying
          // copyable is behaviour rather than appearance, which is the one
          // thing `BaseLabel` still takes. `Tone.neutral` is what the colour
          // said - the dialog's own foreground - and it is now said by not
          // naming a colour at all.
          child: BaseLabel(value, role: TextRole.body, selectable: true),
        ),
      ],
    );
  }

  void _showBlameInfo(BuildContext context, FileBlame blame) {
    showDialog(
      context: context,
      builder: (context) => BaseDialog(
        title: AppLocalizations.of(context)!.blameStatistics,
        onSubmit: () => Navigator.pop(context),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatistics(context, blame),
              const BaseGap(Proximity.grouped),
              BaseLabel(
                AppLocalizations.of(context)!.contributors,
                role: TextRole.sectionTitle,
              ),
              // A section title and the list under it are two parts of one
              // statement; each row of that list is indented under it and
              // separated from the row above. Two statements, two words -
              // rather than one four-sided number saying both at once.
              const BaseGap(Proximity.related),
              ...blame.uniqueAuthors.expand((author) {
                final lineCount = blame.linesByAuthor[author]?.length ?? 0;
                final percentage = (lineCount / blame.totalLines * 100)
                    .toStringAsFixed(1);
                return <Widget>[
                  const BaseGap(Proximity.related),
                  BaseInset(
                    x: Inset.normal,
                    y: Inset.none,
                    child: BaseLabel(
                      '• $author: $lineCount lines ($percentage%)',
                      role: TextRole.body,
                    ),
                  ),
                ];
              }),
            ],
          ),
        ),
        actions: [
          // A statistics sheet with nothing to answer: acknowledging it is
          // what completes it, which is what onSubmit fires too.
          DialogAction(
            label: AppLocalizations.of(context)!.close,
            role: DialogActionRole.affirmative,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

/// Helper class to group consecutive lines from the same commit
class CommitGroup {
  final String commitHash;
  final List<BlameLine> lines;

  CommitGroup({required this.commitHash, required this.lines});
}
