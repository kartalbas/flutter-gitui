// Material 3 skin - delegates to Flutter's material library, which IS the
// reference implementation of M3 (its defaults are generated from Google's
// token database).
//
// This skin is the control group. It is written against the CANONICAL M3
// widgets, not against the app's current rendering, so a parameter that is
// only EXACT because the app happens to render it that way today does not
// score EXACT here.
//
// ignore_for_file: avoid_filled_button, avoid_outlined_button, avoid_text_button
// ignore_for_file: avoid_icon_button, avoid_dialog, avoid_text_field
// ignore_for_file: avoid_filter_chip

import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as m show showDialog;

import '../app_stubs.dart';
import '../frozen/frozen_app_shell.dart';
import '../frozen/frozen_base_button.dart';
import '../frozen/frozen_base_dialog.dart';
import '../frozen/frozen_base_filter_chip.dart';
import '../frozen/frozen_base_text_field.dart';
import '../skin.dart';

class MaterialSkin extends Skin {
  const MaterialSkin();

  @override
  String get id => 'material';

  @override
  String get label => 'Material 3';

  @override
  Iterable<LocalizationsDelegate<Object?>> get localizationsDelegates =>
      const <LocalizationsDelegate<Object?>>[
        DefaultMaterialLocalizations.delegate,
      ];

  @override
  Widget wrapTheme(BuildContext context, Widget child) => child;

  // ---------------------------------------------------------------- buttons
  //
  // onPressed      EXACT     - VoidCallback? is the M3 signature verbatim.
  // label          EXACT     - becomes the button's child Text.
  // variant        EXACT     - 7 variants over 3 M3 families + a colour
  //                            override each; every one is expressible.
  // size           ADAPTED   - M3 has no button size scale; small/large are
  //                            minimumSize + textStyle + iconSize overrides.
  // leadingIcon    EXACT     - .icon constructors / Row child.
  // trailingIcon   ADAPTED   - M3's .icon constructor is leading-only; a
  //                            trailing icon is a Row inside the child.
  // isLoading      ADAPTED   - no loading state in M3 buttons; spinner in the
  //                            child plus onPressed: null.
  // isDisabled     EXACT     - onPressed: null.
  // fullWidth      EXACT     - SizedBox(width: infinity).
  @override
  Widget button(FrozenBaseButton widget) {
    return Builder(
      builder: (BuildContext context) {
        final ColorScheme scheme = Theme.of(context).colorScheme;
        final bool disabled =
            widget.isDisabled || widget.isLoading || widget.onPressed == null;
        final VoidCallback? onPressed = disabled ? null : widget.onPressed;
        final Widget child = _buttonChild(widget);

        final ButtonStyle? variantStyle = switch (widget.variant) {
          ButtonVariant.primary => null,
          ButtonVariant.danger => FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          ButtonVariant.success => FilledButton.styleFrom(
            backgroundColor: const GitSemanticColors().added,
            foregroundColor: Colors.white,
          ),
          ButtonVariant.secondary => null,
          ButtonVariant.dangerSecondary => OutlinedButton.styleFrom(
            foregroundColor: scheme.error,
          ),
          ButtonVariant.tertiary => null,
          ButtonVariant.ghost => TextButton.styleFrom(
            foregroundColor: scheme.onSurface,
          ),
        };

        // ADAPTED: the size scale is expressed as style overrides, because M3
        // itself defines exactly one button size.
        final ButtonStyle style = ButtonStyle(
          minimumSize: WidgetStatePropertyAll<Size>(switch (widget.size) {
            ButtonSize.small => const Size(48, 32),
            ButtonSize.medium => const Size(64, 40),
            ButtonSize.large => const Size(64, 48),
          }),
        ).merge(variantStyle);

        final Widget button = switch (baseOf(widget.variant)) {
          MaterialBase.filled => FilledButton(
            onPressed: onPressed,
            style: style,
            child: child,
          ),
          MaterialBase.outlined => OutlinedButton(
            onPressed: onPressed,
            style: style,
            child: child,
          ),
          MaterialBase.text => TextButton(
            onPressed: onPressed,
            style: style,
            child: child,
          ),
        };

        return widget.fullWidth
            ? SizedBox(width: double.infinity, child: button)
            : button;
      },
    );
  }

  Widget _buttonChild(FrozenBaseButton widget) {
    if (!widget.isLoading &&
        widget.leadingIcon == null &&
        widget.trailingIcon == null) {
      return Text(widget.label);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: <Widget>[
        if (widget.isLoading)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (widget.leadingIcon != null)
          Icon(widget.leadingIcon),
        Text(widget.label),
        if (widget.trailingIcon != null && !widget.isLoading)
          Icon(widget.trailingIcon),
      ],
    );
  }

  // ------------------------------------------------------------ icon button
  //
  // icon        EXACT   - Icon child.
  // tooltip     EXACT   - IconButton.tooltip.
  // variant     EXACT   - standard / .filled / .outlined cover all 7.
  // size        ADAPTED - iconSize + minimumSize overrides.
  // isSelected  EXACT   - IconButton.isSelected, native toggle support.
  // isDisabled  EXACT   - onPressed: null.
  @override
  Widget iconButton(FrozenBaseIconButton widget) {
    final bool disabled = widget.isDisabled || widget.onPressed == null;
    final (double container, double glyph) = switch (widget.size) {
      ButtonSize.small => (32.0, 16.0),
      ButtonSize.medium => (40.0, 20.0),
      ButtonSize.large => (48.0, 24.0),
    };
    final ButtonStyle style = ButtonStyle(
      iconSize: WidgetStatePropertyAll<double>(glyph),
      minimumSize: WidgetStatePropertyAll<Size>(Size.square(container)),
    );
    final Widget icon = Icon(widget.icon);
    final VoidCallback? onPressed = disabled ? null : widget.onPressed;

    return switch (baseOf(widget.variant)) {
      MaterialBase.filled => IconButton.filled(
        onPressed: onPressed,
        icon: icon,
        tooltip: widget.tooltip,
        isSelected: widget.isSelected,
        style: style,
      ),
      MaterialBase.outlined => IconButton.outlined(
        onPressed: onPressed,
        icon: icon,
        tooltip: widget.tooltip,
        isSelected: widget.isSelected,
        style: style,
      ),
      MaterialBase.text => IconButton(
        onPressed: onPressed,
        icon: icon,
        tooltip: widget.tooltip,
        isSelected: widget.isSelected,
        style: style,
      ),
    };
  }

  // ------------------------------------------------------------- text field
  //
  // Every parameter is EXACT here by construction: the signature IS a
  // transcript of InputDecoration. That is precisely why this component is the
  // least portable of the five - see the Cupertino and Fluent tables.
  @override
  Widget textField(TextFieldSlot slot) {
    final FrozenBaseTextField w = slot.widget;
    Widget? suffix;
    if (w.showPasswordToggle && w.obscureText) {
      suffix = IconButton(
        icon: Icon(
          slot.obscureText
              ? PhosphorIconsRegular.eye
              : PhosphorIconsRegular.eyeSlash,
        ),
        onPressed: slot.togglePasswordVisibility,
      );
    } else if (w.showClearButton && slot.hasText) {
      suffix = IconButton(
        icon: const Icon(PhosphorIconsRegular.x),
        onPressed: slot.clearText,
      );
    } else if (w.suffixIcon != null) {
      suffix = w.onSuffixTap == null
          ? Icon(w.suffixIcon)
          : IconButton(icon: Icon(w.suffixIcon), onPressed: w.onSuffixTap);
    }

    return TextFormField(
      controller: slot.controller,
      focusNode: w.focusNode,
      obscureText: slot.obscureText,
      maxLines: w.maxLines,
      onChanged: w.onChanged,
      onFieldSubmitted: w.onSubmitted,
      validator: w.validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      autofocus: w.autofocus,
      enabled: w.enabled,
      decoration: InputDecoration(
        labelText: w.label,
        hintText: w.hintText,
        helperText: w.helperText,
        errorText: w.errorText,
        prefixIcon: w.prefixIcon == null ? null : Icon(w.prefixIcon),
        suffixIcon: suffix,
        // variant EXACT: the enum names the M3 border classes directly.
        border: switch (w.variant) {
          TextFieldVariant.standard => const UnderlineInputBorder(),
          TextFieldVariant.outlined => const OutlineInputBorder(),
          TextFieldVariant.filled => const OutlineInputBorder(
            borderSide: BorderSide.none,
          ),
        },
        filled: w.variant == TextFieldVariant.filled,
      ),
    );
  }

  // ----------------------------------------------------------------- dialog
  //
  // title              EXACT   - AlertDialog.title.
  // content            EXACT   - AlertDialog.content.
  // actions            EXACT   - AlertDialog.actions is List<Widget> too; the
  //                              opacity of the list costs Material nothing,
  //                              because Material's end-alignment needs no
  //                              knowledge of which action is affirmative.
  // variant            ADAPTED - no variant concept; expressed as icon+colour.
  // icon               EXACT   - AlertDialog.icon (M3 has an icon slot).
  // maxWidth           ADAPTED - not an AlertDialog parameter; ConstrainedBox.
  // barrierDismissible EXACT   - showDialog parameter.
  // onSubmit           ADAPTED - not an M3 concept; our own keyboard host.
  @override
  Widget dialog(FrozenBaseDialog widget) {
    return Builder(
      builder: (BuildContext context) {
        final ColorScheme scheme = Theme.of(context).colorScheme;
        final bool destructive = widget.variant == DialogVariant.destructive;
        final IconData? icon =
            widget.icon ??
            switch (widget.variant) {
              DialogVariant.normal => null,
              DialogVariant.confirmation => PhosphorIconsRegular.question,
              DialogVariant.destructive => PhosphorIconsRegular.warning,
            };

        return DialogKeyboardHost(
          barrierDismissible: widget.barrierDismissible,
          onSubmit: widget.onSubmit,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.maxWidth),
            child: AlertDialog(
              icon: icon == null ? null : Icon(icon),
              iconColor: destructive ? scheme.error : scheme.primary,
              title: Text(widget.title),
              content: SingleChildScrollView(child: widget.content),
              actions: widget.actions,
            ),
          ),
        );
      },
    );
  }

  @override
  Future<T?> showDialog<T>(BuildContext context, FrozenBaseDialog dialog) {
    return m.showDialog<T>(
      context: context,
      barrierDismissible: dialog.barrierDismissible,
      builder: (BuildContext context) => this.dialog(dialog),
    );
  }

  // ------------------------------------------------------------------ shell
  //
  // destinations           EXACT   - NavigationRailDestination.
  // selectedIndex          EXACT   - NavigationRail.selectedIndex.
  // onDestinationSelected  EXACT   - NavigationRail.onDestinationSelected.
  // railExtended           EXACT   - NavigationRail.extended.
  // onToggleRailExtended   ADAPTED - no built-in toggle; a trailing button.
  // badgeCount             EXACT   - Badge around the destination icon.
  // toolbar (Widget)       EXACT   - a Column child above the body.
  // body                   EXACT   - Expanded.
  // statusBar              EXACT   - a Column child below the body.
  @override
  Widget shell(FrozenAppShell widget) {
    return Scaffold(
      body: Row(
        children: <Widget>[
          NavigationRail(
            extended: widget.railExtended,
            selectedIndex: widget.selectedIndex,
            onDestinationSelected: widget.onDestinationSelected,
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: IconButton(
                  icon: Icon(
                    widget.railExtended
                        ? PhosphorIconsRegular.caretLeft
                        : PhosphorIconsRegular.caretRight,
                  ),
                  onPressed: widget.onToggleRailExtended,
                ),
              ),
            ),
            destinations: <NavigationRailDestination>[
              for (final ShellDestination d in widget.destinations)
                NavigationRailDestination(
                  icon: d.badgeCount == null
                      ? Icon(d.icon)
                      : Badge(
                          label: Text('${d.badgeCount}'),
                          child: Icon(d.icon),
                        ),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Column(
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
  // label / selected / onSelected / icon  EXACT - FilterChip verbatim.
  // count / showCount                     EXACT - string concatenation.
  @override
  Widget filterChip(FrozenBaseFilterChip widget) {
    return FilterChip(
      selected: widget.selected,
      onSelected: widget.onSelected,
      avatar: widget.icon == null ? null : Icon(widget.icon, size: 16),
      label: Text(
        widget.showCount && widget.count != null
            ? '${widget.label} (${widget.count})'
            : widget.label,
      ),
    );
  }

  @override
  Widget choiceChipGroup(FrozenChoiceChipGroup widget) {
    return SegmentedButton<int>(
      segments: <ButtonSegment<int>>[
        for (int i = 0; i < widget.options.length; i++)
          ButtonSegment<int>(
            value: i,
            label: Text(widget.options[i].label),
            icon: widget.options[i].icon == null
                ? null
                : Icon(widget.options[i].icon),
          ),
      ],
      selected: <int>{widget.selectedIndex},
      onSelectionChanged: (Set<int> s) => widget.onSelected(s.first),
      showSelectedIcon: false,
    );
  }
}
