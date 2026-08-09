import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../fluent_geometry.dart';
import '../fluent_ink.dart';
import '../fluent_motion.dart';
import '../fluent_resources.dart';
import '../fluent_theme.dart';
import '../fluent_typography.dart';
import 'fluent_pressable.dart';

/// The Fluent text-entry shell: the WinUI TextBox drawn once, worn by
/// `textField`, `dateField` and `suggestField`.
///
/// Anatomy and states from the reference (fluent_ui@4.16.1
/// lib/src/controls/form/text_box.dart):
///
///  * content padding 10 / 5 / 6 / 6 (`kTextBoxPadding`, :11), corner 4 and
///    a 1 epx `ControlStrokeColorDefault` border on every side
///    (:1526-1539), minimum height 32 (:1610-1615);
///  * the FILL ladder: `ControlFillColorDefault` at rest, `Secondary`
///    hovered, and SOLID `InputActive` the moment the box holds the
///    keyboard (:1436-1448) - a Fluent text box is translucent until you
///    type into it;
///  * the BOTTOM HAIRLINE, Fluent's signature: a 1.25 epx
///    `ControlStrongStrokeColorDefault` run along the bottom edge at rest
///    that thickens to a 2 epx accent underline while focused, and
///    disappears when disabled (:1557-1586);
///  * the placeholder writes in `TextFillColorSecondary`, dropping to
///    `Tertiary` while the box is focused (:1451-1461);
///  * text is the body step in `TextFillColorPrimary`, `Disabled` when the
///    box is (:1311-1319); the caret is the theme's inactive ink
///    (:1324-1326, `FluentThemeData.inactiveColor` - black on light, white
///    on dark, styles/theme.dart:451) and the selection wash is the accent
///    swatch's `normal` stop (:1330-1332).
///
/// The keyboard contract is the application's, not this skin's to weaken:
/// Escape in a non-empty field empties it and keeps focus
/// (`FieldSpec.escapeClears`), and an empty field lets Escape bubble to the
/// enclosing dismiss scope.
final class FluentTextBox extends StatefulWidget {
  /// Builds the shell.
  const FluentTextBox({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    this.placeholder,
    this.obscure = false,
    this.maxLines = 1,
    this.autofocus = false,
    this.selectable = true,
    this.escapeClears = false,
    this.onChanged,
    this.onSubmitted,
    this.onCleared,
    this.leading,
    this.trailing,
  });

  /// The live text, owned by the caller.
  final TextEditingController controller;

  /// The live focus, owned by the caller.
  final FocusNode focusNode;

  /// Whether the box takes input at all.
  final bool enabled;

  /// What to say while the box is empty.
  final String? placeholder;

  /// Whether the answer is hidden.
  final bool obscure;

  /// How many lines the answer may take.
  final int maxLines;

  /// Whether to take the keyboard when the surface opens.
  final bool autofocus;

  /// Whether the user can select and copy what is in it.
  final bool selectable;

  /// Whether Escape in a non-empty box empties it rather than leaving.
  final bool escapeClears;

  /// How to report a changed answer.
  final ValueChanged<String>? onChanged;

  /// How to report a finished answer.
  final ValueChanged<String>? onSubmitted;

  /// What emptying via Escape additionally reports, so the application and
  /// the hosting form both hear about it.
  final VoidCallback? onCleared;

  /// A mark at the head of the box.
  final Widget? leading;

  /// The in-field affordances at the end of the box.
  final Widget? trailing;

  /// Content padding: `kTextBoxPadding` (text_box.dart:11).
  static const EdgeInsetsGeometry padding = EdgeInsetsDirectional.fromSTEB(
    10,
    5,
    6,
    6,
  );

  /// The box corner (text_box.dart:1526).
  static const double cornerRadius = 4;

  /// The minimum height (text_box.dart:1612-1615).
  static const double minHeight = 32;

  /// The resting bottom hairline's width (text_box.dart:1581).
  static const double restUnderlineWidth = 1.25;

  /// The focused accent underline's width (text_box.dart:1568).
  static const double focusedUnderlineWidth = 2;

  @override
  State<FluentTextBox> createState() => _FluentTextBoxState();
}

class _FluentTextBoxState extends State<FluentTextBox> {
  bool _hovering = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChanged);
    _focused = widget.focusNode.hasFocus;
  }

  @override
  void didUpdateWidget(FluentTextBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.focusNode, widget.focusNode)) {
      oldWidget.focusNode.removeListener(_handleFocusChanged);
      widget.focusNode.addListener(_handleFocusChanged);
      _focused = widget.focusNode.hasFocus;
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChanged);
    super.dispose();
  }

  void _handleFocusChanged() =>
      setState(() => _focused = widget.focusNode.hasFocus);

  /// Whether Escape right now means "empty it".
  bool get _canClearOnEscape =>
      widget.escapeClears &&
      widget.enabled &&
      widget.controller.text.isNotEmpty;

  void _clear() {
    widget.controller.clear();
    widget.onChanged?.call('');
    widget.onCleared?.call();
  }

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentResources res = theme.resources;

    // The fill ladder (text_box.dart:1436-1448). Hover is tracked with a
    // MouseRegion rather than a FocusableActionDetector highlight: a text
    // box darkens under the pointer however the app got its focus, and the
    // highlight callbacks stay silent outside traditional mode.
    final Color fill = !widget.enabled
        ? res.controlFillColorDisabled
        : _focused
        ? res.controlFillColorInputActive
        : _hovering
        ? res.controlFillColorSecondary
        : res.controlFillColorDefault;

    // The bottom hairline (text_box.dart:1557-1586).
    final Border? underline = !widget.enabled
        ? null
        : Border(
            bottom: _focused
                ? BorderSide(
                    color: theme.accent.defaultBrushFor(theme.brightness),
                    width: FluentTextBox.focusedUnderlineWidth,
                  )
                : BorderSide(
                    color: res.controlStrongStrokeColorDefault,
                    width: FluentTextBox.restUnderlineWidth,
                  ),
          );

    final TextStyle textStyle =
        FluentTypeResolution.styleOf(context, TextRole.body).copyWith(
          color: widget.enabled
              ? res.textFillColorPrimary
              : res.textFillColorDisabled,
        );
    final TextStyle placeholderStyle = textStyle.copyWith(
      color: !widget.enabled
          ? res.textFillColorDisabled
          : _focused
          ? res.textFillColorTertiary
          : res.textFillColorSecondary,
    );

    // The caret ink: FluentThemeData.inactiveColor - black on light, white
    // on dark (styles/theme.dart:451), read at text_box.dart:1324-1326.
    final Color caret = theme.brightness == Brightness.light
        ? const Color(0xFF000000)
        : const Color(0xFFffffff);

    return Actions(
      actions: <Type, Action<Intent>>{DismissIntent: _ClearOnEscape(this)},
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.text
            : SystemMouseCursors.basic,
        onEnter: (PointerEnterEvent event) => setState(() => _hovering = true),
        onExit: (PointerExitEvent event) => setState(() => _hovering = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? widget.focusNode.requestFocus : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(FluentTextBox.cornerRadius),
            child: AnimatedContainer(
              duration: FluentMotion.faster,
              curve: FluentMotion.curve,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(FluentTextBox.cornerRadius),
                border: Border.all(color: res.controlStrokeColorDefault),
              ),
              foregroundDecoration: underline == null
                  ? null
                  : BoxDecoration(border: underline),
              constraints: const BoxConstraints(
                minHeight: FluentTextBox.minHeight,
              ),
              child: Row(
                crossAxisAlignment: widget.maxLines > 1
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: <Widget>[
                  if (widget.leading != null) widget.leading!,
                  Expanded(
                    child: Padding(
                      padding: FluentTextBox.padding,
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: widget.controller,
                        builder:
                            (
                              BuildContext context,
                              TextEditingValue value,
                              Widget? child,
                            ) => Stack(
                              children: <Widget>[
                                if (value.text.isEmpty &&
                                    widget.placeholder != null)
                                  Text(
                                    widget.placeholder!,
                                    style: placeholderStyle,
                                  ),
                                child!,
                              ],
                            ),
                        child: EditableText(
                          controller: widget.controller,
                          focusNode: widget.focusNode,
                          style: textStyle,
                          cursorColor: caret,
                          backgroundCursorColor: res.textFillColorDisabled,
                          selectionColor: theme.accent.normal,
                          obscureText: widget.obscure,
                          readOnly: !widget.enabled,
                          autofocus: widget.autofocus,
                          maxLines: widget.obscure ? 1 : widget.maxLines,
                          enableInteractiveSelection: widget.selectable,
                          onChanged: widget.onChanged,
                          onSubmitted: widget.onSubmitted,
                          // No selection toolbar yet: the Fluent text
                          // commands surface is a flyout, and this skin has
                          // no overlay facet to host one - the same
                          // registered deviation the blueprint carries as
                          // D4. Selection itself still works.
                          contextMenuBuilder: null,
                        ),
                      ),
                    ),
                  ),
                  if (widget.trailing != null) widget.trailing!,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Escape empties a box that has something in it, and means what it always
/// meant otherwise.
///
/// The forwarding is the load-bearing part, and it is the blueprint's
/// arrangement adopted for the same reason: `EditableText` forwards an
/// unconsumed Escape as a `DismissIntent`, and `Actions` stops its walk at
/// the first scope that maps the intent whether or not that action fires -
/// so this action must exist even when the box is empty, and must hand the
/// intent on from the STATE's context (above its own `Actions` widget) so
/// an enclosing dialog's Escape still works. `maybeInvoke` rather than
/// `invoke`, because a box outside any dismiss scope is a legal place for
/// Escape to mean nothing.
final class _ClearOnEscape extends Action<DismissIntent> {
  _ClearOnEscape(this._box);

  final _FluentTextBoxState _box;

  @override
  Object? invoke(DismissIntent intent) {
    if (_box._canClearOnEscape) {
      _box._clear();
      return null;
    }
    return Actions.maybeInvoke<DismissIntent>(_box.context, intent);
  }
}

/// One in-field affordance: a compact subtle pressable at the end of the
/// box, the slot WinUI gives a TextBox's clear and reveal buttons
/// (`TextBox.suffix` in the reference's own examples). The subtle ladder is
/// the icon button's (buttons/icon_button.dart:116-130); the mark itself
/// waits on the Fluent glyph table, with the slot held at the compact glyph
/// extent so the box never changes shape when the table lands.
final class FluentFieldAffordance extends StatelessWidget {
  /// Builds one affordance.
  const FluentFieldAffordance({
    super.key,
    required this.semanticsLabel,
    required this.onPressed,
    this.tooltip,
  });

  /// The accessible name - a mark-only control has to name itself.
  final String semanticsLabel;

  /// What it does. Null disables it without removing it, so the field does
  /// not change shape as the action becomes available.
  final VoidCallback? onPressed;

  /// The longer explanation, announced until the overlay facet exists.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentResources res = theme.resources;
    return Semantics(
      button: true,
      tooltip: tooltip,
      child: FluentPressable(
        onPressed: onPressed,
        semanticsLabel: semanticsLabel,
        builder: (BuildContext context, Set<WidgetState> states) {
          final Color fill = states.contains(WidgetState.disabled)
              ? res.subtleFillColorDisabled
              : states.contains(WidgetState.pressed)
              ? res.subtleFillColorTertiary
              : states.contains(WidgetState.hovered)
              ? res.subtleFillColorSecondary
              : res.subtleFillColorTransparent;
          return AnimatedContainer(
            duration: FluentMotion.faster,
            curve: FluentMotion.curve,
            // Touching-distance margins (FluentMetrics.spaceXS) around the
            // affordance, at the control corner.
            margin: const EdgeInsetsDirectional.only(
              end: FluentMetrics.spaceXS,
            ),
            padding: const EdgeInsets.all(FluentMetrics.spaceXS),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(
                FluentGeometry.controlCornerRadius,
              ),
            ),
            // The compact glyph slot (FluentMetrics.glyphCompact), reserved
            // for the pending glyph table.
            child: SizedBox.square(dimension: FluentMetrics.glyphCompact),
          );
        },
      ),
    );
  }
}
