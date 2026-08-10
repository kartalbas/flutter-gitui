import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        DialogExtent,
        DialogRouteSpec,
        IconRole,
        Inset,
        Overlays,
        Proximity,
        TextRole,
        Tone;
import 'package:path/path.dart' as path;
import 'package:timeago/timeago.dart' as timeago;

import '../../generated/app_localizations.dart';
import '../../core/git/git_providers.dart';
import '../../core/git/models/blame.dart';
import '../components/base_label.dart';
import '../components/base_progress.dart';
import '../components/base_viewer_dialog.dart';
import '../components/base_card.dart';
import '../components/base_layout.dart';
import '../widgets/empty_state.dart';

/// Blame dialog for viewing file blame information
class BlameDialog extends ConsumerWidget {
  final String filePath;

  const BlameDialog({super.key, required this.filePath});

  /// Factory constructor for showing blame dialog
  factory BlameDialog.show({
    required BuildContext context,
    required String filePath,
  }) {
    Overlays.dialogFrom(
      context,
      route: DialogRouteSpec(
        title: AppLocalizations.of(context)!.blame,
        extent: DialogExtent.browser,
      ),
      builder: (context) => BlameDialog(filePath: filePath),
    );
    return BlameDialog(filePath: filePath);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileName = path.basename(filePath);
    final blameAsync = ref.watch(fileBlameProvider(filePath));
    final l10n = AppLocalizations.of(context)!;

    return BaseViewerDialog(
      icon: IconRole.userList,
      title: l10n.blame,
      subtitle: fileName,
      content: blameAsync.when(
        data: (blame) {
          if (blame == null) {
            return _buildError(context, l10n.couldNotLoadBlame);
          }
          return _buildBlameView(context, blame);
        },
        loading: () => const BaseProgress.block(),
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

    return BaseCard(
      inset: Inset.none,
      content: ListView.builder(
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          return _buildCommitGroup(context, group, index);
        },
      ),
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
        currentLines.add(lines[i]);
      } else {
        groups.add(CommitGroup(commitHash: currentCommit, lines: currentLines));
        currentCommit = lines[i].commitHash;
        currentLines = [lines[i]];
      }
    }

    // Add the last group
    groups.add(CommitGroup(commitHash: currentCommit, lines: currentLines));

    return groups;
  }

  Widget _buildCommitGroup(BuildContext context, CommitGroup group, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final firstLine = group.lines.first;
    final isEven = index % 2 == 0;

    return Container(
      decoration: BoxDecoration(
        color: isEven
            ? colorScheme.surfaceContainerLowest
            : colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left column: Commit metadata (only shown once per group)
            Container(
              width: 280,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Commit hash
                  BaseLabel(
                    firstLine.commitHash.substring(0, 7),
                    role: TextRole.detail,
                    tone: Tone.accent,
                  ),
                  const BaseGap(Proximity.hairline),
                  // Author
                  BaseLabel(firstLine.author, role: TextRole.itemTitle),
                  // The author and the date are two halves of one statement,
                  // which is what hairline says. It used to be a literal 2 and
                  // the same pairing is 4 elsewhere in the application: one
                  // meaning said with two numbers, unified upward here.
                  const BaseGap(Proximity.hairline),
                  // Date
                  BaseLabel(
                    timeago.format(firstLine.authorTime),
                    role: TextRole.detail,
                    tone: Tone.muted,
                  ),
                  const BaseGap(Proximity.related),
                  // Summary
                  BaseLabel(
                    firstLine.summary,
                    role: TextRole.detail,
                    tone: Tone.muted,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            // Right column: Code lines
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: group.lines.map((line) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Line number
                        SizedBox(
                          width: 50,
                          child: BaseLabel(
                            line.lineNumber.toString(),
                            role: TextRole.detail,
                            tone: Tone.muted,
                            align: TextAlign.right,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Line content. Still a hand-set style, and the
                        // blocker is `height: 1.2`: `BaseLabel(TextRole.code)`
                        // says "monospaced, because alignment is meaning here"
                        // and says nothing about leading, so converting would
                        // hand every blame line Material's own 1.43 and make
                        // the view taller - #426 verbatim, which is the one
                        // mistake this conversion is not allowed to repeat.
                        // The scheme's `onSurface` that sat beside it is gone
                        // (#432): every text-theme step already carries the
                        // scheme's on-surface
                        // (AppTheme._brightnessCorrectedTextTheme), so the
                        // read restated the ambient foreground and deleting
                        // it moves no pixel - it never needed a `Tone` or a
                        // `BaseLabel`, because it never said anything the
                        // ramp does not. The leading still waits for a word
                        // for how tightly a run of code is set.
                        Expanded(
                          child: SelectableText(
                            line.lineContent.isEmpty ? ' ' : line.lineContent,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontFamily: 'monospace',
                                  height: 1.2,
                                ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(PhosphorIconsRegular.userList, size: 48),
          const BaseGap(Proximity.grouped),
          BaseLabel(
            AppLocalizations.of(context)!.couldNotLoadBlame,
            role: TextRole.pageTitle,
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, String error) {
    // The facade (#430), now that its hero can say a failure (#431). The
    // reason recorded here for staying hand-built was that the facade "wants a
    // headline and a sentence" and this state says one thing - which the
    // facade file itself disproves: `ErrorState` is a one-statement state,
    // built out of this same member with `message: ''`. So the shape was never
    // the blocker; the hero's colour was, and it is a `Tone` now.
    //
    // The git error is passed through as the statement rather than routed via
    // `ErrorState`, which would prefix it with its own localized "Error:" and
    // change what the user reads. One delta rides along and is deliberate: the
    // hero goes from this copy's 48 dp to the member's 64, because the size is
    // the member's answer and a copy that will not follow the member is not a
    // copy. Its COLOUR is unchanged: the facade answers `Tone.danger` with the
    // very scheme role this mark was naming by hand. `_buildEmptyState` above
    // keeps its own 48 for now - that mark states no colour at all, so it has
    // no read to convert and resizing it alone would be a pure appearance
    // change.
    return EmptyStateWidget(
      icon: PhosphorIconsRegular.warningCircle,
      title: error,
      message: '',
      tone: Tone.danger,
    );
  }
}

/// Helper class to group consecutive lines by commit
class CommitGroup {
  final String commitHash;
  final List<BlameLine> lines;

  CommitGroup({required this.commitHash, required this.lines});
}

/// Show blame dialog for a file
Future<void> showBlameDialog(BuildContext context, {required String filePath}) {
  return Overlays.dialogFrom(
    context,
    route: DialogRouteSpec(
      title: AppLocalizations.of(context)!.blame,
      extent: DialogExtent.browser,
    ),
    builder: (context) => BlameDialog(filePath: filePath),
  );
}
