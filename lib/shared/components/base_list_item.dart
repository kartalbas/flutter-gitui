import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' as contract;
import 'package:gitui_skin_api/gitui_skin_api.dart' show Proximity;

import 'base_layout.dart';
import 'base_menu_item.dart';

/// Base component for all list item patterns in the app.
///
/// **This is a façade** (#249, P5): the body is one delegation to
/// `surfaces.listRow`, and every pixel this component used to paint by hand now
/// lives in the skin. The Material renderer draws the same Material 3
/// list-item geometry this file spelled out — the 56 dp minimum tile height,
/// the 16 dp leading edge, the 24 dp trailing edge, the 16 dp gap after the
/// leading slot, the `bodyLarge` title, the `onSurfaceVariant` icon theme and
/// the hover/press state layers painted by an [InkWell] over an [Ink] tile —
/// together with the three-state selection layer (transparent,
/// `secondaryContainer`, `tertiaryContainer`), the contrast-corrected
/// foreground for every slot and the inset rule between two rows.
///
/// What moved rather than merely relocating:
/// - the row's own overflow anchor. [contextMenuItems] used to grow a
///   Material `PopupMenuButton` here; the entries now travel as
///   [contract.MenuEntry] data and the SKIN builds the anchor and presents the
///   menu, which is the whole reason the type is data and not a widget.
/// - the badge slot. `ListRowSpec` states a COUNT (`badgeCount`) and this
///   component's [badge] is a widget — a status LETTER in the only scenes that
///   pass one — so there is no slot on the member to hand it to. It travels
///   inside the trailing port instead, and that is the DECIDED answer to the
///   finding #438 recorded here, not a workaround: a count is the member's to
///   render in its own badge idiom, while a status mark is row CONTENT at the
///   tail, and the tail's member is the trailing port. No design language's
///   canonical row distinguishes a second status region from its one trailing
///   slot — Material's `ListTile`, Fluent's `ListItem` and macOS's row all
///   carry exactly one — so a second spec slot would be fed only by
///   conformance scenes, which is not a need.
///
/// Example usage:
/// ```dart
/// BaseListItem(
///   leading: BaseIcon(IconRole.folder),
///   content: Column(
///     crossAxisAlignment: CrossAxisAlignment.start,
///     children: [
///       BaseLabel('Title', role: TextRole.itemTitle),
///       BaseLabel('Subtitle', role: TextRole.detail),
///     ],
///   ),
///   contextMenuItems: [
///     MenuAction(
///       label: 'Edit',
///       icon: IconRole.pencil,
///       onPressed: () => _edit(),
///     ),
///     MenuAction(
///       label: 'Delete',
///       icon: IconRole.trash,
///       role: MenuActionRole.destructive,
///       onPressed: () => _delete(),
///     ),
///   ],
///   isSelected: true,
///   onTap: () => print('Tapped'),
/// )
/// ```
class BaseListItem extends StatelessWidget {
  const BaseListItem({
    super.key,
    required this.content,
    this.leading,
    this.trailing,
    this.badge,
    this.contextMenuItems,
    this.isSelected = false,
    this.isMultiSelected = false,
    this.isSelectable = true,
    this.containerHasFocus = true,
    this.onTap,
    this.onDoubleTap,
    this.onSecondaryTap,
  });

  /// Main content area (required)
  final Widget content;

  /// Leading widget (optional) - typically an icon
  final Widget? leading;

  /// Trailing widget (optional) - typically action buttons
  final Widget? trailing;

  /// Badge/status indicator (optional).
  ///
  /// It rides in the trailing port beside [trailing] rather than in the
  /// member's own badge slot, because that slot takes a `badgeCount` — an
  /// integer answering "how many things does this row stand for" — and every
  /// badge handed to this component is a status MARK instead.
  final Widget? badge;

  /// The entries of the row's three-dot menu, as data (optional).
  ///
  /// When this is non-empty the row grows its own overflow anchor, combined
  /// with [trailing] if that is present too — and the anchor is the SKIN's,
  /// built from these entries. That is the whole point of the type: the widget
  /// form welded Material's menu *classes* into this component's public
  /// signature, where one design language rejects them at compile time and
  /// another accepts them and renders Material rows inside its own menu — see
  /// [MenuEntry] for the measurement.
  final List<MenuEntry>? contextMenuItems;

  /// Whether this item is currently selected (primary selection)
  final bool isSelected;

  /// Whether this item is part of a multi-selection (secondary selection)
  final bool isMultiSelected;

  /// Whether this item can be selected/tapped
  final bool isSelectable;

  /// Whether the collection rendering this item holds keyboard focus.
  ///
  /// A collection is a single Tab stop with a roving highlight, so the
  /// highlight has two strengths: while the collection is focused the selected
  /// item wears its focus ring (tinted background plus border), and while
  /// focus lives elsewhere it keeps only the muted tinted background — still
  /// clearly the selection, no longer claiming the keyboard. Defaults to true
  /// so an item outside a focus-aware collection keeps the full treatment.
  final bool containerHasFocus;

  /// Callback when item is tapped
  final VoidCallback? onTap;

  /// Callback when item is double-tapped
  final VoidCallback? onDoubleTap;

  /// Callback when item is right-clicked (context menu)
  final Function(Offset)? onSecondaryTap;

  /// The row's tail: the badge and the trailing widget, in that order.
  ///
  /// One port, because the member has one trailing slot and its other slot
  /// counts things. The two keep the 16 dp that has always stood between
  /// them; what changes is that the badge is now separated from the content by
  /// the row's own trailing gap rather than by a narrower one of this
  /// component's choosing.
  contract.ContentPort? _trailing() {
    if (badge == null) {
      return trailing == null ? null : contract.ContentPort(trailing!);
    }
    if (trailing == null) return contract.ContentPort(badge!);
    return contract.ContentPort(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[badge!, const BaseGap(Proximity.grouped), trailing!],
      ),
    );
  }

  /// The row's selection state, as the contract names it.
  contract.RowSelection get _selection => isSelected
      ? contract.RowSelection.primary
      : isMultiSelected
      ? contract.RowSelection.multi
      : contract.RowSelection.none;

  @override
  Widget build(BuildContext context) => contract.SkinScope.render(context, (
    contract.Skin skin,
    BuildContext inner,
  ) {
    return skin.surfaces.listRow(
      inner,
      contract.ListRowSpec(
        // One port, not two: every call site in the application composes its
        // own title/subtitle column inside `content`, so splitting it here
        // would be this façade guessing which half of a caller's column is
        // the title. The port arrives already laid out and the member mounts
        // it whole, which is exactly what `subtitle: null` means.
        title: contract.ContentPort(content),
        leading: leading == null ? null : contract.ContentPort(leading!),
        trailing: _trailing(),
        // Handed through as-is: the application's menu vocabulary IS the
        // contract's now (base_menu_item.dart re-exports it), so the
        // restatement switch that used to stand here - two sealed sets with
        // the same names, translated kind by kind - is gone with the
        // duplicate hierarchy it translated from.
        menu: contextMenuItems ?? const <contract.MenuEntry>[],
        selection: _selection,
        containerFocused: containerHasFocus,
        // [isSelectable] is this façade's second way of saying "nothing
        // happens when you press me", so it is resolved into the callbacks
        // rather than carried into the spec: the member reads a row with
        // neither callback as non-interactive and paints no state layer,
        // which is what the unselectable row always looked like.
        onTap: isSelectable ? onTap : null,
        onActivate: isSelectable ? onDoubleTap : null,
        onContextMenu: onSecondaryTap,
      ),
    );
  });
}
