import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

/// One file's diff stat as one mark: how many lines arrived beside how many
/// left.
///
/// A façade over `surfaces.badge`, on the same terms as `BaseBadge`: the
/// application states its facts in its own words - two counts - and this
/// widget translates them into the contract's (`+12` at [Tone.gitAdded]
/// paired with `-3` at [Tone.gitDeleted], at [ControlScale.compact] because
/// the stat rides a dense tree row). The pill's whole measure - whether the
/// pair shares a surface, what fills it, how the halves are separated - is
/// the skin's.
///
/// A stat with nothing to say renders nothing: the hand-painted construction
/// this replaces drew an empty chip for a file with zero counted lines (a
/// binary file), which was a surface standing for no fact.
class DiffStatBadge extends StatelessWidget {
  /// Declares one diff stat.
  const DiffStatBadge({
    super.key,
    required this.additions,
    required this.deletions,
  });

  /// How many lines this change adds.
  final int additions;

  /// How many lines this change removes.
  final int deletions;

  @override
  Widget build(BuildContext context) {
    if (additions <= 0 && deletions <= 0) return const SizedBox.shrink();
    return SkinScope.render(context, (Skin skin, BuildContext inner) {
      final bool hasBoth = additions > 0 && deletions > 0;
      return skin.surfaces.badge(
        inner,
        BadgeSpec(
          label: additions > 0 ? '+$additions' : '-$deletions',
          tone: additions > 0 ? Tone.gitAdded : Tone.gitDeleted,
          secondary: hasBoth
              ? BadgeFact(label: '-$deletions', tone: Tone.gitDeleted)
              : null,
          scale: ControlScale.compact,
        ),
      );
    });
  }
}
