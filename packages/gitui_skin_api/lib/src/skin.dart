import 'facets/skin_chrome.dart';
import 'facets/skin_controls.dart';
import 'facets/skin_layout.dart';
import 'facets/skin_motion.dart';
import 'facets/skin_overlays.dart';
import 'facets/skin_surfaces.dart';
import 'facets/skin_type.dart';
import 'specs/chrome_specs.dart';

/// A design language, whole.
///
/// Everything visible in the application is produced by exactly one of these.
/// "Plugin" means what it physically can mean on a Flutter desktop AOT build,
/// where there is no dynamic code loading: adding a pubspec dependency and one
/// `register()` line. What the contract guarantees is the part that actually
/// matters - that NOTHING ELSE in the application changes per skin.
abstract interface class Skin {
  /// How this skin is named in configuration and in a test parameterisation.
  String get id;

  /// The localisation key for the name a user sees in the settings picker. A
  /// key rather than a string, because the application owns its translations
  /// and a skin package must not ship its own.
  String get nameKey;

  /// Whether this skin is an instrument rather than something to ship.
  ///
  /// True only for the blueprint. An instrument registers itself only in
  /// debug, and a release-mode test asserts that no registered skin claims it.
  bool get isInstrument;

  /// What this skin legitimately needs installed on the single application
  /// root. See `SkinRootClaims`: three declared exceptions, each justified by
  /// a Flutter plumbing requirement, each confined to `lib/main.dart` by a
  /// lint.
  SkinRootClaims get rootClaims;

  /// The frame: the root, the shell, the screens, the dialog surface.
  SkinChrome get chrome;

  /// Things you operate.
  SkinControls get controls;

  /// Things that hold other things.
  SkinSurfaces get surfaces;

  /// Things you read.
  SkinType get type;

  /// How things sit next to one another.
  SkinLayout get layout;

  /// How things change.
  SkinMotion get motion;

  /// Things that appear on top.
  SkinOverlays get overlays;
}
