import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../../shared/theme/app_theme.dart';

/// Badge visual variants
enum BadgeVariant {
  /// Gray/default - for neutral information
  neutral,

  /// Primary color - for primary status
  primary,

  /// Green - for success, ahead commits, etc.
  success,

  /// Yellow/orange - for warnings, uncommitted changes
  warning,

  /// Red - for errors, conflicts
  danger,

  /// Blue - for information, tips
  info,
}

/// Badge size variants
enum BadgeSize {
  /// Compact size
  small,

  /// Default size
  medium,

  /// Prominent size
  large,
}

/// Base badge component for all badge patterns in the app.
///
/// **This is a façade** (#249, §2.11), on the same terms as `BaseButton`: the
/// application keeps naming a badge in its own words - a [BadgeVariant] and a
/// [BadgeSize] - and this component translates those words into the contract's
/// ([Tone] and [ControlScale]) and hands them to `surfaces.badge`, or to
/// `surfaces.tag` when the badge can be removed. Nothing here decides a
/// padding, a corner or a colour any more; the pill's whole measure is the
/// skin's, which is what makes the same badge look like the host platform's
/// badge under a different skin instead of like Material's everywhere.
///
/// Example usage:
/// ```dart
/// BaseBadge(
///   label: 'New',
///   variant: BadgeVariant.success,
///   size: BadgeSize.medium,
///   icon: IconRole.check,
///   onDeleted: () => print('Badge deleted'),
///   deleteTooltip: 'Remove the filter',
/// )
/// ```
class BaseBadge extends StatelessWidget {
  const BaseBadge({
    super.key,
    required this.label,
    this.variant = BadgeVariant.neutral,
    this.size = BadgeSize.medium,
    this.icon,
    this.onDeleted,
    this.deleteTooltip,
  }) : assert(
         onDeleted == null || deleteTooltip != null,
         'A removable badge must name its removal - the removal is a '
         'mark-only control, and every mark-only control says what it does. '
         'TagSpec enforces the same pair one seam down.',
       );

  /// Badge text label
  final String label;

  /// Visual variant (neutral, primary, success, warning, danger, info)
  final BadgeVariant variant;

  /// Size variant (small, medium, large)
  final BadgeSize size;

  /// The meaning of the mark before the words, or null for none.
  ///
  /// An `IconRole` and no longer an `IconData`, because the mark now crosses
  /// the seam with the rest of the badge: `IconData` is type-neutral but not
  /// identity-neutral, so accepting it here would hand every skin Phosphor's
  /// glyphs forever (#249 conflict C3).
  final IconRole? icon;

  /// Optional callback for making the badge removable (shows close icon).
  ///
  /// A removable badge is drawn by `surfaces.tag` rather than by
  /// `surfaces.badge`: the two do not overlap even inside Material, because a
  /// removal is a second, separately named control inside the pill and a badge
  /// has no slot for its tooltip. It is taller and wider than the same badge
  /// without a removal, and that is the member's own deliberate arithmetic -
  /// the removal carries the full 48 dp interactive minimum, laid out over the
  /// pill so that only the target grows.
  ///
  /// Because the tag is the removable form, it draws at the tag's own measure
  /// rather than at [size]; every site that removes uses [BadgeSize.medium],
  /// which is the measure the tag draws at.
  final VoidCallback? onDeleted;

  /// What removing the badge does, for the pointer and for a screen reader.
  /// Required whenever [onDeleted] is set, because the removal is a mark-only
  /// control and its name is the application's copy decision - a skin that
  /// invented a generic one would be naming an action it does not know.
  final String? deleteTooltip;

  /// What the variant MEANS, in the contract's word for it.
  ///
  /// Each pairing is the one the Material skin already resolves to the colour
  /// this component used to name directly: `success` and `warning` are the git
  /// palette's added and modified (`material_ink.dart:171-172`), `info` and
  /// `primary` land on the same `colorScheme.primary` this component gave both
  /// (`material_ink.dart:177`), and `neutral` keeps its own
  /// `surfaceContainerHighest` chip rather than a wash.
  static Tone _toneOf(BadgeVariant variant) => switch (variant) {
    BadgeVariant.neutral => Tone.neutral,
    BadgeVariant.primary => Tone.accent,
    BadgeVariant.success => Tone.success,
    BadgeVariant.warning => Tone.warning,
    BadgeVariant.danger => Tone.danger,
    BadgeVariant.info => Tone.info,
  };

  /// How much room the size asks for.
  static ControlScale _scaleOf(BadgeSize size) => switch (size) {
    BadgeSize.small => ControlScale.compact,
    BadgeSize.medium => ControlScale.normal,
    BadgeSize.large => ControlScale.prominent,
  };

  @override
  Widget build(BuildContext context) => SkinScope.render(context, (
    Skin skin,
    BuildContext inner,
  ) {
    final Tone tone = _toneOf(variant);
    if (onDeleted != null) {
      return skin.surfaces.tag(
        inner,
        TagSpec(
          label: label,
          icon: icon,
          tone: tone,
          onRemoved: onDeleted,
          removeTooltip: deleteTooltip,
        ),
      );
    }
    return skin.surfaces.badge(
      inner,
      BadgeSpec(label: label, icon: icon, tone: tone, scale: _scaleOf(size)),
    );
  });
}

/// Numeric badge variant for displaying counts
///
/// **Decided (#438): this construction asked the wrong member.** A count
/// riding on a host is already the contract's word - the `badgeCount` slot on
/// `ListRowSpec`, `TreeNodeSpec`, `TabEntry` and `ShellDestination`, where the
/// SKIN draws the count in its own idiom (the Material skin's `_CountBadge` is
/// this widget's design, moved there). No application code calls this widget
/// any more; it survives only as the specimen the Material conformance suite
/// measures M3's `Badge` against, and it must not gain new callers - a count
/// belongs in its host's `badgeCount` slot, not beside it.
///
/// Example usage:
/// ```dart
/// BaseNumericBadge(
///   count: 42,
///   variant: BadgeVariant.primary,
/// )
/// ```
class BaseNumericBadge extends StatelessWidget {
  const BaseNumericBadge({
    super.key,
    required this.count,
    this.variant = BadgeVariant.primary,
    this.maxCount = 99,
  });

  /// Count to display
  final int count;

  /// Visual variant
  final BadgeVariant variant;

  /// Maximum count to show (displays "{maxCount}+" for larger numbers)
  final int maxCount;

  /// The badge is a pill: the corner radius is half the minimum size, so
  /// the shape stays fully rounded however wide the count grows. This is
  /// geometry derived from the badge size, not a design-token radius.
  static const double _minSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Get variant-specific colors
    Color backgroundColor;
    Color foregroundColor;

    switch (variant) {
      case BadgeVariant.neutral:
        backgroundColor = colorScheme.surfaceContainerHighest;
        foregroundColor = colorScheme.onSurface;
        break;
      case BadgeVariant.primary:
        backgroundColor = colorScheme.primary;
        foregroundColor = colorScheme.onPrimary;
        break;
      case BadgeVariant.success:
        backgroundColor = context.gitColors.added;
        foregroundColor = GitSemanticColors.foregroundOn(
          context.gitColors.added,
        );
        break;
      case BadgeVariant.warning:
        backgroundColor = context.gitColors.modified;
        foregroundColor = GitSemanticColors.foregroundOn(
          context.gitColors.modified,
        );
        break;
      case BadgeVariant.danger:
        backgroundColor = colorScheme.error;
        foregroundColor = colorScheme.onError;
        break;
      case BadgeVariant.info:
        backgroundColor = colorScheme.primary;
        foregroundColor = colorScheme.onPrimary;
        break;
    }

    final displayText = count > maxCount ? '$maxCount+' : count.toString();

    return Container(
      constraints: const BoxConstraints(
        minWidth: _minSize,
        minHeight: _minSize,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(_minSize / 2),
      ),
      // A shrink-wrapping centre, not a plain one. `Center` with no factors
      // expands to whatever maximum it is offered, so the badge filled its
      // parent whenever that parent handed down a bounded width - inside a
      // Row or a Wrap the main axis is unbounded and it happened to hug its
      // label, but in any bounded box (a SizedBox, a Center, a table cell) a
      // 20 dp count badge became as large as the box. The factors make the
      // centre size to the label, and the container's min constraints still
      // hold it at 20 dp.
      child: Center(
        widthFactor: 1.0,
        heightFactor: 1.0,
        // ignore: avoid_text_with_style
        child: Text(
          displayText,
          style: theme.textTheme.labelMedium?.copyWith(
            color: foregroundColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Icon badge variant for displaying a badge overlay on an icon or widget
///
/// **Decided (#438): this construction asked the wrong member.** Its one
/// application call site is the navigation rail's destination icon
/// (`app_shell.dart`, `_buildIconWithBadge`), and the contract already carries
/// that fact as `ShellDestination.badgeCount`: a count on a navigation
/// destination is the SHELL's to draw - M3 rides a `Badge` on the rail
/// destination, Fluent puts an `InfoBadge` beside the pane item, each in its
/// own place - so the site converts when `chrome.shell` is wired, and this
/// widget goes with the hand-built rail. `BadgeSpec` deliberately does not
/// grow a slot for the thing the badge rides on: every host that can carry a
/// count already names it as data, and a host-shaped hole on the badge would
/// be a second way to say each of them.
///
/// Example usage:
/// ```dart
/// BaseIconBadge(
///   count: 5,
///   variant: BadgeVariant.danger,
///   child: Icon(Icons.notifications),
/// )
/// ```
class BaseIconBadge extends StatelessWidget {
  const BaseIconBadge({
    super.key,
    required this.count,
    required this.child,
    this.variant = BadgeVariant.danger,
    this.maxCount = 99,
  });

  /// Count to display in the badge
  final int count;

  /// Widget to display the badge on (typically an icon)
  final Widget child;

  /// Visual variant
  final BadgeVariant variant;

  /// Maximum count to show (displays "{maxCount}+" for larger numbers)
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Get variant-specific colors
    Color backgroundColor;
    Color foregroundColor;

    switch (variant) {
      case BadgeVariant.neutral:
        backgroundColor = colorScheme.surfaceContainerHighest;
        foregroundColor = colorScheme.onSurface;
        break;
      case BadgeVariant.primary:
        backgroundColor = colorScheme.primary;
        foregroundColor = colorScheme.onPrimary;
        break;
      case BadgeVariant.success:
        backgroundColor = context.gitColors.added;
        foregroundColor = GitSemanticColors.foregroundOn(
          context.gitColors.added,
        );
        break;
      case BadgeVariant.warning:
        backgroundColor = context.gitColors.modified;
        foregroundColor = GitSemanticColors.foregroundOn(
          context.gitColors.modified,
        );
        break;
      case BadgeVariant.danger:
        backgroundColor = colorScheme.error;
        foregroundColor = colorScheme.onError;
        break;
      case BadgeVariant.info:
        backgroundColor = colorScheme.primary;
        foregroundColor = colorScheme.onPrimary;
        break;
    }

    final displayText = count > maxCount ? '$maxCount+' : count.toString();

    // ignore: avoid_badge
    return Badge(
      // ignore: avoid_text_with_style
      label: Text(
        displayText,
        style: theme.textTheme.labelSmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: backgroundColor,
      child: child,
    );
  }
}

/// Dot badge variant for small status indicators
///
/// **Decided (#438): not grown into the contract.** "Presence without a
/// count" is a real meaning - every language has a dot form - but no
/// application screen states it: this widget has zero call sites in `lib/`
/// and survives only as the specimen the Material conformance suite measures
/// M3's small `Badge` against. Members and fields are derived from need in at
/// least one source, so `BadgeSpec.label` stays required until a screen
/// actually needs a label-less badge; growing the word for a specimen would
/// be speculation.
///
/// Example usage:
/// ```dart
/// BaseDotBadge(
///   variant: BadgeVariant.success,
///   size: 10,
/// )
/// ```
class BaseDotBadge extends StatelessWidget {
  const BaseDotBadge({
    super.key,
    this.variant = BadgeVariant.success,
    this.size = 8.0,
  });

  /// Visual variant (determines color)
  final BadgeVariant variant;

  /// Dot size in pixels
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Get variant-specific color
    Color color;

    switch (variant) {
      case BadgeVariant.neutral:
        color = colorScheme.onSurfaceVariant;
        break;
      case BadgeVariant.primary:
        color = colorScheme.primary;
        break;
      case BadgeVariant.success:
        color = context.gitColors.added;
        break;
      case BadgeVariant.warning:
        color = context.gitColors.modified;
        break;
      case BadgeVariant.danger:
        color = colorScheme.error;
        break;
      case BadgeVariant.info:
        color = colorScheme.primary;
        break;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
