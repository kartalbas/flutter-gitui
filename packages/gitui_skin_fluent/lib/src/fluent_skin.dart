import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import 'facets/fluent_chrome.dart';
import 'facets/fluent_controls.dart';
import 'facets/fluent_layout.dart';
import 'facets/fluent_motion_facet.dart';
import 'facets/fluent_overlays.dart';
import 'facets/fluent_surfaces.dart';
import 'facets/fluent_type.dart';

/// Fluent 2, behind the contract - drawn by this package, with no widget
/// library underneath.
///
/// The facets are getters over `const` value objects with no state of their
/// own, exactly as `BlueprintSkin` and `MaterialSkin` arrange them and for
/// the same reasons: the class stays `const`-constructible, and a facet can
/// be rewritten - or landed by a different slice - without anybody touching
/// this file beyond its one line.
///
/// **This skin is registered but not yet whole.** Every facet getter now
/// answers - chrome, controls, surfaces, layout, type and motion are
/// implemented, and the overlay facet carries the menu under both of its
/// anchors, the popover and the notice - but its dialog still throws an
/// [UnimplementedError] naming itself, from its own fence inside
/// [FluentOverlays]. Failing loudly is the only honest answer a partial
/// skin can give: a facet that quietly delegated to another design
/// language would be exactly the substitution failure the blueprint exists
/// to catch, pointed inward.
final class FluentSkin implements Skin {
  /// Builds the Fluent skin.
  const FluentSkin();

  /// How this skin is named in configuration and in a test
  /// parameterisation.
  @override
  String get id => 'fluent';

  /// The key for the name a user sees in the settings picker. A key rather
  /// than a string: the application owns its translations and a skin
  /// package must not ship its own.
  @override
  String get nameKey => 'skinFluent';

  /// False. This is a design language to ship, not an instrument.
  @override
  bool get isInstrument => false;

  /// What Fluent legitimately needs installed on the single application
  /// root: nothing, and that is a measured property of DRAWING the
  /// language rather than delegating to `fluent_ui`.
  ///
  /// The claims exist for skins built on widget libraries - the reference's
  /// `showDialog` checks its own localisations before it pushes, which is
  /// the exact case the `localizationsDelegates` claim was declared for.
  /// This package pushes no such dependency: its controls read only its
  /// own `FluentTheme` scope, installed by `chrome.wrapRoot`. The scroll
  /// behaviour and window chrome are the host's.
  @override
  SkinRootClaims get rootClaims => const SkinRootClaims(
    localizationsDelegates: <LocalizationsDelegate<Object?>>[],
    scrollBehavior: ScrollBehavior(),
    windowChrome: WindowChrome.hostDefault,
  );

  /// The frame: implemented. `wrapRoot` installs FluentTheme,
  /// FluentRequestScope and the page ground; shell, screen and
  /// dialogSurface are the NavigationView, PageHeader and ContentDialog
  /// idioms - the dialog deriving its action order from the roles, with
  /// the affirmative on the LEFT.
  @override
  SkinChrome get chrome => const FluentChrome();

  /// Things you operate: implemented, and behaviour-tested from the paint
  /// stream.
  @override
  SkinControls get controls => const FluentControls();

  /// Things that hold other things: implemented, drawn in Fluent's own
  /// depth grammar - layer fills plus 1 epx strokes, never tonal
  /// elevation - and behaviour-tested from the paint stream.
  @override
  SkinSurfaces get surfaces => const FluentSurfaces();

  /// Things you read: implemented over the ramp and resolution door in
  /// `fluent_typography.dart`. The glyph table stays the registered gap.
  @override
  SkinType get type => const FluentType();

  /// How things sit next to one another: implemented against the Fluent 2
  /// spacing ramp (`FluentSpacing`).
  @override
  SkinLayout get layout => const FluentLayout();

  /// How things change: implemented on the published WinUI duration set
  /// (`FluentMotion` / `FluentMotionDurations`).
  @override
  SkinMotion get motion => const FluentMotionFacet();

  /// Things that appear on top: the menu at a point and off an anchor, the
  /// popover and the InfoBar notice are implemented; only the dialog still
  /// refuses loudly, from its own fence inside [FluentOverlays] - so the
  /// facet getter no longer throws, and the remaining gap sits on the one
  /// member that is actually missing.
  @override
  SkinOverlays get overlays => const FluentOverlays();

  /// Adds Fluent to this build's list of design languages.
  ///
  /// The whole of what "plugin" can mean on a desktop AOT build: one
  /// pubspec dependency and one call from `lib/main.dart`. Nothing else in
  /// the application learns this package's name.
  static void register() => SkinRegistry.register(const FluentSkin());
}
