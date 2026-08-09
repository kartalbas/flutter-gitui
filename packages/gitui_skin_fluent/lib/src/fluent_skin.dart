import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import 'facets/fluent_controls.dart';

/// Fluent 2, behind the contract - drawn by this package, with no widget
/// library underneath.
///
/// The facets are getters over `const` value objects with no state of their
/// own, exactly as `BlueprintSkin` and `MaterialSkin` arrange them and for
/// the same reasons: the class stays `const`-constructible, and a facet can
/// be rewritten - or landed by a different slice - without anybody touching
/// this file beyond its one line.
///
/// **This skin is registered but not yet whole.** The controls facet is
/// implemented; the other six land with their own slices, and until each
/// does, its getter throws an [UnimplementedError] naming itself. Failing
/// loudly is the only honest answer a partial skin can give: a facet that
/// quietly delegated to another design language would be exactly the
/// substitution failure the blueprint exists to catch, pointed inward. The
/// application does not register this skin yet (nothing in `lib/` names
/// this package), so the throw is a fence for the assembling slice, not a
/// crash a user can reach.
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
  /// own `FluentTheme` scope, installed by `chrome.wrapRoot` when that
  /// facet lands. The scroll behaviour and window chrome are the host's.
  @override
  SkinRootClaims get rootClaims => const SkinRootClaims(
    localizationsDelegates: <LocalizationsDelegate<Object?>>[],
    scrollBehavior: ScrollBehavior(),
    windowChrome: WindowChrome.hostDefault,
  );

  /// Not yet: the frame is its own slice.
  @override
  SkinChrome get chrome => throw UnimplementedError(
    'The Fluent chrome facet is not implemented yet: wrapRoot must install '
    'FluentTheme, FluentRequestScope and the page ground; shell, screen and '
    'dialogSurface are the NavigationView, PageHeader and ContentDialog '
    'idioms. It lands as its own slice.',
  );

  /// Things you operate: implemented, and behaviour-tested from the paint
  /// stream.
  @override
  SkinControls get controls => const FluentControls();

  /// Not yet: containers are their own slice.
  @override
  SkinSurfaces get surfaces => throw UnimplementedError(
    'The Fluent surfaces facet is not implemented yet. The depth grammar it '
    'will draw with (layer fills plus 1px strokes, FluentInk.depth) is '
    'already in place.',
  );

  /// Not yet: reading is its own slice, though the ramp and the resolution
  /// door (`FluentTypeRamp`, `FluentTypeResolution`) are already in place.
  @override
  SkinType get type => throw UnimplementedError(
    'The Fluent type facet is not implemented yet. Its foundations - the '
    'Windows 11 type ramp and the single resolution door - are in '
    'fluent_typography.dart.',
  );

  /// Not yet: arrangement is its own slice, though the spacing ramp
  /// (`FluentSpacing`) is already in place.
  @override
  SkinLayout get layout => throw UnimplementedError(
    'The Fluent layout facet is not implemented yet. The Fluent 2 spacing '
    'ramp it will resolve Proximity and Inset against is in '
    'fluent_ink.dart (FluentSpacing).',
  );

  /// Not yet: change is its own slice, though the duration set
  /// (`FluentMotion`) is already in place.
  @override
  SkinMotion get motion => throw UnimplementedError(
    'The Fluent motion facet is not implemented yet. The published WinUI '
    'duration set it will answer with is in fluent_motion.dart.',
  );

  /// Not yet: what appears on top is its own slice, and it is the one the
  /// controls facet is waiting on for tooltips, pickers and flyout lists.
  @override
  SkinOverlays get overlays => throw UnimplementedError(
    'The Fluent overlays facet is not implemented yet. Until it lands, the '
    'controls facet announces tooltips to the semantics tree and opens its '
    'lists in place - both registered in FluentControls\'s doc.',
  );

  /// Adds Fluent to this build's list of design languages.
  ///
  /// The whole of what "plugin" can mean on a desktop AOT build: one
  /// pubspec dependency and one call from `lib/main.dart`. Nothing else in
  /// the application learns this package's name.
  static void register() => SkinRegistry.register(const FluentSkin());
}
