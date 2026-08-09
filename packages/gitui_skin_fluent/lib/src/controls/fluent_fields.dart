/// The Fluent field family: `textField`, `dateField` and `suggestField`,
/// each a [FluentTextBox] under the InfoLabel arrangement.
///
/// WinUI names a field ABOVE it, not inside it: the label is body text with
/// a 4 epx gap to the control (fluent_ui@4.16.1
/// lib/src/controls/utils/info_label.dart:52,63), which is why a Fluent
/// form never floats a label into its border the way Material does. Helper
/// and error land BELOW the control the way the reference's form row lays
/// them (form/form_row.dart:53-69): the error 2 epx under the box, in the
/// red accent brush at a raised weight - `Colors.red.defaultBrushFor`
/// (form_row.dart:64), the same brush `FluentInk.invalidBrush` carries -
/// and the helper in the caption step and secondary ink, the "smallest
/// style for supplementary information" (styles/typography.dart:74-78).
library;

import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../fluent_geometry.dart';
import '../fluent_ink.dart';
import '../fluent_motion.dart';
import '../fluent_resources.dart';
import '../fluent_theme.dart';
import '../fluent_typography.dart';
import 'fluent_pressable.dart';
import 'fluent_text_box.dart';

/// The label-above / message-below arrangement shared by every field.
final class FluentFieldChrome extends StatelessWidget {
  /// Wraps [child] with the field's words.
  const FluentFieldChrome({
    super.key,
    required this.label,
    required this.enabled,
    required this.child,
    this.helper,
    this.error,
  });

  /// What the field is asking for. An empty label renders no line rather
  /// than an empty one - a search box inside an overlay names itself with
  /// its hint.
  final String label;

  /// Whether the field may be answered right now; a disabled field's label
  /// dims with it.
  final bool enabled;

  /// The standing note about what makes an answer acceptable.
  final String? helper;

  /// The one message the field objects with right now, already merged by
  /// `SkinFormFieldHost`.
  final String? error;

  /// The control being named.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final FluentResources res = FluentTheme.of(context).resources;
    final Brightness brightness = FluentTheme.of(context).brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (label.isNotEmpty)
          Padding(
            // InfoLabel: body text 4 epx above its child
            // (info_label.dart:52,63).
            padding: const EdgeInsetsDirectional.only(bottom: 4),
            child: Text(
              label,
              style: FluentTypeResolution.styleOf(context, TextRole.body)
                  .copyWith(
                    color: enabled
                        ? res.textFillColorPrimary
                        : res.textFillColorDisabled,
                  ),
            ),
          ),
        child,
        if (helper != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 2),
            child: Text(
              helper!,
              style: FluentTypeResolution.styleOf(
                context,
                TextRole.detail,
              ).copyWith(color: res.textFillColorSecondary),
            ),
          ),
        if (error != null)
          Padding(
            // form_row.dart:60 (margin top 2), :64 (the red brush), :66
            // (FontWeight.w500).
            padding: const EdgeInsetsDirectional.only(top: 2),
            child: Text(
              error!,
              style: FluentTypeResolution.styleOf(context, TextRole.detail)
                  .copyWith(
                    color: FluentInk.invalidBrush(brightness),
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
      ],
    );
  }
}

/// The Fluent answer to `SkinControls.textField`.
///
/// The spec arrives already resolved by `SkinFormFieldHost`, so `error` is
/// the one message to show and `onChanged` already reports to the form.
/// `FieldSpec.leading` waits on the Fluent glyph table (the registered gap
/// `FluentButton` documents); the three affordances render as
/// [FluentFieldAffordance] slots whose BEHAVIOUR is complete - clear
/// empties and reports, reveal flips the hiding, an action fires - with
/// their marks pending the same table.
final class FluentTextField extends StatefulWidget {
  /// Draws [spec] with [handles] in Fluent.
  const FluentTextField({super.key, required this.spec, required this.handles});

  /// What the application declared, resolved by the host.
  final FieldSpec spec;

  /// The application's live handles.
  final FieldHandles handles;

  @override
  State<FluentTextField> createState() => _FluentTextFieldState();
}

class _FluentTextFieldState extends State<FluentTextField> {
  late final TextEditingController _controller =
      widget.handles.controller ??
      TextEditingController(text: widget.handles.startingText);
  late final FocusNode _focus = widget.handles.focusNode ?? FocusNode();

  /// Whether the user has asked to see a hidden answer.
  bool _revealed = false;

  @override
  void dispose() {
    if (widget.handles.controller == null) _controller.dispose();
    if (widget.handles.focusNode == null) _focus.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.spec.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final FieldSpec spec = widget.spec;
    final bool obscure = spec.purpose == FieldPurpose.password && !_revealed;

    return FluentFieldChrome(
      label: spec.label,
      enabled: spec.enabled,
      helper: spec.helper,
      error: spec.error,
      child: FluentTextBox(
        controller: _controller,
        focusNode: _focus,
        enabled: spec.enabled,
        placeholder: spec.hint,
        obscure: obscure,
        maxLines: spec.maxLines,
        autofocus: spec.autofocus,
        selectable: spec.selectable,
        escapeClears: spec.escapeClears,
        onChanged: spec.onChanged,
        onSubmitted: spec.onSubmitted,
        trailing: _affordance(spec),
      ),
    );
  }

  Widget? _affordance(FieldSpec spec) => switch (spec.suffix) {
    null => null,
    FieldClearAffordance() => ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (BuildContext context, TextEditingValue value, Widget? child) =>
          value.text.isEmpty
          // The clear affordance appears only while there is something
          // to clear, which is also WinUI's TextBox behaviour.
          ? const SizedBox.shrink()
          : FluentFieldAffordance(
              semanticsLabel: 'clear',
              onPressed: spec.enabled ? _clear : null,
            ),
    ),
    FieldRevealAffordance() => FluentFieldAffordance(
      semanticsLabel: _revealed ? 'hide' : 'reveal',
      onPressed: spec.enabled
          ? () => setState(() => _revealed = !_revealed)
          : null,
    ),
    FieldActionAffordance(
      :final String tooltip,
      :final VoidCallback? onPressed,
    ) =>
      FluentFieldAffordance(
        semanticsLabel: tooltip,
        tooltip: tooltip,
        onPressed: spec.enabled ? onPressed : null,
      ),
  };
}

/// The Fluent answer to `SkinControls.dateField`.
///
/// WinUI's canonical moment-picker is a flyout (`DatePicker`), and a flyout
/// needs the overlay facet this skin does not have yet - so until it lands,
/// the moment is TYPED in the one date form that is not a locale decision,
/// inside the same TextBox shell every other field wears. The behaviour is
/// the contract's: `first` and `last` are enforced rather than displayed -
/// a moment outside the range is never reported - and an empty field is a
/// real answer. The flyout presentation is a registered gap of this slice,
/// not a decision.
final class FluentDateField extends StatefulWidget {
  /// Draws [spec] with [handles] in Fluent.
  const FluentDateField({super.key, required this.spec, required this.handles});

  /// What the application declared.
  final DateFieldSpec spec;

  /// The application's live handles.
  final FieldHandles handles;

  @override
  State<FluentDateField> createState() => _FluentDateFieldState();
}

class _FluentDateFieldState extends State<FluentDateField> {
  late final TextEditingController _controller =
      widget.handles.controller ??
      TextEditingController(
        text:
            widget.handles.initialValue ??
            _isoOf(widget.spec.value, widget.spec.precision),
      );
  late final FocusNode _focus = widget.handles.focusNode ?? FocusNode();

  /// What the field last objected to, or null while it objects to nothing.
  String? _objection;

  @override
  void dispose() {
    if (widget.handles.controller == null) _controller.dispose();
    if (widget.handles.focusNode == null) _focus.dispose();
    super.dispose();
  }

  /// Reports a moment only when the text names one the application allows.
  ///
  /// Silence while the text is half-typed is deliberate: `2026-0` is not a
  /// moment, and reporting it would invent an answer. The range compares at
  /// the field's precision as ISO strings, so a `DateTime.utc` boundary and
  /// a typed local midnight cannot disagree about the boundary day - the
  /// same repair the blueprint's date field documents.
  void _report(String text) {
    if (text.trim().isEmpty) {
      setState(() => _objection = null);
      widget.spec.onChanged(null);
      return;
    }
    final DateTime? parsed = DateTime.tryParse(text.trim());
    if (parsed == null) {
      setState(() => _objection = 'unreadable');
      return;
    }
    final DateFieldSpec spec = widget.spec;
    final String typed = _isoOf(parsed, spec.precision);
    if (spec.first != null &&
        typed.compareTo(_isoOf(spec.first, spec.precision)) < 0) {
      setState(
        () => _objection = 'before ${_isoOf(spec.first, spec.precision)}',
      );
      return;
    }
    if (spec.last != null &&
        typed.compareTo(_isoOf(spec.last, spec.precision)) > 0) {
      setState(() => _objection = 'after ${_isoOf(spec.last, spec.precision)}');
      return;
    }
    setState(() => _objection = null);
    spec.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final DateFieldSpec spec = widget.spec;
    return FluentFieldChrome(
      label: spec.label,
      enabled: spec.enabled,
      error: _objection,
      child: FluentTextBox(
        controller: _controller,
        focusNode: _focus,
        enabled: spec.enabled,
        placeholder: spec.hint ?? _formatOf(spec.precision),
        onChanged: _report,
        onSubmitted: _report,
      ),
    );
  }
}

/// How much of the ISO form the precision asks for, as the placeholder a
/// box with no hint shows.
String _formatOf(DatePrecision precision) => switch (precision) {
  DatePrecision.date => 'yyyy-mm-dd',
  DatePrecision.dateTime => 'yyyy-mm-ddThh:mm',
};

/// A moment in the unambiguous form, truncated to the precision asked for.
String _isoOf(DateTime? value, DatePrecision precision) {
  if (value == null) return '';
  final String iso = value.toIso8601String();
  return switch (precision) {
    DatePrecision.date => iso.substring(0, 10),
    DatePrecision.dateTime => iso.substring(0, 16),
  };
}

/// The Fluent answer to `SkinControls.suggestField`.
///
/// The WinUI AutoSuggestBox is a TextBox whose suggestion list drops in a
/// flyout; the box is drawn here exactly, and the LIST renders in place
/// beneath it until the overlay facet lands - the same registered gap the
/// date field carries, reported rather than hidden. Each suggestion is a
/// row on the subtle ladder, its own focusable control, so the list stays
/// keyboard-reachable without a roving-highlight idiom of this skin's own
/// invention.
final class FluentSuggestField<T> extends StatefulWidget {
  /// Draws [spec] with [handles] in Fluent.
  const FluentSuggestField({
    super.key,
    required this.spec,
    required this.handles,
  });

  /// What the application declared.
  final SuggestFieldSpec<T> spec;

  /// The application's live handles.
  final FieldHandles handles;

  @override
  State<FluentSuggestField<T>> createState() => _FluentSuggestFieldState<T>();
}

class _FluentSuggestFieldState<T> extends State<FluentSuggestField<T>> {
  late final TextEditingController _controller =
      widget.handles.controller ??
      TextEditingController(text: widget.handles.startingText);
  late final FocusNode _focus = widget.handles.focusNode ?? FocusNode();

  @override
  void dispose() {
    if (widget.handles.controller == null) _controller.dispose();
    if (widget.handles.focusNode == null) _focus.dispose();
    super.dispose();
  }

  String get _query => _controller.text.trim();

  List<SuggestItem<T>> get _matches {
    if (_query.length < widget.spec.minQueryLength) {
      return <SuggestItem<T>>[];
    }
    final String needle = _query.toLowerCase();
    return widget.spec.items
        .where(
          (SuggestItem<T> item) => item.label.toLowerCase().contains(needle),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final SuggestFieldSpec<T> spec = widget.spec;
    final FluentResources res = FluentTheme.of(context).resources;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FluentFieldChrome(
          label: spec.label,
          enabled: spec.enabled,
          child: FluentTextBox(
            controller: _controller,
            focusNode: _focus,
            enabled: spec.enabled,
            // The combo-box sentence while nothing is chosen, else the
            // search sentence: the AutoSuggestBox IS its own search box, so
            // the two statements the contract carries collapse here the way
            // the spec's own doc predicts a combo-like control collapses
            // them.
            placeholder: spec.value == null
                ? (spec.placeholder ?? spec.hint)
                : spec.hint,
            escapeClears: true,
            onChanged: (String text) {
              setState(() {});
              spec.onQueryChanged?.call(text);
            },
          ),
        ),
        if (spec.enabled) ..._suggestions(context, res, spec),
      ],
    );
  }

  List<Widget> _suggestions(
    BuildContext context,
    FluentResources res,
    SuggestFieldSpec<T> spec,
  ) {
    final List<SuggestItem<T>> matches = _matches;
    if (matches.isEmpty) {
      if (spec.emptyLabel == null || _query.length < spec.minQueryLength) {
        return const <Widget>[];
      }
      return <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 2),
          child: Text(
            spec.emptyLabel!,
            style: FluentTypeResolution.styleOf(
              context,
              TextRole.detail,
            ).copyWith(color: res.textFillColorSecondary),
          ),
        ),
      ];
    }
    return <Widget>[
      for (final SuggestItem<T> item in matches)
        _SuggestRow<T>(
          item: item,
          selected: item.value == spec.value,
          onSelected: () => spec.onSelected(item.value),
        ),
    ];
  }
}

/// One suggestion row: the subtle ladder under body text, the selected row
/// resting on the hover fill the way a WinUI list marks the chosen item
/// with a standing subtle fill (surfaces/list_tile.dart's selected tile).
final class _SuggestRow<T> extends StatelessWidget {
  const _SuggestRow({
    required this.item,
    required this.selected,
    required this.onSelected,
  });

  final SuggestItem<T> item;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final FluentResources res = FluentTheme.of(context).resources;
    return Semantics(
      selected: selected,
      child: FluentPressable(
        onPressed: onSelected,
        semanticsLabel: item.label,
        builder: (BuildContext context, Set<WidgetState> states) {
          final Color fill = states.contains(WidgetState.pressed)
              ? res.subtleFillColorTertiary
              : states.contains(WidgetState.hovered) || selected
              ? res.subtleFillColorSecondary
              : res.subtleFillColorTransparent;
          return AnimatedContainer(
            duration: FluentMotion.faster,
            curve: FluentMotion.curve,
            width: double.infinity,
            // The reference's dense list rhythm: 6 vertical, 12 at the end
            // (surfaces/list_tile.dart:8-12).
            padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 12, 6),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(
                FluentGeometry.controlCornerRadius,
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    item.label,
                    overflow: TextOverflow.ellipsis,
                    style: FluentTypeResolution.styleOf(
                      context,
                      TextRole.body,
                    ).copyWith(color: res.textFillColorPrimary),
                  ),
                ),
                if (item.detail != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8),
                    child: Text(
                      item.detail!,
                      overflow: TextOverflow.ellipsis,
                      style: FluentTypeResolution.styleOf(
                        context,
                        TextRole.detail,
                      ).copyWith(color: res.textFillColorSecondary),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
