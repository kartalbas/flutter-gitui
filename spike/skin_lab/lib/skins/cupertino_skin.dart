// iOS Cupertino skin - delegates to Flutter's cupertino library.
//
// Target, carried over from #249 and not open for reinterpretation: iOS HIG as
// implemented by Flutter's cupertino library, NOT macOS. Inter stands in for
// SF Pro. Liquid Glass is out of scope.
//
// Every `SIGNATURE:` comment below is a measurement, and every BLOCKED entry
// is a thing the spike refused to hand-paint around. Hand-painting a lookalike
// would have tested drawing skill; refusing to, and recording why, tests the
// actual question.
//
// ignore_for_file: avoid_dialog

// NOTE: this file imports cupertino and widgets ONLY. No material import. That
// is deliberate evidence: if a Cupertino skin needed Material to express any of
// the five components, the import list would say so.
import 'package:flutter/cupertino.dart';

import '../frozen/frozen_app_shell.dart';
import '../frozen/frozen_base_button.dart';
import '../frozen/frozen_base_dialog.dart';
import '../frozen/frozen_base_filter_chip.dart';
import '../frozen/frozen_base_text_field.dart';
import '../skin.dart';

class CupertinoSkin extends Skin {
  const CupertinoSkin();

  @override
  String get id => 'cupertino';

  @override
  String get label => 'iOS Cupertino';

  @override
  Iterable<LocalizationsDelegate<Object?>> get localizationsDelegates =>
      const <LocalizationsDelegate<Object?>>[
        DefaultCupertinoLocalizations.delegate,
      ];

  @override
  Widget wrapTheme(BuildContext context, Widget child) => CupertinoTheme(
    data: const CupertinoThemeData(),
    child: DefaultTextStyle(
      style: const CupertinoThemeData().textTheme.textStyle,
      child: child,
    ),
  );

  // ---------------------------------------------------------------- buttons
  //
  // SIGNATURE: FrozenBaseButton
  //   onPressed     EXACT   - CupertinoButton.onPressed.
  //   label         EXACT   - the child Text.
  //   variant       ADAPTED - 7 variants onto 3 canonical constructors
  //                           (.filled / .tinted / plain) plus a colour. The
  //                           mapping is total, but HIG recognises only
  //                           filled/tinted/plain/borderless emphasis, so
  //                           `ghost` and `tertiary` collapse onto one and
  //                           `dangerSecondary` has no HIG counterpart.
  //   size          ADAPTED - CupertinoButtonSize small/medium/large exists,
  //                           but its heights are 28/32/50, not our 32/40/48.
  //                           The names line up; the metrics do not.
  //   leadingIcon   EXACT   - Row child.
  //   trailingIcon  EXACT   - Row child.
  //   isLoading     ADAPTED - CupertinoActivityIndicator instead of a ring.
  //                           HIG shows the indicator INSTEAD of the label;
  //                           the signature offers no way to say that, so the
  //                           skin keeps our arrangement.
  //   isDisabled    EXACT   - onPressed: null.
  //   fullWidth     EXACT   - SizedBox.
  @override
  Widget button(FrozenBaseButton widget) {
    final bool disabled =
        widget.isDisabled || widget.isLoading || widget.onPressed == null;
    final VoidCallback? onPressed = disabled ? null : widget.onPressed;

    final CupertinoButtonSize sizeStyle = switch (widget.size) {
      ButtonSize.small => CupertinoButtonSize.small,
      ButtonSize.medium => CupertinoButtonSize.medium,
      ButtonSize.large => CupertinoButtonSize.large,
    };

    final Widget child = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.isLoading)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: CupertinoActivityIndicator(radius: 8),
          )
        else if (widget.leadingIcon != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(widget.leadingIcon, size: 18),
          ),
        Text(widget.label),
        if (widget.trailingIcon != null && !widget.isLoading)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Icon(widget.trailingIcon, size: 18),
          ),
      ],
    );

    final Widget button = switch (widget.variant) {
      ButtonVariant.primary => CupertinoButton.filled(
        sizeStyle: sizeStyle,
        onPressed: onPressed,
        child: child,
      ),
      ButtonVariant.danger => CupertinoButton.filled(
        sizeStyle: sizeStyle,
        color: CupertinoColors.destructiveRed,
        onPressed: onPressed,
        child: child,
      ),
      ButtonVariant.success => CupertinoButton.filled(
        sizeStyle: sizeStyle,
        color: CupertinoColors.systemGreen,
        onPressed: onPressed,
        child: child,
      ),
      ButtonVariant.secondary => CupertinoButton.tinted(
        sizeStyle: sizeStyle,
        onPressed: onPressed,
        child: child,
      ),
      ButtonVariant.dangerSecondary => CupertinoButton.tinted(
        sizeStyle: sizeStyle,
        color: CupertinoColors.destructiveRed,
        onPressed: onPressed,
        child: child,
      ),
      ButtonVariant.tertiary => CupertinoButton(
        sizeStyle: sizeStyle,
        onPressed: onPressed,
        child: child,
      ),
      ButtonVariant.ghost => CupertinoButton(
        sizeStyle: sizeStyle,
        onPressed: onPressed,
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: CupertinoColors.label),
          child: child,
        ),
      ),
    };

    return widget.fullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }

  // ------------------------------------------------------------ icon button
  //
  // SIGNATURE: FrozenBaseIconButton
  //   icon        EXACT   - Icon child of a CupertinoButton.
  //   variant     ADAPTED - same three constructors as above.
  //   size        ADAPTED - as above.
  //   isDisabled  EXACT   - onPressed: null.
  //   isSelected  LOSSY   - CupertinoButton has no selected state and iOS has
  //                         no toggle-icon-button idiom; the skin can only
  //                         recolour the glyph, losing the toggle SEMANTICS
  //                         that IconButton.isSelected sets.
  //   tooltip     BLOCKED - iOS has no tooltip and Flutter's cupertino library
  //                         ships no tooltip widget. The parameter also
  //                         carries the accessible name of an icon-only
  //                         control (the app relies on it for the labelled-
  //                         tap-target guideline), and there is nowhere in the
  //                         Cupertino widget to put either job. Not
  //                         hand-painted: Semantics(label:) below preserves
  //                         the ACCESSIBLE name only, and the hover name is
  //                         simply lost.
  @override
  Widget iconButton(FrozenBaseIconButton widget) {
    final bool disabled = widget.isDisabled || widget.onPressed == null;
    final double glyph = switch (widget.size) {
      ButtonSize.small => 16,
      ButtonSize.medium => 20,
      ButtonSize.large => 24,
    };
    final Color color = (widget.isSelected ?? false)
        ? CupertinoColors.activeBlue
        : CupertinoColors.label;

    final Widget button = CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.square(switch (widget.size) {
        ButtonSize.small => 32,
        ButtonSize.medium => 40,
        ButtonSize.large => 48,
      }),
      onPressed: disabled ? null : widget.onPressed,
      child: Icon(widget.icon, size: glyph, color: color),
    );

    // BLOCKED, mitigated only for accessibility: the tooltip STRING survives
    // as the semantic label; the tooltip BEHAVIOUR does not exist.
    return widget.tooltip == null
        ? button
        : Semantics(label: widget.tooltip, button: true, child: button);
  }

  // ------------------------------------------------------------- text field
  //
  // SIGNATURE: FrozenBaseTextField - the worst-scoring component of the five.
  //   controller / focusNode / initialValue / obscureText / maxLines /
  //   onChanged / onSubmitted / validator / autofocus / enabled
  //                       EXACT   - CupertinoTextFormFieldRow takes all of
  //                                 them under the same names.
  //   hintText            EXACT   - `placeholder`.
  //   escapeClears        EXACT   - our own Focus wrapper; language-neutral.
  //   label               LOSSY   - a floating label has no Cupertino meaning.
  //                                 The HIG grouped-form idiom is an inline
  //                                 leading label, which is the `prefix` slot
  //                                 - the SAME slot prefixIcon needs.
  //   prefixIcon          LOSSY   - shares one `prefix` slot with `label`; a
  //                                 field with both cannot be expressed as the
  //                                 canonical widget renders it.
  //   variant             LOSSY   - the enum names Material border classes
  //                                 (standard=UnderlineInputBorder,
  //                                 outlined/filled=OutlineInputBorder).
  //                                 Cupertino has ONE field appearance; all
  //                                 three values collapse to it.
  //   helperText          BLOCKED - CupertinoTextFormFieldRow has no helper
  //                                 slot. CupertinoFormRow does, but it is not
  //                                 exposed by the form-field widget, and
  //                                 dropping to CupertinoFormRow +
  //                                 CupertinoTextField loses Form
  //                                 registration, i.e. `validator`.
  //   errorText           ADAPTED - no slot either; injected through a
  //                                 wrapping validator so the row's own error
  //                                 line renders it.
  //   suffixIcon          BLOCKED |
  //   onSuffixTap         BLOCKED | CupertinoTextFormFieldRow HAS NO SUFFIX
  //   suffixTooltip       BLOCKED | SLOT AT ALL. CupertinoTextField does, but
  //   showClearButton     BLOCKED | it is not a FormField, so choosing it
  //   showPasswordToggle  BLOCKED | trades away `validator`. Five public
  //                               | parameters, one missing slot.
  @override
  Widget textField(TextFieldSlot slot) {
    final FrozenBaseTextField w = slot.widget;

    // ADAPTED: errorText has no slot, so it is folded into the validator the
    // row already runs.
    String? Function(String?)? validator;
    if (w.errorText != null || w.validator != null) {
      validator = (String? value) => w.errorText ?? w.validator?.call(value);
    }

    // LOSSY: one slot, two claimants. The label wins because a grouped iOS
    // form row without its leading label is unreadable; the prefix icon is
    // therefore dropped when both are present, and that drop is the finding.
    Widget? prefix;
    if (w.label != null) {
      prefix = Text(w.label!);
    } else if (w.prefixIcon != null) {
      prefix = Icon(w.prefixIcon, size: 20);
    }

    return CupertinoTextFormFieldRow(
      controller: slot.controller,
      focusNode: w.focusNode,
      prefix: prefix,
      placeholder: w.hintText,
      obscureText: slot.obscureText,
      maxLines: w.maxLines,
      onChanged: w.onChanged,
      onFieldSubmitted: w.onSubmitted,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      autofocus: w.autofocus,
      enabled: w.enabled,
    );
    // NOT DONE ON PURPOSE: no hand-built suffix row, no hand-drawn helper
    // line, no hand-painted variant borders. Each would have hidden a BLOCKED
    // finding behind a lookalike.
  }

  // ----------------------------------------------------------------- dialog
  //
  // SIGNATURE: FrozenBaseDialog - the sharpest probe, and it draws blood.
  //   title               EXACT   - CupertinoAlertDialog.title.
  //   content             EXACT   - CupertinoAlertDialog.content.
  //   barrierDismissible  EXACT   - showCupertinoDialog parameter (note its
  //                                 default is false, ours true).
  //   onSubmit            ADAPTED - not an iOS concept (no hardware Enter in
  //                                 the HIG model), but the keyboard host is
  //                                 language-neutral and desktop needs it.
  //   variant             LOSSY   - CupertinoAlertDialog has no variant. HIG
  //                                 expresses "destructive" on the ACTION
  //                                 (CupertinoDialogAction.isDestructiveAction),
  //                                 not on the dialog - and the actions are
  //                                 opaque Widgets, so the skin cannot get at
  //                                 them. The variant is therefore dropped.
  //   icon                BLOCKED - HIG alerts have no icon and
  //                                 CupertinoAlertDialog has no icon slot.
  //   maxWidth            BLOCKED - CupertinoAlertDialog is hard-pinned to
  //                                 270 pt (_kCupertinoDialogWidth in
  //                                 cupertino/dialog.dart); it is not a
  //                                 parameter and cannot be widened. Our
  //                                 default is 650 and 15 call sites pass a
  //                                 value.
  //   actions             BLOCKED - `List<Widget>` is opaque. A Cupertino
  //                                 alert stacks CupertinoDialogActions inside
  //                                 its own divided layout and needs to know
  //                                 which one is default and which is
  //                                 destructive. A List<Widget> of buttons
  //                                 renders as foreign controls inside the
  //                                 alert's action area, WITHOUT the dividers,
  //                                 the full-width stacking or the
  //                                 default/destructive treatment. The skin
  //                                 below passes them through unchanged so the
  //                                 lab SHOWS the breakage rather than hiding
  //                                 it behind a rewrite.
  @override
  Widget dialog(FrozenBaseDialog widget) {
    return DialogKeyboardHost(
      barrierDismissible: widget.barrierDismissible,
      onSubmit: widget.onSubmit,
      child: CupertinoAlertDialog(
        title: Text(widget.title),
        content: widget.content,
        actions: widget.actions ?? const <Widget>[],
      ),
    );
  }

  @override
  Future<T?> showDialog<T>(BuildContext context, FrozenBaseDialog dialog) {
    return showCupertinoDialog<T>(
      context: context,
      barrierDismissible: dialog.barrierDismissible,
      builder: (BuildContext context) =>
          wrapTheme(context, this.dialog(dialog)),
    );
  }

  // ------------------------------------------------------------------ shell
  //
  // SIGNATURE: FrozenAppShell
  //   body                   EXACT   - CupertinoPageScaffold.child.
  //   toolbar (Widget)       ADAPTED - iOS puts chrome in a navigation bar
  //                                    (CupertinoNavigationBar), which takes
  //                                    leading/middle/trailing slots, not one
  //                                    opaque Widget. Stacked above instead.
  //   destinations           ADAPTED - CupertinoListSection.insetGrouped +
  //                                    CupertinoListTile is the closest
  //                                    canonical construct and does carry
  //                                    icon, title and a trailing badge.
  //   selectedIndex          ADAPTED - no selection model on CupertinoListTile
  //                                    beyond a background colour.
  //   badgeCount             ADAPTED - CupertinoListTile.additionalInfo.
  //   railExtended           LOSSY   - iOS sidebars do not collapse to a rail;
  //                                    the collapsed state has no counterpart.
  //   onToggleRailExtended   LOSSY   - no HIG affordance to bind it to.
  //   statusBar              ADAPTED - stacked below.
  //
  // >>> THE FINDING: Flutter's cupertino library ships NO sidebar widget. The
  // >>> destination LIST delegates to CupertinoListSection/CupertinoListTile,
  // >>> but the sidebar CONTAINER - the fixed-width, always-visible column
  // >>> beside the content - has no counterpart in the SDK. The container
  // >>> below is a raw SizedBox + ColoredBox and is marked as such. It is the
  // >>> ONE place in this spike where delegation was impossible, and it is
  // >>> left visibly plain rather than dressed up.
  @override
  Widget shell(FrozenAppShell widget) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: widget.toolbar),
      child: Row(
        children: <Widget>[
          // NOT A CANONICAL WIDGET - see the finding above.
          //
          // The width is FIXED and ignores `railExtended`. That is not
          // laziness: a collapsed icon-only rail has no iOS counterpart, and
          // CupertinoListTile - the canonical row - hard-overflows below about
          // 110 px ("A RenderFlex overflowed by 22 pixels on the right",
          // reproduced at 88 px). Honouring the parameter would have meant
          // hand-painting a rail the language does not have. Recorded instead.
          SizedBox(
            width: 220,
            child: ColoredBox(
              color: CupertinoColors.systemGroupedBackground,
              child: CupertinoListSection.insetGrouped(
                children: <Widget>[
                  for (int i = 0; i < widget.destinations.length; i++)
                    CupertinoListTile.notched(
                      leading: Icon(
                        i == widget.selectedIndex
                            ? widget.destinations[i].selectedIcon
                            : widget.destinations[i].icon,
                      ),
                      title: Text(widget.destinations[i].label),
                      additionalInfo: widget.destinations[i].badgeCount == null
                          ? null
                          : Text('${widget.destinations[i].badgeCount}'),
                      backgroundColor: i == widget.selectedIndex
                          ? CupertinoColors.systemFill
                          : null,
                      onTap: () => widget.onDestinationSelected(i),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Expanded(child: widget.body),
                if (widget.statusBar != null) widget.statusBar!,
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ chips
  //
  // SIGNATURE: FrozenBaseFilterChip
  //   label / count / showCount  EXACT   - text.
  //   selected / onSelected      ADAPTED - a tinted/plain CupertinoButton
  //                                        toggle.
  //   icon                       EXACT   - Row child.
  //
  // >>> THE FINDING: there is no filter chip in the HIG and none in Flutter's
  // >>> cupertino library. A multi-select filter set is expressed with a
  // >>> different pattern entirely (a filter bar, a pull-down menu with
  // >>> checkmarks). The tinted-button toggle below is the closest CANONICAL
  // >>> widget, not a chip lookalike, which is why it does not look like our
  // >>> chip - deliberately.
  @override
  Widget filterChip(FrozenBaseFilterChip widget) {
    final String text = widget.showCount && widget.count != null
        ? '${widget.label} (${widget.count})'
        : widget.label;
    final Widget child = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.icon != null)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Icon(widget.icon, size: 16),
          ),
        Text(text),
      ],
    );
    return widget.selected
        ? CupertinoButton.tinted(
            sizeStyle: CupertinoButtonSize.small,
            onPressed: () => widget.onSelected(false),
            child: child,
          )
        : CupertinoButton(
            sizeStyle: CupertinoButtonSize.small,
            onPressed: () => widget.onSelected(true),
            child: child,
          );
  }

  // SIGNATURE: FrozenChoiceChipGroup - the payoff of the pattern-level seam.
  //   options / selectedIndex / onSelected  EXACT - this maps 1:1 onto
  //     CupertinoSlidingSegmentedControl, the HIG's actual answer to
  //     single-choice. The per-CHIP seam had nothing to return; the per-
  //     PATTERN seam is EXACT. Same information, different unit.
  //   ChoiceOption.icon                     ADAPTED - segment children are
  //     Widgets, so an icon fits, though HIG segments are text-or-icon, not
  //     both.
  @override
  Widget choiceChipGroup(FrozenChoiceChipGroup widget) {
    return CupertinoSlidingSegmentedControl<int>(
      groupValue: widget.selectedIndex,
      onValueChanged: (int? value) {
        if (value != null) widget.onSelected(value);
      },
      children: <int, Widget>{
        for (int i = 0; i < widget.options.length; i++)
          i: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(widget.options[i].label),
          ),
      },
    );
  }
}
