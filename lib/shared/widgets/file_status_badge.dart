import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show TextRole, Tone;

import '../theme/app_theme.dart';
import '../components/base_label.dart';

/// The one drawing of the git status pill: a file's status on its own tinted
/// wash.
///
/// The changes list, the changes tree, the browse tree and the commit dialog
/// all state this same meaning, and before P3d two of them hand-painted their
/// own copy at a different inset (h6/v2 against this component's h4/v2) - one
/// meaning, two insets, which is exactly the disagreement a component exists
/// to prevent. The copies now render through this widget, and the pill's
/// measure is stated once, here, until `surfaces.badge` makes it the skin's.
///
/// Used to show git status indicators like 'M' for modified, 'A' for added -
/// and equally the status spelled out ('Modified'), which is the same pill
/// saying the same fact in more letters.
class FileStatusBadge extends StatelessWidget {
  /// The text on the pill: a status code ('M', 'A') or the status's name
  /// ('Modified').
  final String code;

  /// The color for the badge background and text
  final Color color;

  /// What the status MEANS, where the site knows it. When set, the label
  /// carries this tone instead of reading [color] - which differs for exactly
  /// one status: an unmerged file says `Tone.gitConflicted` while its
  /// [color] borrows the deletion colour (see `FileStatusType.toneOf`). The
  /// wash behind the label still reads [color], because no contract member
  /// can tint a surface from a `Tone` until the pill is `surfaces.badge`.
  final Tone? tone;

  /// Whether the parent item is selected (affects background opacity)
  final bool isSelected;

  const FileStatusBadge({
    super.key,
    required this.code,
    required this.color,
    this.tone,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // The vertical rung is `Inset.hairline`, but the horizontal one has no
      // word: this badge is a single letter and sits narrower across than
      // "barely set in" would make it. Saying only half of an inset is not
      // something the façade can do, so both halves stay measurements until
      // the badge becomes `surfaces.badge`. See the P3d report.
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.paddingXS,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? color.withValues(alpha: 0.3)
            : color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
      ),
      // The badge states its own foreground and the code reads it, rather than
      // the two of them naming the same `Color` twice. [color] itself stays a
      // `Color` for now on purpose: it paints the wash behind the code as well
      // as the code, and until the badge is `surfaces.badge` at P3d there is no
      // contract member that can tint a surface from a `Tone` — a half-migrated
      // badge whose text is a meaning and whose fill is still a value would be
      // two names for one thing. [tone] is the half-step out of that: where a
      // site already knows the MEANING, the label says it and only the wash
      // still reads the value.
      child: tone != null
          ? BaseLabel(code, role: TextRole.micro, tone: tone!)
          : DefaultTextStyle.merge(
              style: TextStyle(color: color),
              child: BaseLabel(code, role: TextRole.micro),
            ),
    );
  }
}
