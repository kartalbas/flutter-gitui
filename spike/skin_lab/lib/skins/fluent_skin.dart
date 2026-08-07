// Fluent 2 / WinUI skin - delegates to package:fluent_ui 4.16.1.
//
// Day-one findings this skin is built on (see test/day_one_risk_test.dart):
//   * fluent_ui resolves in this workspace against Flutter 3.44.4 / Dart 3.12.2
//     and adds no version pressure to any existing app dependency.
//   * Fluent overlays DO work under a non-FluentApp root. `fluent.showDialog`
//     captures ancestor InheritedThemes into the route, so a FluentTheme in the
//     page subtree survives; flyouts do NOT capture and must re-wrap.
//   * `fluent.showDialog` hard-asserts FluentLocalizations, so the skin has to
//     contribute a localizations delegate to the ONE app root.
//
// ignore_for_file: avoid_dialog

import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';

import '../frozen/frozen_app_shell.dart';
import '../frozen/frozen_base_button.dart';
import '../frozen/frozen_base_dialog.dart';
import '../frozen/frozen_base_filter_chip.dart';
import '../frozen/frozen_base_text_field.dart';
import '../skin.dart';

class FluentSkin extends Skin {
  const FluentSkin();

  @override
  String get id => 'fluent';

  @override
  String get label => 'Fluent 2';

  @override
  Iterable<LocalizationsDelegate<Object?>> get localizationsDelegates =>
      const <LocalizationsDelegate<Object?>>[
        fluent.FluentLocalizations.delegate,
      ];

  @override
  Widget wrapTheme(BuildContext context, Widget child) =>
      fluent.FluentTheme(data: fluent.FluentThemeData(), child: child);

  // ---------------------------------------------------------------- buttons
  //
  // SIGNATURE: FrozenBaseButton
  //   onPressed     EXACT   - fluent.BaseButton.onPressed.
  //   label         EXACT   - the child Text.
  //   variant       ADAPTED - 7 variants onto FilledButton (accent) /
  //                           Button (standard) / HyperlinkButton, plus a
  //                           ButtonStyle colour override. Total, but Fluent 2
  //                           recognises accent / standard / hyperlink /
  //                           subtle only, so `danger` and `success` are
  //                           colour overrides of accent rather than named
  //                           Fluent styles.
  //   size          LOSSY   - Fluent 2 has ONE standard control height (32 px)
  //                           and no button size scale at all. All three of
  //                           our sizes collapse; forcing 32/40/48 would mean
  //                           hand-painting past the spec, which this spike
  //                           refuses to do. Rendered at the Fluent height.
  //   leadingIcon   EXACT   - Row child.
  //   trailingIcon  EXACT   - Row child.
  //   isLoading     ADAPTED - fluent.ProgressRing in the child.
  //   isDisabled    EXACT   - onPressed: null.
  //   fullWidth     EXACT   - SizedBox.
  @override
  Widget button(FrozenBaseButton widget) {
    final bool disabled =
        widget.isDisabled || widget.isLoading || widget.onPressed == null;
    final VoidCallback? onPressed = disabled ? null : widget.onPressed;

    final Widget child = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.isLoading)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 16,
              height: 16,
              child: fluent.ProgressRing(strokeWidth: 2),
            ),
          )
        else if (widget.leadingIcon != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(widget.leadingIcon, size: 16),
          ),
        Text(widget.label),
        if (widget.trailingIcon != null && !widget.isLoading)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Icon(widget.trailingIcon, size: 16),
          ),
      ],
    );

    fluent.ButtonStyle? tint(Color color) => fluent.ButtonStyle(
      backgroundColor: WidgetStatePropertyAll<Color>(color),
    );

    final Widget button = switch (widget.variant) {
      ButtonVariant.primary => fluent.FilledButton(
        onPressed: onPressed,
        child: child,
      ),
      ButtonVariant.danger => fluent.FilledButton(
        onPressed: onPressed,
        style: tint(fluent.Colors.red),
        child: child,
      ),
      ButtonVariant.success => fluent.FilledButton(
        onPressed: onPressed,
        style: tint(fluent.Colors.green),
        child: child,
      ),
      ButtonVariant.secondary => fluent.Button(
        onPressed: onPressed,
        child: child,
      ),
      ButtonVariant.dangerSecondary => fluent.Button(
        onPressed: onPressed,
        style: fluent.ButtonStyle(
          foregroundColor: WidgetStatePropertyAll<Color>(fluent.Colors.red),
        ),
        child: child,
      ),
      ButtonVariant.tertiary => fluent.HyperlinkButton(
        onPressed: onPressed,
        child: child,
      ),
      ButtonVariant.ghost => fluent.Button(
        onPressed: onPressed,
        style: const fluent.ButtonStyle(
          backgroundColor: WidgetStatePropertyAll<Color>(Color(0x00000000)),
          shape: WidgetStatePropertyAll<ShapeBorder>(
            RoundedRectangleBorder(side: BorderSide.none),
          ),
        ),
        child: child,
      ),
    };

    return widget.fullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }

  // ------------------------------------------------------------ icon button
  //
  // SIGNATURE: FrozenBaseIconButton
  //   icon        EXACT   - fluent.IconButton.icon.
  //   tooltip     EXACT   - fluent.Tooltip wrapper (Fluent HAS tooltips;
  //                         Cupertino does not - the same parameter scores
  //                         EXACT here and BLOCKED there).
  //   variant     ADAPTED - IconButton (subtle) vs FilledButton with an icon
  //                         child; Fluent has no outlined icon button.
  //   size        LOSSY   - IconButtonMode.small/large only; no three-step
  //                         scale, and the modes are 24/32 px, not 32/40/48.
  //   isSelected  ADAPTED - fluent.ToggleButton, a DIFFERENT WIDGET CLASS.
  //                         The signature folds "action button" and "toggle"
  //                         into one optional bool, so the skin has to switch
  //                         widget classes on a nullable field.
  //   isDisabled  EXACT   - onPressed: null.
  @override
  Widget iconButton(FrozenBaseIconButton widget) {
    final bool disabled = widget.isDisabled || widget.onPressed == null;
    final double glyph = switch (widget.size) {
      ButtonSize.small => 16,
      ButtonSize.medium => 20,
      ButtonSize.large => 24,
    };
    final Widget icon = Icon(widget.icon, size: glyph);

    Widget button;
    if (widget.isSelected != null) {
      button = fluent.ToggleButton(
        checked: widget.isSelected!,
        onChanged: disabled ? null : (bool _) => widget.onPressed?.call(),
        child: icon,
      );
    } else {
      button = fluent.IconButton(
        icon: icon,
        iconButtonMode: switch (widget.size) {
          ButtonSize.small => fluent.IconButtonMode.small,
          ButtonSize.medium => fluent.IconButtonMode.large,
          ButtonSize.large => fluent.IconButtonMode.large,
        },
        onPressed: disabled ? null : widget.onPressed,
      );
    }

    return widget.tooltip == null
        ? button
        : fluent.Tooltip(message: widget.tooltip, child: button);
  }

  // ------------------------------------------------------------- text field
  //
  // SIGNATURE: FrozenBaseTextField
  //   controller / focusNode / obscureText / maxLines / onChanged /
  //   onSubmitted / validator / autofocus / enabled
  //                       EXACT   - fluent.TextFormBox takes all of them.
  //   hintText            EXACT   - `placeholder`.
  //   prefixIcon          EXACT   - `prefix`.
  //   suffixIcon          EXACT   - `suffix`.
  //   onSuffixTap         EXACT   - an IconButton in the suffix slot.
  //   suffixTooltip       EXACT   - fluent.Tooltip on that button.
  //   showClearButton     EXACT   - suffix slot.
  //   showPasswordToggle  EXACT   - suffix slot (fluent.PasswordBox also
  //                                 exists, but it is not a FormField).
  //   escapeClears        EXACT   - our own Focus wrapper; language-neutral.
  //   errorText           ADAPTED - no slot; folded into the validator.
  //   label               ADAPTED - Fluent's label is a HEADER ABOVE the box
  //                                 (fluent.InfoLabel), never floating. The
  //                                 string survives; the floating BEHAVIOUR
  //                                 that the parameter's doc promises
  //                                 ("floats above field when focused or has
  //                                 value") does not exist in Fluent.
  //   helperText          LOSSY   - no slot on TextFormBox; Fluent puts a
  //                                 caption below the field, which is
  //                                 composition around the widget rather than
  //                                 a property of it, so it cannot be
  //                                 delegated - only stacked.
  //   variant             LOSSY   - the enum names Material border classes.
  //                                 Fluent has ONE TextBox appearance (a
  //                                 bottom accent stroke on focus); all three
  //                                 values collapse to it.
  @override
  Widget textField(TextFieldSlot slot) {
    final FrozenBaseTextField w = slot.widget;

    Widget? suffix;
    if (w.showPasswordToggle && w.obscureText) {
      suffix = fluent.IconButton(
        icon: Icon(
          slot.obscureText ? fluent.FluentIcons.hide3 : fluent.FluentIcons.view,
          size: 14,
        ),
        onPressed: slot.togglePasswordVisibility,
      );
    } else if (w.showClearButton && slot.hasText) {
      suffix = fluent.IconButton(
        icon: const Icon(fluent.FluentIcons.clear, size: 12),
        onPressed: slot.clearText,
      );
    } else if (w.suffixIcon != null) {
      final Widget glyph = Icon(w.suffixIcon, size: 16);
      suffix = w.onSuffixTap == null
          ? glyph
          : fluent.Tooltip(
              message: w.suffixTooltip ?? '',
              child: fluent.IconButton(
                icon: glyph,
                onPressed: w.enabled ? w.onSuffixTap : null,
              ),
            );
    }

    String? Function(String?)? validator;
    if (w.errorText != null || w.validator != null) {
      validator = (String? value) => w.errorText ?? w.validator?.call(value);
    }

    final Widget field = fluent.TextFormBox(
      controller: slot.controller,
      focusNode: w.focusNode,
      placeholder: w.hintText,
      prefix: w.prefixIcon == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(w.prefixIcon, size: 16),
            ),
      suffix: suffix,
      obscureText: slot.obscureText,
      maxLines: w.maxLines,
      onChanged: w.onChanged,
      onFieldSubmitted: w.onSubmitted,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      autofocus: w.autofocus,
      enabled: w.enabled,
    );

    final Widget labelled = w.label == null
        ? field
        : fluent.InfoLabel(label: w.label!, child: field);

    // LOSSY: helperText can only be STACKED next to the delegated widget.
    return w.helperText == null
        ? labelled
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              labelled,
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(w.helperText!),
              ),
            ],
          );
  }

  // ----------------------------------------------------------------- dialog
  //
  // SIGNATURE: FrozenBaseDialog
  //   title               EXACT   - ContentDialog.title.
  //   content             EXACT   - ContentDialog.content.
  //   maxWidth            EXACT   - ContentDialog.constraints (its own default
  //                                 is 368; ours passes straight through).
  //   barrierDismissible  EXACT   - fluent.showDialog parameter.
  //   onSubmit            ADAPTED - our keyboard host; Fluent has no concept,
  //                                 though it does have `dismissWithEsc`.
  //   variant             LOSSY   - ContentDialog has no variant. Fluent
  //                                 expresses "destructive" by styling the
  //                                 affirmative BUTTON, which the skin cannot
  //                                 reach - see `actions`.
  //   icon                BLOCKED - ContentDialog has no icon slot and Fluent
  //                                 dialogs carry no title icon.
  //   actions             BLOCKED - THE SHARPEST RESULT OF THE SPIKE.
  //                                 `List<Widget>` is opaque. Fluent 2 places
  //                                 the AFFIRMATIVE action on the LEFT and the
  //                                 dismissive on the right - the opposite of
  //                                 Material and Apple - and stretches both to
  //                                 equal width. The skin can see only "two
  //                                 widgets", so it cannot tell which is
  //                                 affirmative. Blind reversal is wrong the
  //                                 moment a dialog has three actions (14
  //                                 `BaseDialog.show` sites and the update
  //                                 dialog do), and stretching a widget it
  //                                 cannot re-style produces two differently
  //                                 shaped buttons.
  //                                 The skin below therefore does NOT reverse.
  //                                 It hands the list through in call order so
  //                                 the lab renders the WRONG-for-Fluent
  //                                 order, which is the evidence.
  @override
  Widget dialog(FrozenBaseDialog widget) {
    return DialogKeyboardHost(
      barrierDismissible: widget.barrierDismissible,
      onSubmit: widget.onSubmit,
      child: fluent.ContentDialog(
        title: Text(widget.title),
        content: widget.content,
        actions: widget.actions,
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
      ),
    );
  }

  @override
  Future<T?> showDialog<T>(BuildContext context, FrozenBaseDialog dialog) {
    return fluent.showDialog<T>(
      context: context,
      barrierDismissible: dialog.barrierDismissible,
      // The day-one probe showed fluent.showDialog captures ancestor
      // InheritedThemes, so this wrap is belt-and-braces for a caller whose
      // context sits outside the skin's theme (e.g. a Navigator-level call).
      builder: (BuildContext context) =>
          wrapTheme(context, this.dialog(dialog)),
    );
  }

  // ------------------------------------------------------------------ shell
  //
  // SIGNATURE: FrozenAppShell
  //   destinations           EXACT   - fluent.PaneItem(icon:, title:).
  //   badgeCount             EXACT   - PaneItem.infoBadge, a first-class
  //                                    Fluent affordance.
  //   selectedIndex          EXACT   - NavigationPane.selected.
  //   onDestinationSelected  EXACT   - NavigationPane.onChanged.
  //   railExtended           EXACT   - PaneDisplayMode.open vs .compact.
  //   body                   EXACT   - PaneItem.body.
  //   onToggleRailExtended   LOSSY   - NavigationPane owns its OWN toggle
  //                                    button (`toggleButton`), so binding our
  //                                    external toggle would put two
  //                                    affordances on one job. Dropped.
  //   toolbar (Widget)       BLOCKED - Fluent dissolves the AppBar concept:
  //                                    chrome lives in the window `titleBar`
  //                                    and in a CommandBar INSIDE the page.
  //                                    An opaque Widget can only be stacked
  //                                    above the content, which is not the
  //                                    Fluent arrangement, and a CommandBar
  //                                    needs `List<CommandBarItem>`, which the
  //                                    signature does not carry.
  //   statusBar              ADAPTED - stacked below the page content.
  @override
  Widget shell(FrozenAppShell widget) {
    return fluent.NavigationView(
      pane: fluent.NavigationPane(
        selected: widget.selectedIndex,
        onChanged: widget.onDestinationSelected,
        displayMode: widget.railExtended
            ? fluent.PaneDisplayMode.expanded
            : fluent.PaneDisplayMode.compact,
        items: <fluent.NavigationPaneItem>[
          for (final ShellDestination d in widget.destinations)
            fluent.PaneItem(
              icon: Icon(d.icon),
              title: Text(d.label),
              infoBadge: d.badgeCount == null
                  ? null
                  : fluent.InfoBadge(source: Text('${d.badgeCount}')),
              // BLOCKED: `toolbar` has nowhere Fluent-correct to go, so it is
              // stacked above the body and the deviation is recorded rather
              // than disguised.
              body: Column(
                children: <Widget>[
                  widget.toolbar,
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
  //   selected / onSelected      ADAPTED - fluent.ToggleButton is the closest
  //                                        canonical control; Fluent 2 has no
  //                                        chip.
  //   icon                       EXACT   - Row child.
  @override
  Widget filterChip(FrozenBaseFilterChip widget) {
    return fluent.ToggleButton(
      checked: widget.selected,
      onChanged: widget.onSelected,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (widget.icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(widget.icon, size: 14),
            ),
          Text(
            widget.showCount && widget.count != null
                ? '${widget.label} (${widget.count})'
                : widget.label,
          ),
        ],
      ),
    );
  }

  // SIGNATURE: FrozenChoiceChipGroup
  //   options / selectedIndex / onSelected  ADAPTED - Fluent 2's answer to
  //     single-choice is a RadioButton group (or a ComboBox when the list is
  //     long). fluent_ui 4.16.1 ships no segmented control, so unlike
  //     Cupertino this is not a 1:1 map - but it is still ONE pattern-level
  //     answer, which the per-chip seam could not have produced either.
  @override
  Widget choiceChipGroup(FrozenChoiceChipGroup widget) {
    return RadioGroup<int>(
      groupValue: widget.selectedIndex,
      onChanged: (int? value) {
        if (value != null) widget.onSelected(value);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < widget.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: fluent.RadioButton(
                value: i,
                content: Text(widget.options[i].label),
              ),
            ),
        ],
      ),
    );
  }
}
