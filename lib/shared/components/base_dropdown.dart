import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        ControlScale,
        Fields,
        IconRole,
        Proximity,
        SuggestFieldSpec,
        SuggestItem,
        TextRole;

import '../../generated/app_localizations.dart';
import 'base_badge.dart';
import 'base_icon.dart';
import 'base_label.dart';
import 'base_layout.dart';

/// Base dropdown component for consistent dropdown styling across the app.
///
/// Geometry, outline colors per state and typography are asserted against a
/// real SDK `DropdownButtonFormField` by
/// packages/gitui_skin_material/test/conformance/components/base_dropdown_conformance_test.dart;
/// the single deliberate divergence is registered as DROP-001 in
/// packages/gitui_skin_material/docs/deviation_register.yaml.
class BaseDropdown<T> extends StatelessWidget {
  final T? initialValue;
  final String? labelText;
  final String? hintText;

  /// The meaning of an optional leading mark; the skin chooses the glyph.
  final IconRole? prefixIcon;
  final List<BaseDropdownItem<T>> items;
  final void Function(T?)? onChanged;
  final String? Function(T?)? validator;
  final bool isExpanded;

  /// Focus this dropdown when the dialog opens, so the keyboard lands on the
  /// dialog's first field (Space/Enter opens the menu, arrows pick a value).
  final bool autofocus;
  final FocusNode? focusNode;

  const BaseDropdown({
    super.key,
    this.initialValue,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    required this.items,
    this.onChanged,
    this.validator,
    this.isExpanded = true,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      isExpanded: isExpanded,
      autofocus: autofocus,
      focusNode: focusNode,
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        // Shape only: the content padding and the minimum height are the
        // Material 3 defaults for an outlined field
        // (EdgeInsetsDirectional.fromSTEB(12, 20, 12, 12) plus the border's
        // 4 dp gap padding, Flutter 3.44.4
        // packages/flutter/lib/src/material/input_decorator.dart:2629-2635,
        // floored at kMinInteractiveDimension by :1331). The dropdown used to
        // set `isDense` and its own padding, which shrank it to 40 dp — below
        // the minimum interactive dimension, and 15 dp shorter than a
        // BaseTextField standing next to it in the same dialog.
        border: const OutlineInputBorder(),
        prefixIcon: prefixIcon == null
            ? null
            : BaseIcon(prefixIcon!, scale: ControlScale.normal),
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item.value,
          child: item.builder(context),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
}

/// Dropdown item with custom builder for content
class BaseDropdownItem<T> {
  final T value;
  final Widget Function(BuildContext) builder;

  const BaseDropdownItem({required this.value, required this.builder});

  /// Create a simple dropdown item with icon and label
  factory BaseDropdownItem.simple({
    required T value,
    required String label,
    IconData? icon,
    Widget? trailing,
  }) {
    return BaseDropdownItem(
      value: value,
      builder: (context) => Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14),
            const BaseGap(Proximity.related),
          ],
          // One line, because a menu entry is a row: the line cap is the fact
          // the application states, and how the skin truncates the last line
          // is the skin's idiom.
          Expanded(
            child: BaseLabel(label, role: TextRole.control, maxLines: 1),
          ),
          if (trailing != null) ...[const BaseGap(Proximity.related), trailing],
        ],
      ),
    );
  }

  /// Create a dropdown item with icon, label, and optional badge
  ///
  /// The `badgeColor` / `badgeTextColor` pair this used to accept is gone. It
  /// let a caller hand in a fill and a foreground as two independent `Color`s,
  /// which is two design decisions crossing an application API and, worse, two
  /// that can contradict each other — a caller could set the fill and leave the
  /// text pairing behind. No call site ever passed either, so nothing is lost
  /// today; when the badge becomes `surfaces.badge` at P3d it will carry a
  /// single [Tone] and the skin will pair the foreground with the fill itself,
  /// which is the one arrangement that cannot be got wrong.
  factory BaseDropdownItem.withBadge({
    required T value,
    required String label,
    IconData? icon,
    String? badgeText,
  }) {
    return BaseDropdownItem(
      value: value,
      builder: (context) => Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14),
            const BaseGap(Proximity.related),
          ],
          Expanded(
            child: BaseLabel(label, role: TextRole.control, maxLines: 1),
          ),
          if (badgeText != null) ...[
            const BaseGap(Proximity.related),
            // The badge this factory is named after, now asked for as one.
            // The paragraph above predicted exactly this: it carries a single
            // meaning and the skin pairs the foreground with the fill, which
            // is the one arrangement that cannot be got wrong. The 4/1 inset
            // and the 4 dp corner left with the hand-painted box - a badge's
            // measure is the member's, and its corner is derived from its own
            // height rather than named as a rung here.
            BaseBadge(
              label: badgeText,
              variant: BadgeVariant.primary,
              size: BadgeSize.small,
            ),
          ],
        ],
      ),
    );
  }
}

/// The application's way of asking the user to narrow a closed list down to
/// one of its items.
///
/// **This is a façade** (#249, §2.11): the body is one delegation to
/// `controls.suggestField`, through the package's own field seam. Everything
/// this class used to draw itself moved into the skin verbatim — the
/// `LayerLink`, the `OverlayEntry` and the `CompositedTransformFollower` that
/// anchored the list, the search box above it, the filtering beneath it, the
/// `TapRegion` that dismissed it and the caret that turned over — and the
/// Material skin's `_MaterialSuggestField` carries the same lengths it did
/// (`elevationRaised` == `elevationLevel2`, `radiusM`, `spaceS + 4` inside the
/// closed box, a 300 px list, the 4 px drop below the anchor).
///
/// What stays here is the two things that are the application's and not a
/// design language's: WHAT is being narrowed ([label], [items], [value]) and
/// WHAT the field says while the list has nothing to show — this
/// application's own translated sentence, so it crosses the contract as a
/// string instead of being invented by the skin.
class SearchableBaseDropdown<T> extends StatelessWidget {
  const SearchableBaseDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onSelected,
    this.prefixIcon,
    this.placeholder,
    this.searchHint,
    this.minSearchLength = 3,
  });

  /// What kind of thing is being named.
  final String label;

  /// The meaning of an optional leading mark; the skin chooses the glyph.
  final IconRole? prefixIcon;

  /// Which one is named so far, or null.
  final T? value;

  /// Everything it could settle on, as data.
  final List<SuggestItem<T>> items;

  /// How to tell the application the user settled on one.
  final ValueChanged<T> onSelected;

  /// What the closed control says while nothing is chosen. A different
  /// sentence from [searchHint], and the spec carries both so the number of
  /// surfaces they land on stays the skin's decision.
  final String? placeholder;

  /// What the search box says while nothing is typed.
  final String? searchHint;

  /// How much the user must type before narrowing is useful.
  final int minSearchLength;

  @override
  Widget build(BuildContext context) => Fields.suggest<T>(
    context,
    SuggestFieldSpec<T>(
      label: label,
      value: value,
      items: items,
      onSelected: onSelected,
      hint: searchHint,
      placeholder: placeholder,
      leading: prefixIcon,
      minQueryLength: minSearchLength,
      // The hand-built overlay hard-coded an English "No items found"; the
      // member takes the words from the application instead, so the empty
      // answer is translated like every other sentence on screen.
      emptyLabel: AppLocalizations.of(context)!.emptyStateNoResultsFound,
    ),
  );
}
