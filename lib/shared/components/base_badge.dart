import 'dart:math' as math;

import 'package:flutter/material.dart';
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
/// Provides unified badge behavior with variants and sizes.
///
/// Example usage:
/// ```dart
/// BaseBadge(
///   label: 'New',
///   variant: BadgeVariant.success,
///   size: BadgeSize.medium,
///   icon: PhosphorIconsRegular.check,
///   onDeleted: () => print('Badge deleted'),
/// )
/// ```
class BaseBadge extends StatelessWidget {
  const BaseBadge({
    super.key,
    required this.label,
    this.variant = BadgeVariant.neutral,
    this.size = BadgeSize.medium,
    this.icon,
    this.isPill = true,
    this.onDeleted,
  });

  /// Badge text label
  final String label;

  /// Visual variant (neutral, primary, success, warning, danger, info)
  final BadgeVariant variant;

  /// Size variant (small, medium, large)
  final BadgeSize size;

  /// Leading icon (optional)
  final IconData? icon;

  /// Whether to use pill shape (true) or rounded corners (false)
  final bool isPill;

  /// Optional callback for making the badge deletable (shows close icon).
  ///
  /// A deletable badge is taller and wider than the same badge without a
  /// delete callback, because the delete glyph is a real button with the full
  /// 48 dp interactive minimum around it (see [_BadgeDeleteButton]): its
  /// *layout* box is [kMinInteractiveDimension] tall with the pill centred in
  /// it, and the pill itself sets the glyph off from the label by enough that
  /// the 48 dp box lands on the badge's trailing space instead of on the
  /// label. Nothing else about the pill changes.
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Get size-specific values
    final double horizontalPadding;
    final double verticalPadding;
    final double fontSize;
    final double iconSize;
    final double borderRadius;

    switch (size) {
      case BadgeSize.small:
        horizontalPadding = AppTheme.paddingS;
        verticalPadding = 2;
        fontSize = 10;
        iconSize = 10;
        borderRadius = isPill ? 12 : AppTheme.radiusS;
        break;
      case BadgeSize.medium:
        horizontalPadding = AppTheme.paddingM;
        verticalPadding = 4;
        fontSize = 12;
        iconSize = 12;
        borderRadius = isPill ? 16 : AppTheme.radiusS;
        break;
      case BadgeSize.large:
        horizontalPadding = AppTheme.paddingL;
        verticalPadding = AppTheme.paddingS;
        fontSize = 14;
        iconSize = 14;
        borderRadius = isPill ? 20 : AppTheme.radiusM;
        break;
    }

    // Get variant-specific colors
    Color backgroundColor;
    Color foregroundColor;

    switch (variant) {
      case BadgeVariant.neutral:
        backgroundColor = colorScheme.surfaceContainerHighest;
        foregroundColor = colorScheme.onSurface;
        break;
      case BadgeVariant.primary:
        backgroundColor = colorScheme.primary.withValues(alpha: 0.15);
        foregroundColor = colorScheme.primary;
        break;
      case BadgeVariant.success:
        backgroundColor = context.gitColors.added.withValues(alpha: 0.15);
        foregroundColor = context.gitColors.added;
        break;
      case BadgeVariant.warning:
        backgroundColor = context.gitColors.modified.withValues(alpha: 0.15);
        foregroundColor = context.gitColors.modified;
        break;
      case BadgeVariant.danger:
        backgroundColor = colorScheme.error.withValues(alpha: 0.15);
        foregroundColor = colorScheme.error;
        break;
      case BadgeVariant.info:
        backgroundColor = colorScheme.primary.withValues(alpha: 0.15);
        foregroundColor = colorScheme.primary;
        break;
    }

    // The delete glyph is two steps up from the badge's own icon size, the
    // size it has always painted at; only its interactive box grows below.
    final double deleteGlyphSize = iconSize + 2;

    // The gap between the label and the delete glyph. It is not a spacing
    // choice: it is what keeps the glyph's 48 dp interactive box off the
    // label. The box is centred on the glyph, so it reaches
    // kMinInteractiveDimension / 2 back towards the label, and anything the
    // label occupies inside that reach is a place where clicking the badge's
    // own text deletes the badge. Material draws the same line for its chip -
    // the delete affordance's hit region is capped at the label padding plus
    // the icon so that it claims the gap and never the label (Flutter 3.44.4
    // packages/flutter/lib/src/material/chip.dart:2425-2431,
    // `accessibleDeleteButtonWidth`) - and this is that rule with the app's
    // larger target: the gap grows to whatever the 48 dp box needs, and the
    // badge grows with it, rather than the box being allowed to overlap the
    // text. A non-deletable badge keeps the ordinary half-step.
    final double deleteGap = math.max(
      AppTheme.paddingS / 2,
      kMinInteractiveDimension / 2 - deleteGlyphSize / 2,
    );

    final Widget pill = Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: foregroundColor),
            SizedBox(width: AppTheme.paddingS / 2),
          ],
          // ignore: avoid_text_with_style
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: fontSize,
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onDeleted != null) ...[
            SizedBox(width: deleteGap),
            // The slot the delete glyph occupies inside the pill. The glyph
            // itself is painted by the control stacked over this slot, which
            // is the whole point: the pill reserves the glyph's space without
            // having to contain the glyph's 48 dp interactive box.
            SizedBox.square(dimension: deleteGlyphSize),
          ],
        ],
      ),
    );

    if (onDeleted == null) {
      return pill;
    }

    // A deletable badge lays out inside a 48 dp interactive row while the pill
    // keeps painting at its own height - the move BaseIconButton already makes,
    // where only the painted container shrinks and the hit area stays at
    // kMinInteractiveDimension. Growing the pill instead would turn a 25 dp
    // status pill into a 56 dp one wherever it happens to be deletable.
    //
    // The two children are aligned on their trailing edge, so the arithmetic
    // is one number: how far the centre of the reserved glyph slot sits from
    // the pill's trailing edge. Whichever of the two boxes reaches less far
    // takes the difference as padding, which puts the 48 dp box exactly over
    // the slot and makes the badge as wide as it needs to be for the target to
    // be hit-testable in full. It reaches beyond the pill by at most 10 dp
    // (the small size); at the large size it fits inside it.
    //
    // Everything the box covers is the badge's own trailing space, because
    // [deleteGap] has already pushed the label out of its reach: the target
    // spans the glyph, the gap before it, the pill's trailing padding and the
    // strip of the badge's box beyond the pill, plus the band above and below
    // the pill - and nothing else. The label is never inside it, so a click on
    // the badge's text cannot delete the badge.
    final double slotCentre = horizontalPadding + deleteGlyphSize / 2;
    final double targetRadius = kMinInteractiveDimension / 2;
    final double pillOverhang = math.max(0, targetRadius - slotCentre);
    final double targetInset = math.max(0, slotCentre - targetRadius);

    return Stack(
      alignment: AlignmentDirectional.centerEnd,
      children: <Widget>[
        Padding(
          padding: EdgeInsetsDirectional.only(end: pillOverhang),
          child: pill,
        ),
        Padding(
          padding: EdgeInsetsDirectional.only(end: targetInset),
          child: _BadgeDeleteButton(
            glyphSize: deleteGlyphSize,
            color: foregroundColor,
            onDeleted: onDeleted!,
          ),
        ),
      ],
    );
  }
}

/// The delete affordance of a deletable [BaseBadge]: a 48 dp interactive box
/// around a glyph that keeps the size the badge draws it at.
///
/// It exists because the glyph used to be a bare `GestureDetector` - a 14 dp
/// tap target with no state layer, no focus and no keyboard activation. This
/// is the same shape Material gives its own chip's delete affordance
/// (Flutter 3.44.4 packages/flutter/lib/src/material/chip.dart:1305-1321): a
/// circular [InkResponse] whose highlight is sized to the glyph rather than to
/// the box, so the state layer stays inside the pill while the target does not
/// have to.
class _BadgeDeleteButton extends StatelessWidget {
  const _BadgeDeleteButton({
    required this.glyphSize,
    required this.color,
    required this.onDeleted,
  });

  /// The painted glyph's size; the interactive box is always
  /// [kMinInteractiveDimension].
  final double glyphSize;

  /// The badge variant's foreground, so the glyph keeps carrying the variant's
  /// accent the way the label does.
  final Color color;

  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    // The glyph is the whole control, so without a tooltip it reaches
    // assistive technology as a tappable node with no name at all - which is
    // what the a11y matrix sweep measures. The message is Material's own, the
    // one `Chip` gives its delete affordance (chip.dart:1307-1308), so it is
    // already translated into every locale the app ships and reads the same
    // here as it does on a chip.
    return Tooltip(
      message: MaterialLocalizations.of(context).deleteButtonTooltip,
      // An InkResponse paints its state layers into the nearest Material, and
      // a badge is placed in toolbars and rows that may not offer one. A
      // transparent Material guarantees the ink surface without painting
      // anything itself - the same guarantee BaseCard makes for its content.
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox.square(
          dimension: kMinInteractiveDimension,
          child: InkResponse(
            onTap: onDeleted,
            customBorder: const CircleBorder(),
            // The hover, focus and pressed circle is sized to the glyph plus
            // one spacing step, not to the 48 dp box, so it stays within the
            // pill it is drawn on.
            radius: glyphSize / 2 + AppTheme.paddingXS,
            child: Icon(Icons.close, size: glyphSize, color: color),
          ),
        ),
      ),
    );
  }
}

/// Numeric badge variant for displaying counts
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
