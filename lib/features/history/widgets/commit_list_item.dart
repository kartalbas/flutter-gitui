import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        ControlScale,
        GraphEdgeSpec,
        GraphGutterSpec,
        GraphRowSpec,
        IconRole,
        Proximity,
        Skin,
        SkinScope,
        TextRole,
        Tone;

import '../../../shared/components/base_badge.dart';
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
      // height. The reservation is `surfaces.commitGraphGutter`: the skin
      // that paints the lanes answers how much room they need, so the one
      // number the graph conversion could not take with it - the gutter's
      // width - now lives on the skin's side of the line too. Without lanes a
      // plain dot still marks the commit.
      leading: !showCommitGraph
          ? null
          : row != null
          ? SkinScope.render(
              context,
              (Skin skin, BuildContext inner) =>
                  skin.surfaces.commitGraphGutter(
                    inner,
                    GraphGutterSpec(laneCount: graphLaneCount),
                  ),
            )
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
              // Which branches and tags point at this commit. Each is a named
              // mark riding on the row - the badge member's own question - and
              // it says nothing beyond the name, which is what `neutral`
              // means. It used to be a hand-painted `secondaryContainer` box
              // with a `secondary`-at-30 % hairline, a 4 dp corner, a 6/2
              // inset and a glyph whose size and colour were spelled out
              // beside the word; every one of those is the skin's now. The
              // whole point of the mark travelling as an `IconRole` is that
              // the pairing can no longer disagree with the label beside it,
              // because one member paints both.
              children: commit.refs
                  .map(
                    (ref) => BaseBadge(
                      label: ref,
                      icon: ref.contains('tag:')
                          ? IconRole.tag
                          : IconRole.gitBranch,
                      size: BadgeSize.small,
                    ),
                  )
                  .toList(),
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
