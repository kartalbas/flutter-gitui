// The skin contract the frozen components dispatch to.
//
// This is the measurement instrument, not a proposal for #249's final API.
// Each method takes the FROZEN WIDGET ITSELF, so a skin sees exactly the
// public signature that exists today and nothing more. Anything a skin cannot
// express from that object is, by construction, a signature problem rather
// than an implementation problem - which is the question the spike exists to
// answer.
//
// Deliberate design choices, each load-bearing:
//
//  * `Skin.maybeOf` returns null when no skin is installed, so a frozen
//    component with its dispatch line still renders its original body. That
//    keeps the dispatch line a strict addition and lets the lab show the
//    unskinned original next to the three skins.
//  * The dialog seam is split into `dialog()` (the surface) and `showDialog()`
//    (the route, barrier and metrics), because the day-one probe showed the
//    route is where per-language behaviour actually lives - a Cupertino dialog
//    is a `CupertinoDialogRoute`, a Fluent dialog a `FluentDialogRoute`, and
//    neither is reachable from the widget alone.
//  * `localizationsDelegates` exists because the day-one probe showed
//    `fluent.showDialog` hard-asserts `FluentLocalizations`. A skin therefore
//    has to contribute delegates to the ONE app root.
library;

import 'package:flutter/widgets.dart';

import 'frozen/frozen_app_shell.dart';
import 'frozen/frozen_base_button.dart';
import 'frozen/frozen_base_dialog.dart';
import 'frozen/frozen_base_filter_chip.dart';
import 'frozen/frozen_base_text_field.dart';

/// Everything the frozen [FrozenBaseTextField] state holds that a skin needs
/// but the widget does not expose.
///
/// FINDING (recorded, not silently fixed): the text field's public signature is
/// insufficient on its own. `showClearButton`, `showPasswordToggle` and
/// `initialValue` are *behaviours* whose realisation lives in private State
/// (`_controller`, `_obscureText`, `_hasText`, `_clearText`,
/// `_togglePasswordVisibility`). A skin that renders the field with a different
/// library's widget must re-implement all of it or receive it. This slot is the
/// "receive it" option, and it is the reason the dispatch line in the frozen
/// text field is the longest of the five.
class TextFieldSlot {
  const TextFieldSlot({
    required this.widget,
    required this.controller,
    required this.obscureText,
    required this.hasText,
    required this.clearText,
    required this.togglePasswordVisibility,
  });

  final FrozenBaseTextField widget;
  final TextEditingController controller;
  final bool obscureText;
  final bool hasText;
  final VoidCallback clearText;
  final VoidCallback togglePasswordVisibility;
}

/// A design language, delegating to that language's canonical widgets.
abstract class Skin {
  const Skin();

  /// 'material' | 'cupertino' | 'fluent'
  String get id;

  /// Human-readable name for the lab's picker.
  String get label;

  /// Delegates this skin's app-root widget installs. See the class doc.
  Iterable<LocalizationsDelegate<Object?>> get localizationsDelegates =>
      const <LocalizationsDelegate<Object?>>[];

  /// Wraps [child] in whatever inherited theme this skin's widgets require.
  /// Applied at the page root AND re-applied inside every overlay route,
  /// because a route is a descendant of the Navigator, not of the page.
  Widget wrapTheme(BuildContext context, Widget child);

  Widget button(FrozenBaseButton widget);

  Widget iconButton(FrozenBaseIconButton widget);

  Widget textField(TextFieldSlot slot);

  Widget dialog(FrozenBaseDialog widget);

  Future<T?> showDialog<T>(BuildContext context, FrozenBaseDialog dialog);

  Widget shell(FrozenAppShell widget);

  Widget filterChip(FrozenBaseFilterChip widget);

  /// The pattern seam, not a widget seam. See
  /// [FrozenChoiceChipGroup]: neither Cupertino nor Fluent has a single-choice
  /// chip, and the HIG answer to a row of them is ONE segmented control, so a
  /// per-widget seam cannot express it at all.
  Widget choiceChipGroup(FrozenChoiceChipGroup widget);

  static Skin? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SkinScope>()?.skin;
}

/// Installs a [Skin] for the subtree below it.
class SkinScope extends InheritedWidget {
  const SkinScope({super.key, required this.skin, required super.child});

  final Skin skin;

  @override
  bool updateShouldNotify(SkinScope oldWidget) => oldWidget.skin != skin;
}
