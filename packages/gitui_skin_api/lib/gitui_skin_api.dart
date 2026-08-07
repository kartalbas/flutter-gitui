/// The skin contract: the one package every skin implements and the
/// application depends on.
///
/// **The spine rule, from which everything else follows.** No member of this
/// contract returns a `Color`, a length, an `EdgeInsets`, a `TextStyle`, a
/// `ShapeBorder`, a `Duration` or an `IconData`. Every member returns a
/// `Widget`. When there is no value to name, application code cannot hold one -
/// and that is what makes the blueprint skin a falsifier rather than a
/// decoration.
///
/// **What the widgets-only import proves, and what it does not.** Every
/// library in this package imports `package:flutter/widgets.dart` and nothing
/// else from Flutter, and the isolation gate
/// (`test/dependency_isolation_gate_test.dart`) holds it there. That closes one
/// hole exactly: a *Material-named* type - `ThemeExtension`, `InputBorder`,
/// `PopupMenuEntry`, `ButtonStyle`, `Icons`, `Colors` - cannot be named here,
/// because it does not resolve.
///
/// It does NOT prove the spine rule, and saying otherwise would be the most
/// expensive kind of comfortable error. `package:flutter/widgets.dart` exports
/// `Color` (via `dart:ui`), `EdgeInsets`, `TextStyle`, `ShapeBorder`,
/// `IconData`, `BoxDecoration`, `BorderRadius`, `Curve`, and the whole
/// `WidgetState` family; `Duration` is `dart:core`. A contributor adding
/// `final Color tint;` to a spec would change no import, and `flutter analyze`,
/// the isolation gate and `custom_lint` would all stay green.
///
/// So the spine rule is enforced by a rule written for it:
/// `no_value_in_contract` (`lint_rules/flutter_gitui_lint`) fails on any
/// declaration in this package whose resolved type is one of the values the
/// rule bans, and `no_widget_in_contract` fails on any `Widget`-typed
/// parameter that is not a [ContentPort]. Both run in the blocking
/// `dart run custom_lint` step. The import ban stays, because it is still the
/// cheapest guard against the Material-named half of the problem - it is just
/// no longer asked to carry a claim it cannot support.
///
/// **Three declared latitudes**, each recorded rather than hidden:
///
///  * `SkinRootClaims` carries three values - localisation delegates, a scroll
///    behaviour and a window-chrome enum - because Flutter plumbing requires
///    them at the single application root. A lint confines every read to
///    `lib/main.dart`.
///  * The overlay members return a `Future`, because pushing a route is an
///    asynchronous question rather than a widget.
///  * `overlays.notify` returns an opaque `NoticeHandle`, because the
///    application already dismisses and replaces its own notices today.
///
/// **Fifty-five members across seven facets**: chrome 4, controls 15,
/// surfaces 19, type 3, layout 8, overlays 4, motion 2.
///
/// The design is `docs/SKIN-CONTRACT.md`; the settled member list is
/// `docs/SKIN-CONTRACT-MEMBERS.md`.
library;

export 'src/content_port.dart';
export 'src/facets/skin_chrome.dart';
export 'src/facets/skin_controls.dart';
export 'src/facets/skin_layout.dart';
export 'src/facets/skin_motion.dart';
export 'src/facets/skin_overlays.dart';
export 'src/facets/skin_surfaces.dart';
export 'src/facets/skin_type.dart';
export 'src/fields.dart';
export 'src/icon_role.dart';
export 'src/skin.dart';
export 'src/skin_registry.dart';
export 'src/specs/chrome_specs.dart';
export 'src/specs/control_specs.dart';
export 'src/specs/field_spec.dart';
export 'src/specs/layout_specs.dart';
export 'src/specs/overlay_specs.dart';
export 'src/specs/surface_specs.dart';
export 'src/specs/toolbar_specs.dart';
export 'src/specs/type_specs.dart';
export 'src/vocabulary.dart';
