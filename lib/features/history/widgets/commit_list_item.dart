import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        ControlScale,
        GraphEdgeSpec,
        GraphRowSpec,
        IconRole,
        Proximity,
        Skin,
        SkinScope,
        TextRole,
        Tone;

import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_list_item.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_layout.dart';
import '../../../core/config/config_providers.dart';
import '../../../core/git/models/commit.dart';
import '../models/commit_graph.dart';

/// Individual commit item in the history list
class CommitListItem extends ConsumerWidget {
  final GitCommit commit;
  final bool isSelected;
  final bool isMultiSelected;
  final VoidCallback onTap;
  final String? currentBranch;

  /// This commit's precomputed lanes, or null when the displayed list is not
  /// the window the graph pass walked (an in-memory filter removed rows).
  final CommitGraphRow? graphRow;

  /// Lane columns of the whole window, so every row reserves the same width
  /// and the lanes line up vertically.
  final int graphLaneCount;

  /// Right-click handler, handed the global cursor position so the caller
  /// can anchor a context menu on the commit under the cursor.
  final void Function(Offset globalPosition)? onSecondaryTap;

  /// Whether the commit list holds keyboard focus, so the highlighted row
  /// wears its focus ring only while the keyboard actually lives there.
  final bool containerHasFocus;

  const CommitListItem({
    super.key,
    required this.commit,
    required this.isSelected,
    required this.onTap,
    this.isMultiSelected = false,
    this.currentBranch,
    this.graphRow,
    this.graphLaneCount = 0,
    this.onSecondaryTap,
    this.containerHasFocus = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showCommitGraph = ref.watch(showCommitGraphProvider);
    final row = graphRow;

    final listItem = BaseListItem(
      isSelected: isSelected,
      isMultiSelected: isMultiSelected,
      containerHasFocus: containerHasFocus,
      onTap: onTap,
      onSecondaryTap: onSecondaryTap,
      // With lanes available the leading slot only reserves their width; the
      // drawing happens in the overlay below, which can span the full row
      // height. Without lanes a plain dot still marks the commit.
      leading: !showCommitGraph
          ? null
          : row != null
          ? SizedBox(width: _graphGutterWidthFor(graphLaneCount))
          : Padding(
              // Not a rung, and deliberately not rounded onto one: this nudges
              // the dot down so its centre meets the cap height of the subject
              // line beside it. That is an optical alignment against one line
              // of text, which is neither a gap between two neighbours nor a
              // container's breathing room, and `BaseInset` has no per-side
              // form to say it with. It waits for the row surface.
              padding: const EdgeInsets.only(top: 2),
              // The graph node is a drawn SHAPE, not a glyph and not text: a
              // 12 dp disc with a 2 dp ring. Both of its colours are therefore
              // a fill and a border rather than a foreground, which is the one
              // class of read this conversion deliberately leaves where it is
              // - they disappear together when the row becomes a skin member
              // and the lanes become `Tone.series`. There is also no legal way
              // to say them: a tone reaches a mark only through `BaseIcon` or
              // `BaseLabel`, and neither draws a circle.
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: commit.isMergeCommit
                      ? Theme.of(context).colorScheme.tertiary
                      : Theme.of(context).colorScheme.primary,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.onSurface,
                    width: 2,
                  ),
                ),
              ),
            ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject line. No colour: BaseListItem publishes the foreground its
          // tile needs, which is `onSurface` on an unselected row and the role
          // that clears 4.5 : 1 on the selected tile. Naming
          // `onSecondaryContainer` here reinstated the M3 pairing that misses
          // it at 4.45 : 1 in the dark theme.
          BaseLabel(commit.shortSubject, role: TextRole.body, maxLines: 2),

          // A subject and the lines qualifying it are two halves of one
          // thing: `hairline`.
          const BaseGap(Proximity.hairline),

          // Refs (branches, tags)
          if (commit.refs.isNotEmpty) ...[
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: commit.refs.map((ref) {
                return Container(
                  // The badge's fill, border and corner stay: they are the
                  // surface. Its inset and its internal gap stay literals
                  // too: 6 sits between `hairline` and `tight` on a ladder
                  // that skips it - the same between-the-rungs distance
                  // file_list_item.dart's status badge records - and this
                  // badge rides inside the densest list in the application,
                  // so rounding either number would widen every ref chip.
                  // Both wait for `surfaces.badge`, whose skin owns a
                  // badge's measure.
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: 0.3),
                    ),
                  ),
                  // The chip is painted here, so the pairing is stated
                  // here: its label reads the foreground rather than naming
                  // one, and cannot disagree with the glyph beside it.
                  child: DefaultTextStyle.merge(
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // The glyph keeps its explicit size and colour
                        // because it is painted ON the badge's own fill: the
                        // pairing that colour states is the surface's, and
                        // it leaves with the surface rather than with this
                        // sweep.
                        Icon(
                          ref.contains('tag:')
                              ? PhosphorIconsRegular.tag
                              : PhosphorIconsRegular.gitBranch,
                          size: 10,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 2),
                        BaseLabel(ref, role: TextRole.micro),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const BaseGap(Proximity.hairline),
          ],

          // Author and time. Both lines are secondary to the subject
          // above them, which is what `Tone.muted` says — and it says it
          // once, for both row states, because the skin resolves "secondary"
          // against whatever foreground the row has published. The two
          // glyphs no longer restate the row's selection state either:
          // `BaseListItem` publishes an `IconTheme` (base_list_item.dart:328)
          // that already carries `onSurfaceVariant` on an unselected row and
          // a contrast-corrected on-colour on a selected one, so the ternary
          // here was the row's own answer copied out by hand — and the copy
          // is what let the glyph and the word beside it drift apart.
          Row(
            children: [
              // The inline-metadata marks of a row: one job, one scale. They
              // were drawn at 12 here and at 16 in the branch list for the
              // same job, which was one meaning said with two numbers;
              // `compact` is the meaning.
              const BaseIcon(IconRole.user, scale: ControlScale.compact),
              const BaseGap(Proximity.hairline),
              Flexible(
                child: BaseLabel(
                  commit.author,
                  role: TextRole.detail,
                  tone: Tone.muted,
                  maxLines: 1,
                ),
              ),
              const BaseGap(Proximity.related),
              const BaseIcon(IconRole.clock, scale: ControlScale.compact),
              const BaseGap(Proximity.hairline),
              Flexible(
                child: BaseLabel(
                  commit.authorDateDisplay(
                    Localizations.localeOf(context).languageCode,
                  ),
                  role: TextRole.detail,
                  tone: Tone.muted,
                  maxLines: 1,
                ),
              ),
            ],
          ),

          // The same relationship the line above states, said with the same
          // word rather than with a second number.
          const BaseGap(Proximity.hairline),

          // Short hash and current branch, the same statement one line down.
          Row(
            children: [
              BaseLabel(
                commit.shortHash,
                role: TextRole.detail,
                tone: Tone.muted,
              ),
              if (currentBranch != null) ...[
                const BaseGap(Proximity.related),
                // The same inline-metadata mark as the row above, which used
                // to be drawn at 11 - a number on no ladder in the
                // application - for want of a word for the job.
                const BaseIcon(IconRole.gitBranch, scale: ControlScale.compact),
                const BaseGap(Proximity.hairline),
                BaseLabel(currentBranch!, role: TextRole.micro),
              ],
            ],
          ),
        ],
      ),
    );

    if (!showCommitGraph || row == null) {
      return listItem;
    }

    // The overlay, not the leading widget, carries the graph: only here does
    // it cover the full item height, divider strip included, so this row's
    // lane lines meet the neighboring rows' without gaps. The `Stack` and the
    // fill are structure and stay here; everything drawn inside them is
    // `surfaces.commitGraphRow` (#249, P5), which is why this file no longer
    // names a lane width, a dot radius, a stroke, a divider strip or a colour.
    // The member ignores pointers itself, so the item underneath keeps
    // receiving taps.
    return Stack(
      children: [
        listItem,
        Positioned.fill(
          child: SkinScope.render(context, (Skin skin, BuildContext inner) {
            return skin.surfaces.commitGraphRow(
              inner,
              GraphRowSpec(
                lane: row.lane,
                // An INDEX into the skin's own series, never a colour: the
                // lane cycle and its length are the skin's, exactly as they
                // are for `Tone.series`.
                toneIndex: row.colorIndex,
                isMerge: row.isMerge,
                // A COUNT, not a width. How wide the gutter has to be for
                // this many columns is the skin's arithmetic.
                laneCount: graphLaneCount,
                incoming: _edges(row.incoming),
                outgoing: _edges(row.outgoing),
                passing: _edges(row.passing),
              ),
            );
          }),
        ),
      ],
    );
  }

  /// One row's edges, as data the skin paints.
  static List<GraphEdgeSpec> _edges(List<GraphEdge> edges) => <GraphEdgeSpec>[
    for (final edge in edges)
      GraphEdgeSpec(lane: edge.lane, toneIndex: edge.colorIndex),
  ];
}

/// How much room the row's leading slot reserves so the lanes and the subject
/// text never overlap.
///
/// **This is the one number `surfaces.commitGraphRow` could not take with it.**
/// The member fills the box it is given rather than sizing itself - it has to,
/// because the graph spans the whole row including its rule strip, and a
/// painter confined to the leading slot would leave a gap at every row
/// boundary. So the row must reserve the gutter's width, and the width is the
/// skin's lane width times the columns in play - which the contract states
/// nowhere the application can read. `GraphRowSpec.laneCount` deliberately
/// carries a COUNT so the skin owns the width, and there is no member, no
/// vocabulary word and no metric query that hands the count back as a width.
///
/// Until the contract can answer "how wide is your graph gutter for n lanes",
/// this reproduces the Material skin's own arithmetic and is therefore a
/// reported drift rather than a hidden one: a skin with a different lane width
/// - or, like the blueprint, with no drawn graph at all - gets a gutter sized
/// for Material's. See the P5 report for #249.
double _graphGutterWidthFor(int laneCount) => 12.0 * laneCount.clamp(1, 8);
