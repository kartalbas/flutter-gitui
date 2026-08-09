import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Tone;

import 'base_icon.dart';

/// One entry in a menu, expressed as data rather than as a widget.
///
/// A menu is one of the places where the three design languages disagree not
/// about styling but about *type*. Fluent 2's `MenuFlyout` takes
/// `List<MenuFlyoutItemBase>`, which is not even a `Widget`, so no cast or
/// adapter reaches it from a `List<PopupMenuEntry>` — handing it Material menu
/// entries fails to compile, which is the harmless failure. Cupertino's
/// `CupertinoContextMenu.actions` is typed `List<Widget>` and `PopupMenuEntry`
/// **is** a `Widget`, so the same list compiles cleanly there and then renders
/// Material rows, Material ink and Material typography inside an iOS menu,
/// without any of `CupertinoContextMenuAction`'s dividers, destructive
/// treatment or dismissal behaviour. That is the failure that ships.
///
/// The lesson is the one `DialogAction` was created for
/// (lib/shared/components/base_dialog.dart): a `Widget`-typed parameter is
/// exactly what lets the wrong design language through the type system
/// unnoticed. So a menu entry here carries only language-neutral data — a
/// string, a glyph, a callback, a role and a flag — and the mapping onto
/// Material's `PopupMenuEntry` happens in exactly one place,
/// [materialMenuEntries].
///
/// The type is sealed so that place can switch over it exhaustively: adding a
/// third kind of entry becomes a compile error there rather than an entry that
/// silently renders as nothing.
sealed class MenuEntry {
  const MenuEntry();
}

/// A rule drawn between two groups of actions, carrying no action of its own.
///
/// It is a separate kind of entry rather than a flag on [MenuAction] because
/// it is not one: a separator has no label, no glyph and nothing to invoke,
/// and every design language draws it with its own dedicated element
/// (`PopupMenuDivider`, `MenuFlyoutSeparator`, the divider Cupertino puts
/// between context-menu actions by construction).
final class MenuSeparator extends MenuEntry {
  const MenuSeparator();
}

/// What an action in a menu *means*, from which each design language derives
/// its own emphasis.
///
/// The role is what the call site declares, not a colour and not a variant,
/// for the same reason `DialogActionRole` exists: Material tints a destructive
/// entry with `error`, Fluent 2 gives it its own critical style, and Cupertino
/// expresses it on the action itself
/// (`CupertinoContextMenuAction.isDestructiveAction`). A call site that named
/// a colour would have made Material's choice on behalf of all three.
enum MenuActionRole {
  /// An ordinary entry: open, rename, copy, check out, push.
  normal,

  /// An entry that destroys something the user cannot get back by repeating
  /// the gesture: delete, drop, discard, force-delete.
  destructive,
}

/// One invokable entry in a menu.
///
/// Everything on it survives a change of design language: a `String`, an
/// [IconRole] (a MEANING rather than a glyph, so the mark and its weight stay
/// the skin's to choose), a callback, a role and a flag. Nothing here names a
/// Material class, a colour or a size.
final class MenuAction extends MenuEntry {
  const MenuAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.role = MenuActionRole.normal,
    this.enabled = true,
  });

  /// The entry's text, and its accessible name.
  final String label;

  /// The meaning of the entry's leading mark. Required rather than optional
  /// because every menu in this app is mark-led and a single markless row
  /// inside an otherwise aligned column reads as a rendering fault; which
  /// *glyph* stands for the meaning stays the skin's decision.
  final IconRole icon;

  /// What the entry does. Null disables it, exactly as on a button, so a call
  /// site that already computes `condition ? callback : null` needs no
  /// rewriting.
  final VoidCallback? onPressed;

  /// What the entry means. See [MenuActionRole].
  final MenuActionRole role;

  /// Whether the entry may be invoked right now. Distinct from a null
  /// [onPressed] only in how it reads at the call site: an entry that is
  /// present but temporarily unavailable says so, and stays in the menu with
  /// its reason visible rather than disappearing from it.
  final bool enabled;

  /// The resolved answer to "can the user invoke this now".
  bool get isEnabled => enabled && onPressed != null;
}

/// Renders [entries] the Material 3 way, as the `PopupMenuEntry` list a
/// [PopupMenuButton] wants.
///
/// This is the single place where the language-neutral data of [MenuEntry]
/// becomes Material widgets, which is what makes the rest of the app free of
/// them. Each [MenuAction] is given its own index as the menu's value, so the
/// button dispatches by position and no call site has to invent string keys
/// for its entries; [dispatchMenuEntry] is the matching half.
List<PopupMenuEntry<int>> materialMenuEntries(
  BuildContext context,
  List<MenuEntry> entries,
) {
  final List<PopupMenuEntry<int>> rendered = <PopupMenuEntry<int>>[];

  for (int index = 0; index < entries.length; index++) {
    final MenuEntry entry = entries[index];
    switch (entry) {
      case MenuSeparator():
        rendered.add(const PopupMenuDivider());
      case MenuAction():
        // The destructive tint is dropped while the entry is unavailable, so
        // the disabled treatment `PopupMenuItem` resolves for its label
        // (onSurface at 38%, popup_menu.dart:1847-1852) is the one that shows.
        // Naming the tint anyway would paint straight over it and a disabled
        // destructive entry would look exactly like an invokable one. The
        // second half of that sentence used to be a `labelColor:` spelling out
        // `colorScheme.error` under the same condition; it says nothing the
        // tone beside it did not already say, now that the tone reaches the
        // words too.
        final bool emphasiseAsDestructive =
            entry.role == MenuActionRole.destructive && entry.isEnabled;
        rendered.add(
          PopupMenuItem<int>(
            value: index,
            enabled: entry.isEnabled,
            child: MenuItemContent(
              icon: entry.icon,
              label: entry.label,
              tone: emphasiseAsDestructive ? Tone.danger : Tone.neutral,
            ),
          ),
        );
    }
  }

  return rendered;
}

/// Invokes the entry [materialMenuEntries] gave the index [index].
///
/// The index addresses the original [entries] list, separators included, so
/// the two functions stay in step without either of them holding state. A
/// separator carries no callback and can never be selected, so it is simply
/// ignored here rather than treated as an error.
void dispatchMenuEntry(List<MenuEntry> entries, int index) {
  final MenuEntry entry = entries[index];
  if (entry is MenuAction) {
    entry.onPressed?.call();
  }
}

/// The colour a menu item's own label should use when the caller names none.
///
/// It is the colour the enclosing menu item already published through its
/// [DefaultTextStyle], not `colorScheme.onSurface`. That distinction is the
/// whole point: `PopupMenuItem` resolves its label colour per widget state and
/// hands a **disabled** item `onSurface` at 38%
/// (flutter/lib/src/material/popup_menu.dart:1847-1852), and a content widget
/// that spells `onSurface` out again paints straight over it — which is why a
/// disabled entry in an overflow menu used to look exactly like an enabled one.
/// Reading the inherited colour keeps every state the item resolves, and still
/// lets a caller override it explicitly.
Color? _inheritedLabelColor(BuildContext context) =>
    DefaultTextStyle.of(context).style.color;

/// Base component for all clickable menu items in the application.
///
/// This ensures consistent font sizing across all menus (popup menus, dropdowns, etc.)
/// by automatically applying the user's selected font size preference.
///
/// All menu items should use this component to maintain visual consistency.
class BaseMenuItem<T> extends PopupMenuItem<T> {
  const BaseMenuItem({
    super.key,
    super.value,
    super.onTap,
    super.enabled,
    super.height,
    super.padding,
    super.mouseCursor,
    super.labelTextStyle,
    required Widget child,
  }) : super(child: child);
}

/// Base component for menu item content with icon and label
///
/// This is the recommended way to build menu item content as it ensures
/// consistent layout and spacing across all menus.
class MenuItemContent extends StatelessWidget {
  const MenuItemContent({
    super.key,
    required this.icon,
    required this.label,
    this.tone = Tone.neutral,
    this.labelColor,
    this.scale = ControlScale.compact,
    this.spacing = 8,
  });

  /// The meaning of the leading mark.
  final IconRole icon;
  final String label;

  /// What the entry means. [Tone.neutral] leaves the colour to whatever the
  /// enclosing menu item has already published, which is what a null
  /// `iconColor` did and what keeps a disabled entry looking disabled.
  ///
  /// It reaches the WORDS as well as the mark. It did not until now, and that
  /// gap is why four screens spelled out `colorScheme.error` beside a
  /// `Tone.danger` they had already stated: the tone said "destructive", the
  /// component reddened only the glyph, and the label had to be re-said as a
  /// `Color` to keep the two halves of one entry agreeing. Material's answer
  /// to `Tone.danger` is quoted once here instead — the same arrangement the
  /// empty-state hero uses, and for the same reason: a tone reaches text only
  /// through `BaseLabel`, and this label is a `TextStyle` on Material's own
  /// `bodyLarge` ramp that `PopupMenuItem` expects to inherit.
  final Tone tone;

  /// An explicit override for the label's colour.
  ///
  /// Deprecated by [tone] in everything but name: every remaining caller is
  /// restating what its tone already says, and each one deletes this argument
  /// as it converts. The parameter goes when the last of them has.
  final Color? labelColor;

  /// How much room the mark is entitled to. `compact` is the 16 dp rung this
  /// component has always drawn; the overflow bar and the repositories screen
  /// ask for `normal`, which is the 20 dp rung they spelled out as a number.
  final ControlScale scale;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // `identical` rather than `==` for the reason BaseLabel records: Tone
    // carries a custom `==` and every named tone is a const singleton, so
    // identity is exactly as strong as equality here.
    final effectiveLabelColor =
        labelColor ??
        (identical(tone, Tone.danger)
            ? theme.colorScheme.error
            : _inheritedLabelColor(context));

    return Row(
      children: [
        BaseIcon(icon, tone: tone, scale: scale),
        SizedBox(width: spacing),
        Expanded(
          // ignore: avoid_text_with_style
          child: Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: effectiveLabelColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// Base component for menu item content with a checkmark for selected items
///
/// Use this for menu items that show a selection state (like language selector,
/// theme selector, etc.)
class MenuItemContentWithCheck extends StatelessWidget {
  const MenuItemContentWithCheck({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    this.iconColor,
    this.labelColor,
    this.iconSize = 16,
    this.spacing = 8,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final Color? iconColor;
  final Color? labelColor;
  final double iconSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveLabelColor =
        labelColor ??
        (isSelected
            ? theme.colorScheme.primary
            : _inheritedLabelColor(context));
    final effectiveIconColor =
        iconColor ??
        (isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface);

    return Row(
      children: [
        Icon(icon, size: iconSize, color: effectiveIconColor),
        SizedBox(width: spacing),
        Expanded(
          // ignore: avoid_text_with_style
          child: Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: effectiveLabelColor,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        if (isSelected) ...[
          SizedBox(width: spacing),
          Icon(Icons.check, size: iconSize, color: theme.colorScheme.primary),
        ],
      ],
    );
  }
}

/// Base component for two-line menu item content (icon + primary + secondary text)
///
/// Use this for menu items that need to display additional information below the
/// main label (like switchers showing name + path, or name + commit message)
class MenuItemContentTwoLine extends StatelessWidget {
  const MenuItemContentTwoLine({
    super.key,
    required this.icon,
    required this.primaryLabel,
    this.secondaryLabel,
    this.iconColor,
    this.primaryLabelColor,
    this.secondaryLabelColor,
    this.isSelected = false,
    this.showCheck = false,
    this.iconSize = 16,
    this.spacing = 8,
  });

  final IconData icon;
  final String primaryLabel;
  final String? secondaryLabel;
  final Color? iconColor;
  final Color? primaryLabelColor;
  final Color? secondaryLabelColor;
  final bool isSelected;
  final bool showCheck;
  final double iconSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectivePrimaryColor =
        primaryLabelColor ??
        (isSelected
            ? theme.colorScheme.primary
            : _inheritedLabelColor(context));
    final effectiveIconColor = iconColor;
    final effectiveSecondaryColor =
        secondaryLabelColor ?? theme.colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Icon(icon, size: iconSize, color: effectiveIconColor),
        SizedBox(width: spacing),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ignore: avoid_text_with_style
              Text(
                primaryLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: effectivePrimaryColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (secondaryLabel != null && secondaryLabel!.isNotEmpty)
                // ignore: avoid_text_with_style
                Text(
                  secondaryLabel!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: effectiveSecondaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        if (showCheck && isSelected) ...[
          SizedBox(width: spacing),
          Icon(Icons.check, size: iconSize, color: theme.colorScheme.primary),
        ],
      ],
    );
  }
}

/// A menu entry's words, at Material's `bodyLarge`.
///
/// **Part of the migration bridge, and it leaves with it.** Its replacement is
/// `BaseLabel(text, role: TextRole.control)`: a menu entry, a button label and
/// a field label are all "text the user operates", which is one job and
/// therefore one role. This class is why they disagreed — it drew menu entries
/// at `bodyLarge` while every button label was `labelLarge`, one rung smaller,
/// for no reason anybody wrote down.
///
/// It is kept only until the call sites outside `lib/shared/` have converted;
/// see `base_label_legacy.dart` for the rest of the bridge and why it exists.
class MenuItemLabel extends StatelessWidget {
  const MenuItemLabel(
    this.text, {
    super.key,
    this.color,
    this.fontWeight,
    this.textAlign,
    this.overflow,
    this.maxLines,
  });

  final String text;
  final Color? color;
  final FontWeight? fontWeight;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.onSurface;

    // ignore: avoid_text_with_style
    return Text(
      text,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: effectiveColor,
        fontWeight: fontWeight,
      ),
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
    );
  }
}
