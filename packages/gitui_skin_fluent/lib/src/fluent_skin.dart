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
/// **Whole.** All seven facets are implemented and no member throws any
/// more: chrome, controls, surfaces, layout, type, motion, and - last to
/// land - the overlays, which carry the flyout under all three of its
/// anchors, the InfoBar notice and the ContentDialog route. The fences the
/// skin kept while it grew were the point of growing it that way: failing
/// loudly is the only honest answer a partial skin can give, where a facet
/// that quietly delegated to another design language would be exactly the
/// substitution failure the blueprint exists to catch, pointed inward.
///
/// What is still owed is not a member but a vocabulary: the [IconRole]
/// glyph table, whose 155 marks are a provenance question of their own and
/// whose slot every control here already holds open at its exact extent -
/// see [FluentButton]'s doc. Control anatomy (a check, a chevron, a dismiss
/// cross, a severity mark) is drawn as geometry and is NOT waiting on it.
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

  /// Things that appear on top: the flyout at a point, off an anchor and as
  /// a popover, the InfoBar notice, and the ContentDialog route around
  /// `chrome.dialogSurface`. No member throws.
  @override
  SkinOverlays get overlays => const FluentOverlays();

  /// Adds Fluent to this build's list of design languages.
  ///
  /// The whole of what "plugin" can mean on a desktop AOT build: one
  /// pubspec dependency and one call from `lib/main.dart`. Nothing else in
  /// the application learns this package's name.
  static void register() => SkinRegistry.register(const FluentSkin());
}
