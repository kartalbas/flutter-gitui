import 'package:flutter/widgets.dart';

import '../fluent_motion.dart';

/// Builds a widget for the current set of interaction states.
typedef FluentStateBuilder =
    Widget Function(BuildContext context, Set<WidgetState> states);

/// The behaviour half of every Fluent control that answers a pointer: it
/// owns the interaction STATES and none of the drawing.
///
/// This is the reimplementation of the reference's `HoverButton`
/// (fluent_ui@4.16.1 lib/src/controls/utils/hover_button.dart), because that
/// class - not any colour table - is where the Fluent feel actually lives.
/// The behaviours carried over, each with its source:
///
///  * **Hover and focus arrive through [FocusableActionDetector]'s highlight
///    callbacks** (hover_button.dart:349-368), never through raw focus
///    state. That single decision is what makes the focus rectangle
///    keyboard-only: `onShowFocusHighlight` respects the framework's
///    interaction mode, so pointer interaction never reveals the rectangle -
///    WinUI's own rule ("Focus visuals are only rendered when keyboard input
///    is used", WinUI "Focus visuals" design page).
///  * **A press begins on pointer DOWN** (hover_button.dart:311-315), not on
///    tap completion - the control answers the finger, not the click.
///  * **Release keeps the pressed state for 100 ms**
///    (hover_button.dart:316-321, [FluentMotion.pressedRelease]) so a fast
///    click still shows its press.
///  * **Enter and Space activate through `ActivateIntent` /
///    `ButtonActivateIntent`** (hover_button.dart:228-235), and a keyboard
///    activation FLASHES the pressed state for [FluentMotion.fast]
///    (hover_button.dart:243-251) - a keyboard press is visible exactly like
///    a pointer press, only self-timed.
///  * **Disabled means no states at all**: the state set collapses to
///    `{disabled}` (hover_button.dart:295-303), so a hover over a disabled
///    control changes nothing - which the behaviour suite asserts.
final class FluentPressable extends StatefulWidget {
  /// Creates the behaviour shell around [builder]'s drawing.
  const FluentPressable({
    super.key,
    required this.builder,
    this.onPressed,
    this.semanticsLabel,
    this.focusNode,
    this.autofocus = false,
  });

  /// Draws the control for the current states. Called on every state change.
  final FluentStateBuilder builder;

  /// What pressing does. Null disables the control, exactly like the
  /// contract's `ButtonSpec.onPressed`.
  final VoidCallback? onPressed;

  /// The accessible name, merged over the child semantics.
  final String? semanticsLabel;

  /// The application's own handle on this control's focus, when it has one.
  final FocusNode? focusNode;

  /// Whether to take focus when first built.
  final bool autofocus;

  /// Whether the control answers input at all.
  bool get enabled => onPressed != null;

  @override
  State<FluentPressable> createState() => _FluentPressableState();
}

class _FluentPressableState extends State<FluentPressable> {
  bool _hovering = false;
  bool _pressing = false;
  bool _showFocus = false;

  late final Map<Type, Action<Intent>> _activationActions =
      <Type, Action<Intent>>{
        // Both intents, because the framework's default keyboard map sends
        // ButtonActivateIntent on some platforms and ActivateIntent on
        // others; the reference registers both (hover_button.dart:228-235).
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (ActivateIntent intent) => _activateFromKeyboard(),
        ),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
          onInvoke: (ButtonActivateIntent intent) => _activateFromKeyboard(),
        ),
      };

  Set<WidgetState> get _states {
    if (!widget.enabled) {
      return const <WidgetState>{WidgetState.disabled};
    }
    return <WidgetState>{
      if (_pressing) WidgetState.pressed,
      if (_hovering) WidgetState.hovered,
      if (_showFocus) WidgetState.focused,
    };
  }

  /// A keyboard activation: fire, and flash the pressed state for
  /// [FluentMotion.fast] so the press is seen (hover_button.dart:243-251).
  Future<void> _activateFromKeyboard() async {
    if (!widget.enabled) {
      return;
    }
    setState(() => _pressing = true);
    widget.onPressed?.call();
    await Future<void>.delayed(FluentMotion.fast);
    if (mounted) {
      setState(() => _pressing = false);
    }
  }

  Future<void> _releasePress() async {
    // Hold the pressed state through the release so a fast click still
    // shows it (hover_button.dart:316-321).
    await Future<void>.delayed(FluentMotion.pressedRelease);
    if (mounted) {
      setState(() => _pressing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? widget.onPressed : null,
      onTapDown: widget.enabled
          ? (TapDownDetails details) => setState(() => _pressing = true)
          : null,
      onTapUp: widget.enabled
          ? (TapUpDetails details) => _releasePress()
          : null,
      onTapCancel: widget.enabled
          ? () => setState(() => _pressing = false)
          : null,
      child: widget.builder(context, _states),
    );
    child = FocusableActionDetector(
      enabled: widget.enabled,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      actions: _activationActions,
      onShowFocusHighlight: (bool value) => setState(() => _showFocus = value),
      onShowHoverHighlight: (bool value) => setState(() => _hovering = value),
      child: child,
    );
    return MergeSemantics(
      child: Semantics(
        label: widget.semanticsLabel,
        enabled: widget.enabled,
        child: child,
      ),
    );
  }
}
