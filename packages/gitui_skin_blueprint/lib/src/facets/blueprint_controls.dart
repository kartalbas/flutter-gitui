import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../blueprint_ink.dart';

/// Things you operate, naked.
///
/// Fifteen members, and every one of them is a box with an outline and a
/// handful of marks. What makes this facet an instrument rather than a
/// backdrop is the obligation in `docs/SKIN-CONTRACT-MEMBERS.md` §9: it
/// implements every member and **accepts every parameter**, and wherever a
/// parameter can be rendered distinguishably without becoming design, it is.
///
/// So [Emphasis] is whole pixels of outline, [ControlScale] is the smallest
/// box the control may be drawn in, a [Tone] is a mark beside the label, an
/// [IconRole] is its own name in brackets, and the three states of a toggle
/// are `[x]`, `[ ]` and `[-]`. Nothing here is a taste: every mark comes from
/// `BlueprintMarks` and every measurement from `BlueprintGeometry`, so a
/// member cannot quietly invent its own way of saying something another member
/// already says.
///
/// Two properties fall out of that, and they are the reason for the work:
///
///  * a parameter the application never varies shows up as a **constant** -
///    every button in the application drawn with the same outline weight is a
///    screen that never asked for a second [Emphasis];
///  * a parameter a skin drops shows up as a **difference from the
///    blueprint** - the Material skin rendering a `dangerSecondary` button
///    exactly like a plain one is visible the moment the same screen is
///    rendered under both.
///
/// **What this facet does NOT read, and why.** `FieldSpec.validator` is the
/// only parameter of the fifteen members that never reaches a widget here, and
/// it is not dropped: `SkinFormFieldHost` in the contract package consumes it
/// before the skin is called, precisely so that no skin has to remember to
/// register its field with the enclosing `Form`. The blueprint renders what the
/// host hands it - the merged `error` - which is the whole point of the host
/// existing.
final class BlueprintControls implements SkinControls {
  /// Takes the distance every rung resolves against.
  const BlueprintControls(this.distance);

  /// How far apart things are under this instrument.
  ///
  /// Nothing in this facet resolves it, and that is a finding rather than an
  /// oversight: no control spec in the contract carries a [Proximity] or an
  /// [Inset], so a control's internal spacing is the skin's alone and there is
  /// no rung for the sweep to vary. The field is here so that every facet is
  /// constructed identically and a facet that grows a rung later needs no
  /// change in `BlueprintSkin`.
  final BlueprintDistance distance;

  /// **What can the user do here, in words?**
  ///
  /// Reads all ten parameters: the outline's weight is the [Emphasis] and its
  /// dash is [Emphasis.link]; the smallest box it may occupy is the
  /// [ControlScale]; the [Tone], the leading mark, the trailing mark, the
  /// running state and the unavailability each add their own mark beside the
  /// label; `fillWidth` takes the whole offered width; and the tooltip is
  /// announced rather than drawn, because there is no naked tooltip to draw
  /// (see [describedBy]).
  ///
  /// The label is its own `Text` and every mark is a separate one, so a test
  /// that looks for `find.text('Delete')` still finds exactly that.
  @override
  Widget button(BuildContext context, ButtonSpec spec) {
    return BlueprintPressable(
      onPressed: spec.onPressed,
      semanticsLabel: spec.label,
      tooltip: spec.tooltip,
      child: BlueprintBox(
        stroke: BlueprintGeometry.stroke(context, spec.emphasis),
        dashed: BlueprintGeometry.dashed(spec.emphasis),
        minExtent: BlueprintGeometry.extent(context, spec.scale),
        fillWidth: spec.fillWidth,
        child: _line(<Widget>[
          if (spec.leading != null) _mark(BlueprintMarks.icon(spec.leading!)),
          _mark(BlueprintMarks.tone(spec.tone)),
          BlueprintText(spec.label),
          if (spec.trailing != null) _mark(BlueprintMarks.icon(spec.trailing!)),
          if (spec.isLoading) const BlueprintMark(BlueprintMarks.busy),
          if (spec.onPressed == null)
            const BlueprintMark(BlueprintMarks.disabled),
        ]),
      ),
    );
  }

  /// **What can the user do here, as a mark?**
  ///
  /// The mark is the role's own name in brackets, which is more
  /// distinguishable than any glyph set and makes a wrong mapping obvious.
  /// `selected` renders as three states and not two - chosen, not chosen, and
  /// "this control does not choose anything" - because the contract carries
  /// three and a skin that collapsed them would be dropping a fact.
  @override
  Widget iconButton(BuildContext context, IconButtonSpec spec) {
    return BlueprintPressable(
      onPressed: spec.onPressed,
      semanticsLabel: spec.tooltip,
      tooltip: spec.tooltip,
      selected: spec.selected,
      child: BlueprintBox(
        stroke: BlueprintGeometry.stroke(context, spec.emphasis),
        dashed: BlueprintGeometry.dashed(spec.emphasis),
        minExtent: BlueprintGeometry.extent(context, spec.scale),
        filled: spec.selected ?? false,
        child: _line(<Widget>[
          _mark(BlueprintMarks.icon(spec.icon)),
          _mark(BlueprintMarks.tone(spec.tone)),
          if (spec.selected != null)
            _mark(BlueprintMarks.selected(spec.selected!)),
          if (spec.badgeCount != null)
            _mark(BlueprintMarks.count(spec.badgeCount!)),
          if (spec.onPressed == null)
            const BlueprintMark(BlueprintMarks.disabled),
        ]),
      ),
    );
  }

  /// **What is the application asking the user to type?**
  ///
  /// Built on `EditableText`, which is the naked text primitive
  /// `package:flutter/widgets.dart` ships: it carries the whole of text entry -
  /// the caret, the platform's editing shortcuts, the input connection,
  /// selection by keyboard - and none of the appearance. Everything a design
  /// language would have decorated it with is a mark instead.
  ///
  /// The spec arrives already resolved by `SkinFormFieldHost`, so `error` is
  /// the one message to show and `onChanged` already reports to the form.
  @override
  Widget textField(
    BuildContext context,
    FieldSpec spec,
    FieldHandles handles,
  ) => _BlueprintTextField(spec: spec, handles: handles);

  /// **Which moment is the application asking the user to name?**
  ///
  /// A typed field rather than a calendar, and the reason is the same one that
  /// keeps 151 icons out of the blueprint: a calendar is a grid of weekday
  /// headings, month navigation and a today mark - a design, and a large one.
  /// The naked answer is the unambiguous ISO form, typed, which is also the
  /// only date format that is not a locale decision.
  ///
  /// [DatePrecision] decides how much of the ISO form is asked for, `first`
  /// and `last` are enforced rather than merely displayed - a moment outside
  /// the range is never reported to the application - and an empty field is a
  /// real answer, because `onChanged` takes a nullable moment.
  @override
  Widget dateField(
    BuildContext context,
    DateFieldSpec spec,
    FieldHandles handles,
  ) => _BlueprintDateField(spec: spec, handles: handles);

  /// **Which item of a closed list is the user narrowing towards?**
  ///
  /// The list is rendered in place, under the field, rather than in an overlay:
  /// an overlay is `overlays.presentPopover`'s job, and a control that reached
  /// for one would be borrowing another member's answer. Each suggestion is
  /// its own focusable control, so the list is reachable with Tab and
  /// confirmed with Enter without the blueprint inventing a roving-highlight
  /// idiom of its own.
  @override
  Widget suggestField<T>(
    BuildContext context,
    SuggestFieldSpec<T> spec,
    FieldHandles handles,
  ) => _BlueprintSuggestField<T>(spec: spec, handles: handles);

  /// **Is this fact true?**
  ///
  /// `[x]`, `[ ]` and `[-]`, exactly as §9.1 fixes them. The mixed state is
  /// not decoration: it is live in this application today, and a skin that
  /// could not show it would lose the partially selected folder.
  @override
  Widget checkbox(BuildContext context, ToggleSpec spec) =>
      _toggleMark(spec, BlueprintMarks.check(spec.value));

  /// **Is this setting on?**
  ///
  /// The same three states in parentheses rather than brackets. Two members
  /// that rendered identically would hide a mis-wired call site, and a
  /// checkbox and a switch are two different questions: one states a fact to
  /// be confirmed later, the other takes effect at once.
  @override
  Widget toggle(BuildContext context, ToggleSpec spec) =>
      _toggleMark(spec, BlueprintMarks.switching(spec.value));

  /// **Is this named fact true?**
  ///
  /// The whole row, at the full width it is offered, because that is what the
  /// member is: Material reaches for a different canonical widget for it,
  /// Fluent for a different constructor, and macOS has no label slot at all.
  @override
  Widget toggleRow(BuildContext context, ToggleRowSpec spec) {
    final bool operable = spec.enabled && spec.onChanged != null;
    return BlueprintPressable(
      onPressed: operable
          ? () => spec.onChanged!(_nextValue(spec.value))
          : null,
      semanticsLabel: spec.label,
      checked: spec.value,
      child: BlueprintBox(
        fillWidth: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _line(<Widget>[
              if (spec.leading != null)
                _mark(BlueprintMarks.icon(spec.leading!)),
              _mark(switch (spec.kind) {
                ToggleKind.check => BlueprintMarks.check(spec.value),
                ToggleKind.switching => BlueprintMarks.switching(spec.value),
              }),
              BlueprintText(spec.label),
              if (!operable) const BlueprintMark(BlueprintMarks.disabled),
            ]),
            if (spec.description != null) BlueprintText(spec.description!),
          ],
        ),
      ),
    );
  }

  /// **Where along this range is the user?**
  ///
  /// A track with a thumb for the pointer, two stepping controls for the
  /// keyboard, and the numbers themselves in a mark - because the one thing a
  /// naked slider must not do is make its own value unreadable. `divisions`
  /// quantises the value rather than drawing ticks: ticks are the skin's
  /// answer to the fact, and the fact is that a clone depth is a whole number
  /// of commits.
  @override
  Widget slider(BuildContext context, SliderSpec spec) =>
      _BlueprintSlider(spec: spec);

  /// **Which one of these is it?**
  ///
  /// The list opens in place rather than in a menu, for the same reason
  /// [suggestField] does: a menu belongs to `overlays.presentMenu`.
  @override
  Widget dropdown<T>(BuildContext context, DropdownSpec<T> spec) =>
      _BlueprintDropdown<T>(spec: spec);

  /// **Which one of these few is it?**
  ///
  /// The chosen option is washed and doubly outlined, which is the same pair
  /// of facts a roving list draws: the wash says "this one" and the second
  /// outline says "and it is here". `tooltip` is announced, because a group
  /// whose segments are `Aa`, `*` and `.*` is unreadable without it.
  @override
  Widget choiceGroup<T>(BuildContext context, ChoiceGroupSpec<T> spec) {
    return Semantics(
      label: spec.label,
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final ChoiceOption<T> option in spec.options)
            BlueprintPressable(
              onPressed: option.enabled
                  ? () => spec.onSelected(option.value)
                  : null,
              semanticsLabel: option.label,
              tooltip: option.tooltip,
              selected: option.value == spec.selected,
              child: BlueprintBox(
                minExtent: BlueprintGeometry.extent(context, spec.scale),
                filled: option.value == spec.selected,
                rings: option.value == spec.selected ? 2 : 1,
                child: _line(<Widget>[
                  _mark(BlueprintMarks.selected(option.value == spec.selected)),
                  if (option.icon != null)
                    _mark(BlueprintMarks.icon(option.icon!)),
                  BlueprintText(option.label),
                  if (!option.enabled)
                    const BlueprintMark(BlueprintMarks.disabled),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  /// **Is this condition on?**
  ///
  /// There is no "show the count" flag anywhere in this member, because the
  /// contract has none: a null count already means "do not say".
  @override
  Widget filterToggle(BuildContext context, FilterToggleSpec spec) {
    return BlueprintPressable(
      onPressed: spec.enabled ? () => spec.onSelected(!spec.selected) : null,
      semanticsLabel: spec.label,
      selected: spec.selected,
      child: BlueprintBox(
        filled: spec.selected,
        child: _line(<Widget>[
          _mark(BlueprintMarks.selected(spec.selected)),
          if (spec.icon != null) _mark(BlueprintMarks.icon(spec.icon!)),
          BlueprintText(spec.label),
          if (spec.count != null) _mark(BlueprintMarks.count(spec.count!)),
          if (!spec.enabled) const BlueprintMark(BlueprintMarks.disabled),
        ]),
      ),
    );
  }

  /// **Which of the skin's own colours does this object get?**
  ///
  /// The blueprint has no colours, so it offers its series as indices - the
  /// same indices `Tone.series(n)` renders as. The length is
  /// `BlueprintInk.seriesLength` and it is the skin's to declare: that is the
  /// entire reason this member exists, because once the palette AND its length
  /// belong to the skin there is no legal way for the application to enumerate
  /// the swatches itself.
  @override
  Widget seriesPicker(BuildContext context, SeriesPickerSpec spec) {
    return Semantics(
      label: spec.label,
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int index = 0; index < BlueprintInk.seriesLength; index++)
            BlueprintPressable(
              onPressed: () => spec.onSelected(index),
              semanticsLabel: '$index',
              selected: index == spec.selectedIndex,
              child: BlueprintBox(
                filled: index == spec.selectedIndex,
                rings: index == spec.selectedIndex ? 2 : 1,
                child: _mark(BlueprintMarks.tone(Tone.series(index))),
              ),
            ),
        ],
      ),
    );
  }

  /// **How far along is this, and how much room may saying so take?**
  ///
  /// `[####----]` inline and `(45%)` as a block. A null fraction is the case
  /// the languages disagree about most - one of them cannot draw an
  /// indeterminate bar at all - so the blueprint says so in as many characters
  /// as it says everything else: `[????????]`.
  @override
  Widget progress(
    BuildContext context, {
    double? fraction,
    required ProgressExtent extent,
  }) {
    final String readout = BlueprintMarks.progress(fraction, extent);
    return Semantics(
      value: readout,
      child: BlueprintBox(child: BlueprintMark(readout)),
    );
  }

  /// **What does this thing do, for someone who cannot tell by looking?**
  ///
  /// Announced, not drawn. `Tooltip` is a Material widget and there is no
  /// naked one; drawing a hovering panel would be both a design decision and
  /// an import this package may not make. The message is not lost - it reaches
  /// the semantics tree, which is where an explanation for someone who cannot
  /// see the control has to be anyway - and this is the same answer every
  /// `tooltip` parameter in this facet gets, for the same reason.
  ///
  /// The child is mounted through its port, which is what plants the boundary
  /// the attribution walk resumes at.
  @override
  Widget describedBy(
    BuildContext context, {
    required String message,
    required ContentPort child,
  }) => Semantics(tooltip: message, child: child.mount());

  /// The naked answer to both [checkbox] and [toggle]: one mark, one box.
  Widget _toggleMark(ToggleSpec spec, String mark) {
    final bool operable = spec.enabled && spec.onChanged != null;
    return BlueprintPressable(
      onPressed: operable
          ? () => spec.onChanged!(_nextValue(spec.value))
          : null,
      semanticsLabel: spec.label,
      checked: spec.value,
      child: BlueprintBox(
        child: _line(<Widget>[
          _mark(mark),
          if (!operable) const BlueprintMark(BlueprintMarks.disabled),
        ]),
      ),
    );
  }
}

/// What operating a three-state toggle produces.
///
/// The mixed state is never something the user can ASK for - it is what the
/// application reports when a folder is partly selected - so operating a mixed
/// control means "make it true", which is the gesture that resolves it.
bool _nextValue(bool? value) => value != true;

/// One mark.
Widget _mark(String text) => BlueprintMark(text);

/// Marks and words beside one another, with the empty marks dropped.
///
/// Dropping the empty ones matters: `Tone.neutral` is the default and renders
/// nothing, so a control at its defaults carries no marks at all and the marks
/// that ARE on screen all mean something.
///
/// A [Wrap] rather than a [Row], and the reason is that the instrument must not
/// fail on the application's own words. Every string in a line here is the
/// application's - a label, a helper, a validation message - and this
/// application ships in six languages, so a message that fits in English at
/// 300 logical pixels routinely does not in German. A min-size row overflows on
/// that, and an overflow paints the framework's yellow-and-black stripes, which
/// the chromatic census reads as an application leak that the application did
/// not cause and the zero-and-extremes sweep reads as a screen asserting
/// design. A wrap breaks the run to the next line instead, and a long single
/// string soft-wraps inside it, because a wrap hands each child its own
/// bounded width. Under unbounded width it behaves exactly like the row it
/// replaced, so nothing that used to lay out stops laying out.
Widget _line(List<Widget> parts) => Wrap(
  crossAxisAlignment: WrapCrossAlignment.center,
  children: <Widget>[
    for (final Widget part in parts)
      if (part is! BlueprintMark || part.text.isNotEmpty) part,
  ],
);

/// The one text-entry primitive, dressed in marks instead of a decoration.
class _BlueprintTextField extends StatefulWidget {
  const _BlueprintTextField({required this.spec, required this.handles});

  final FieldSpec spec;
  final FieldHandles handles;

  @override
  State<_BlueprintTextField> createState() => _BlueprintTextFieldState();
}

class _BlueprintTextFieldState extends State<_BlueprintTextField> {
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

  /// Whether Escape in this field means "empty it" rather than "leave".
  bool get canClearOnEscape =>
      widget.spec.escapeClears &&
      widget.spec.enabled &&
      _controller.text.isNotEmpty;

  /// Empties the field and tells the application, which is also what tells the
  /// hosting form.
  void clear() {
    _controller.clear();
    widget.spec.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final FieldSpec spec = widget.spec;
    // A hidden answer is a single line by definition, and `EditableText`
    // asserts as much. Stating it here rather than letting the assert fire
    // keeps a password field with a stale `maxLines` rendering instead of
    // crashing.
    final bool obscure = spec.purpose == FieldPurpose.password && !_revealed;
    final int lines = obscure ? 1 : spec.maxLines;

    return Actions(
      actions: <Type, Action<Intent>>{DismissIntent: _ClearOnEscape(this)},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          BlueprintText(spec.label),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: spec.enabled ? _focus.requestFocus : null,
            child: BlueprintBox(
              fillWidth: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (spec.leading != null)
                    _mark(BlueprintMarks.icon(spec.leading!)),
                  if (_purposeMark(spec.purpose).isNotEmpty)
                    _mark(_purposeMark(spec.purpose)),
                  Expanded(
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _controller,
                      builder: (BuildContext c, TextEditingValue value, _) =>
                          Stack(
                            children: <Widget>[
                              if (value.text.isEmpty && spec.hint != null)
                                BlueprintText(spec.hint!),
                              EditableText(
                                controller: _controller,
                                focusNode: _focus,
                                style: BlueprintInk.textStyle(c),
                                cursorColor: BlueprintInk.ink(context),
                                backgroundCursorColor: BlueprintInk.paper(
                                  context,
                                ),
                                selectionColor: BlueprintInk.wash(context, 0.3),
                                obscureText: obscure,
                                readOnly: !spec.enabled,
                                autofocus: spec.autofocus,
                                maxLines: lines,
                                enableInteractiveSelection: spec.selectable,
                                onChanged: spec.onChanged,
                                onSubmitted: spec.onSubmitted,
                                // Decision D4, registered as the blueprint's
                                // one deviation: no selection toolbar.
                                // `AdaptiveTextSelectionToolbar` is
                                // Material/Cupertino, and importing it would
                                // break the compile-time proof that this
                                // package needs neither. Selection itself
                                // still works.
                                contextMenuBuilder: null,
                              ),
                            ],
                          ),
                    ),
                  ),
                  if (spec.suffix != null) _affordance(context, spec.suffix!),
                  if (!spec.enabled)
                    const BlueprintMark(BlueprintMarks.disabled),
                ],
              ),
            ),
          ),
          if (spec.helper != null) BlueprintText(spec.helper!),
          if (spec.error != null)
            _line(<Widget>[
              _mark(BlueprintMarks.tone(Tone.danger)),
              BlueprintText(spec.error!),
            ]),
        ],
      ),
    );
  }

  /// The action that belongs to this field, drawn INSIDE it.
  ///
  /// A sealed set of three rather than an icon and a callback, because that is
  /// what lets a language reach for its own affordance where it has one. The
  /// blueprint has none, so all three render as marks - but they render as
  /// three DIFFERENT marks, so a skin that collapsed them would be visible.
  Widget _affordance(BuildContext context, FieldAffordance affordance) {
    return switch (affordance) {
      FieldClearAffordance() => BlueprintPressable(
        onPressed: widget.spec.enabled ? clear : null,
        semanticsLabel: 'clear',
        child: const BlueprintMark('[clear]'),
      ),
      FieldRevealAffordance() => BlueprintPressable(
        onPressed: widget.spec.enabled
            ? () => setState(() => _revealed = !_revealed)
            : null,
        semanticsLabel: _revealed ? 'hide' : 'reveal',
        child: BlueprintMark(_revealed ? '[hide]' : '[reveal]'),
      ),
      FieldActionAffordance(
        :final IconRole icon,
        :final String tooltip,
        :final VoidCallback? onPressed,
      ) =>
        BlueprintPressable(
          onPressed: widget.spec.enabled ? onPressed : null,
          semanticsLabel: tooltip,
          tooltip: tooltip,
          child: _line(<Widget>[
            _mark(BlueprintMarks.icon(icon)),
            if (onPressed == null) const BlueprintMark(BlueprintMarks.disabled),
          ]),
        ),
    };
  }
}

/// What KIND of asking this is, where that changes the canonical widget in a
/// design language.
///
/// Rendered because it is one of the parameters most likely to be dropped: a
/// skin that treats every field as a plain one loses nothing visible under
/// itself, and everything under comparison.
String _purposeMark(FieldPurpose purpose) => switch (purpose) {
  FieldPurpose.text => BlueprintMarks.none,
  FieldPurpose.search => '[search]',
  FieldPurpose.password => '[password]',
};

/// Escape empties a field that has something in it, and means what it always
/// meant otherwise.
///
/// The forwarding is the load-bearing part. `Actions` stops its walk at the
/// first scope that maps the intent, whether or not that action is enabled, so
/// a disabled action here would SWALLOW Escape and a dialog would stop
/// closing. Handing the intent on from the state's own context - which sits
/// above the `Actions` widget this action lives in - resumes the search at the
/// ancestor, which is exactly where the dialog's own Escape lives.
class _ClearOnEscape extends Action<DismissIntent> {
  _ClearOnEscape(this._field);

  final _BlueprintTextFieldState _field;

  @override
  Object? invoke(DismissIntent intent) {
    if (_field.canClearOnEscape) {
      _field.clear();
      return null;
    }
    return Actions.maybeInvoke<DismissIntent>(_field.context, intent);
  }
}

/// A moment, typed in the one date format that is not a design decision.
class _BlueprintDateField extends StatefulWidget {
  const _BlueprintDateField({required this.spec, required this.handles});

  final DateFieldSpec spec;
  final FieldHandles handles;

  @override
  State<_BlueprintDateField> createState() => _BlueprintDateFieldState();
}

class _BlueprintDateFieldState extends State<_BlueprintDateField> {
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
  /// Silence is deliberate while the text is half-typed: `2026-0` is not a
  /// moment, and telling the application about it would be inventing an
  /// answer the user did not give.
  void _report(String text) {
    if (text.trim().isEmpty) {
      setState(() => _objection = null);
      widget.spec.onChanged(null);
      return;
    }
    final DateTime? parsed = DateTime.tryParse(text.trim());
    if (parsed == null) {
      setState(() => _objection = '[unreadable]');
      return;
    }
    final DateFieldSpec spec = widget.spec;
    // Compared at the precision the field asked for rather than as two
    // instants. A typed `2026-06-01` is local midnight and a boundary the
    // application built with `DateTime.utc` is not, so an instant comparison
    // would reject the boundary day itself in half the world's offsets - which
    // is a bug in the naked field, not in the application that handed over the
    // range. Two ISO strings of the same shape compare chronologically.
    final String typed = _isoOf(parsed, spec.precision);
    if (spec.first != null &&
        typed.compareTo(_isoOf(spec.first, spec.precision)) < 0) {
      setState(() => _objection = '[before first]');
      return;
    }
    if (spec.last != null &&
        typed.compareTo(_isoOf(spec.last, spec.precision)) > 0) {
      setState(() => _objection = '[after last]');
      return;
    }
    setState(() => _objection = null);
    spec.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final DateFieldSpec spec = widget.spec;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        BlueprintText(spec.label),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: spec.enabled ? _focus.requestFocus : null,
          child: BlueprintBox(
            fillWidth: true,
            child: Row(
              children: <Widget>[
                _mark(_precisionMark(spec.precision)),
                Expanded(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (BuildContext c, TextEditingValue value, _) =>
                        Stack(
                          children: <Widget>[
                            if (value.text.isEmpty && spec.hint != null)
                              BlueprintText(spec.hint!),
                            EditableText(
                              controller: _controller,
                              focusNode: _focus,
                              style: BlueprintInk.textStyle(c),
                              cursorColor: BlueprintInk.ink(context),
                              backgroundCursorColor: BlueprintInk.paper(
                                context,
                              ),
                              selectionColor: BlueprintInk.wash(context, 0.3),
                              readOnly: !spec.enabled,
                              maxLines: 1,
                              onChanged: _report,
                              onSubmitted: _report,
                              contextMenuBuilder: null,
                            ),
                          ],
                        ),
                  ),
                ),
                if (spec.first != null || spec.last != null)
                  _mark(
                    '[${_isoOf(spec.first, spec.precision)}..'
                    '${_isoOf(spec.last, spec.precision)}]',
                  ),
                if (_objection != null) _mark(_objection!),
                if (!spec.enabled) const BlueprintMark(BlueprintMarks.disabled),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// How much of a moment is being asked for.
String _precisionMark(DatePrecision precision) => switch (precision) {
  DatePrecision.date => '[yyyy-mm-dd]',
  DatePrecision.dateTime => '[yyyy-mm-ddThh:mm]',
};

/// A moment in the one unambiguous form, truncated to the precision asked for.
///
/// ISO 8601 and never a localised format, because which order a date's parts
/// come in is a locale decision the application's own formatting owns - and
/// because a blueprint that guessed would be asserting a convention it has no
/// business asserting.
String _isoOf(DateTime? value, DatePrecision precision) {
  if (value == null) return '';
  final String iso = value.toIso8601String();
  return switch (precision) {
    DatePrecision.date => iso.substring(0, 10),
    DatePrecision.dateTime => iso.substring(0, 16),
  };
}

/// A field that narrows a closed list, with the list under it.
class _BlueprintSuggestField<T> extends StatefulWidget {
  const _BlueprintSuggestField({required this.spec, required this.handles});

  final SuggestFieldSpec<T> spec;
  final FieldHandles handles;

  @override
  State<_BlueprintSuggestField<T>> createState() =>
      _BlueprintSuggestFieldState<T>();
}

class _BlueprintSuggestFieldState<T> extends State<_BlueprintSuggestField<T>> {
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

  /// What the user has typed so far.
  String get _query => _controller.text.trim();

  /// The suggestions the query allows, or none at all while the query is too
  /// short to be worth suggesting from.
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

  /// What the current value is called, for the mark that reports it.
  String get _chosenLabel {
    for (final SuggestItem<T> item in widget.spec.items) {
      if (item.value == widget.spec.value) return item.label;
    }
    return '${widget.spec.value}';
  }

  @override
  Widget build(BuildContext context) {
    final SuggestFieldSpec<T> spec = widget.spec;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _line(<Widget>[
          BlueprintText(spec.label),
          if (spec.value != null) _mark('[= $_chosenLabel]'),
          if (spec.minQueryLength > 0) _mark('[min ${spec.minQueryLength}]'),
        ]),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: spec.enabled ? _focus.requestFocus : null,
          child: BlueprintBox(
            fillWidth: true,
            child: Row(
              children: <Widget>[
                if (spec.leading != null)
                  _mark(BlueprintMarks.icon(spec.leading!)),
                Expanded(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (BuildContext c, TextEditingValue value, _) =>
                        Stack(
                          children: <Widget>[
                            if (value.text.isEmpty && spec.hint != null)
                              BlueprintText(spec.hint!),
                            EditableText(
                              controller: _controller,
                              focusNode: _focus,
                              style: BlueprintInk.textStyle(c),
                              cursorColor: BlueprintInk.ink(context),
                              backgroundCursorColor: BlueprintInk.paper(
                                context,
                              ),
                              selectionColor: BlueprintInk.wash(context, 0.3),
                              readOnly: !spec.enabled,
                              maxLines: 1,
                              onChanged: (String text) {
                                setState(() {});
                                spec.onQueryChanged?.call(text);
                              },
                              contextMenuBuilder: null,
                            ),
                          ],
                        ),
                  ),
                ),
                if (!spec.enabled) const BlueprintMark(BlueprintMarks.disabled),
              ],
            ),
          ),
        ),
        if (spec.enabled) ..._suggestions(context, spec),
      ],
    );
  }

  /// The list, in place. Empty while nothing matches, unless the application
  /// gave words for that case.
  List<Widget> _suggestions(BuildContext context, SuggestFieldSpec<T> spec) {
    final List<SuggestItem<T>> matches = _matches;
    if (matches.isEmpty) {
      if (spec.emptyLabel == null) return const <Widget>[];
      return <Widget>[BlueprintBox(child: BlueprintText(spec.emptyLabel!))];
    }
    return <Widget>[
      for (final SuggestItem<T> item in matches)
        BlueprintPressable(
          onPressed: () => spec.onSelected(item.value),
          semanticsLabel: item.label,
          selected: item.value == spec.value,
          child: BlueprintBox(
            fillWidth: true,
            filled: item.value == spec.value,
            child: _line(<Widget>[
              _mark(BlueprintMarks.selected(item.value == spec.value)),
              if (item.icon != null) _mark(BlueprintMarks.icon(item.icon!)),
              BlueprintText(item.label),
              if (item.detail != null) BlueprintText(item.detail!),
            ]),
          ),
        ),
    ];
  }
}

/// A position along a range: a track for the pointer, two steps for the
/// keyboard, and the numbers in a mark.
class _BlueprintSlider extends StatelessWidget {
  const _BlueprintSlider({required this.spec});

  final SliderSpec spec;

  /// How high the naked track is drawn, in logical pixels.
  static const double _trackHeight = 8;

  /// Whether the user may move it at all.
  bool get _operable => spec.enabled && spec.onChanged != null;

  /// How far one keyboard step moves it.
  ///
  /// A division when the value has divisions, because then the steps ARE the
  /// values; a tenth of the range otherwise, which is the blueprint choosing a
  /// number for itself - legal inside a skin, and visible in the mark that
  /// reports the value. A range with no width and a division count of zero are
  /// both nonsense the application could still hand over, so the step never
  /// goes to zero and the arithmetic below never divides by it.
  double get _step {
    final int divisions = (spec.divisions ?? 0) > 0 ? spec.divisions! : 10;
    final double step = (spec.max - spec.min) / divisions;
    return step > 0 ? step : 1;
  }

  /// Reports [value], snapped to a division when there are divisions.
  void _report(double value, {required bool ended}) {
    final double clamped = value.clamp(spec.min, spec.max);
    final double snapped = (spec.divisions ?? 0) > 0
        ? spec.min + ((clamped - spec.min) / _step).round() * _step
        : clamped;
    spec.onChanged?.call(snapped);
    if (ended) spec.onChangeEnd?.call(snapped);
  }

  @override
  Widget build(BuildContext context) {
    final double span = spec.max - spec.min;
    final double fraction = span <= 0
        ? 0
        : ((spec.value - spec.min) / span).clamp(0, 1);
    return Semantics(
      slider: true,
      value: spec.valueLabel ?? '${spec.value}',
      enabled: _operable,
      child: BlueprintBox(
        child: Row(
          children: <Widget>[
            BlueprintPressable(
              onPressed: _operable
                  ? () => _report(spec.value - _step, ended: true)
                  : null,
              semanticsLabel: 'less',
              child: const BlueprintMark('[<]'),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext c, BoxConstraints constraints) =>
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: _operable
                          ? (DragUpdateDetails details) => _report(
                              spec.min +
                                  span *
                                      (details.localPosition.dx /
                                              constraints.maxWidth)
                                          .clamp(0, 1),
                              ended: false,
                            )
                          : null,
                      onHorizontalDragEnd: _operable
                          ? (DragEndDetails _) =>
                                _report(spec.value, ended: true)
                          : null,
                      child: SizedBox(
                        height: _trackHeight,
                        child: Stack(
                          children: <Widget>[
                            const BlueprintBox(child: SizedBox.expand()),
                            Align(
                              alignment: Alignment(fraction * 2 - 1, 0),
                              child: const SizedBox(
                                width: _trackHeight,
                                height: _trackHeight,
                                child: BlueprintBox(
                                  filled: true,
                                  child: SizedBox.expand(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ),
            ),
            BlueprintPressable(
              onPressed: _operable
                  ? () => _report(spec.value + _step, ended: true)
                  : null,
              semanticsLabel: 'more',
              child: const BlueprintMark('[>]'),
            ),
            _mark('[${spec.value} of ${spec.min}..${spec.max}]'),
            if (spec.divisions != null) _mark('[${spec.divisions} steps]'),
            if (spec.valueLabel != null) BlueprintText(spec.valueLabel!),
            if (!_operable) const BlueprintMark(BlueprintMarks.disabled),
          ],
        ),
      ),
    );
  }
}

/// One of a short closed list, chosen from a list that opens in place.
class _BlueprintDropdown<T> extends StatefulWidget {
  const _BlueprintDropdown({required this.spec});

  final DropdownSpec<T> spec;

  @override
  State<_BlueprintDropdown<T>> createState() => _BlueprintDropdownState<T>();
}

class _BlueprintDropdownState<T> extends State<_BlueprintDropdown<T>> {
  /// Whether the list is showing.
  bool _open = false;

  /// What the current value is called, or the hint while there is none.
  String get _shown {
    for (final DropdownOption<T> option in widget.spec.options) {
      if (option.value == widget.spec.value) return option.label;
    }
    return widget.spec.hint ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final DropdownSpec<T> spec = widget.spec;
    final bool operable = spec.enabled && spec.onChanged != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        BlueprintText(spec.label),
        BlueprintPressable(
          onPressed: operable ? () => setState(() => _open = !_open) : null,
          semanticsLabel: spec.label,
          focusNode: spec.focusNode,
          autofocus: spec.autofocus,
          child: BlueprintBox(
            fillWidth: spec.fillWidth,
            child: _line(<Widget>[
              if (spec.leading != null)
                _mark(BlueprintMarks.icon(spec.leading!)),
              BlueprintText(_shown),
              _mark(_open ? '[v]' : '[>]'),
              if (!operable) const BlueprintMark(BlueprintMarks.disabled),
            ]),
          ),
        ),
        if (_open)
          for (final DropdownOption<T> option in spec.options)
            BlueprintPressable(
              onPressed: option.enabled
                  ? () {
                      setState(() => _open = false);
                      spec.onChanged!(option.value);
                    }
                  : null,
              semanticsLabel: option.label,
              selected: option.value == spec.value,
              child: BlueprintBox(
                fillWidth: spec.fillWidth,
                filled: option.value == spec.value,
                child: _line(<Widget>[
                  _mark(BlueprintMarks.selected(option.value == spec.value)),
                  if (option.icon != null)
                    _mark(BlueprintMarks.icon(option.icon!)),
                  BlueprintText(option.label),
                  if (option.detail != null) BlueprintText(option.detail!),
                  if (!option.enabled)
                    const BlueprintMark(BlueprintMarks.disabled),
                ]),
              ),
            ),
      ],
    );
  }
}
