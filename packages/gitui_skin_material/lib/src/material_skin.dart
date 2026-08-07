// `MaterialType` is a Flutter enum (`Material(type:)`) AND the name the
// contract's type facet has to take, since the seven facet classes are named
// after the seven facets. The SDK's is hidden rather than the facet renamed:
// nothing in this package draws a raw `Material` by type, and a facet called
// something other than its own member would be the one file where the seven
// stopped lining up.
import 'package:flutter/material.dart' hide MaterialType;
import 'package:gitui_skin_api/gitui_skin_api.dart';

import 'facets/material_chrome.dart';
import 'facets/material_controls.dart';
import 'facets/material_layout.dart';
import 'facets/material_motion.dart';
import 'facets/material_overlays.dart';
import 'facets/material_surfaces.dart';
import 'facets/material_type.dart';

/// Material 3, whole, behind the contract.
///
/// The seven facets are getters over `const` value objects with no state of
/// their own, exactly as `BlueprintSkin` arranges them, and for the same two
/// reasons. It keeps this class `const`-constructible, and it keeps this file
/// out of the way: a facet can be rewritten without anybody touching
/// `MaterialSkin`, which matters while several people are extracting different
/// facets into this package at the same time. The cost is one small allocation
/// per access.
final class MaterialSkin implements Skin {
  /// Builds the Material skin.
  const MaterialSkin();

  /// How this skin is named in configuration and in a test parameterisation.
  @override
  String get id => 'material';

  /// The key for the name a user sees in the settings picker.
  ///
  /// A key rather than a string: the application owns its translations and a
  /// skin package must not ship its own.
  @override
  String get nameKey => 'skinMaterial';

  /// False. This is a design language, not an instrument.
  @override
  bool get isInstrument => false;

  /// What Material legitimately needs installed on the single application
  /// root.
  ///
  /// All three declared exceptions resolve to Flutter's own defaults here, and
  /// that is a finding rather than a placeholder: Material is the language the
  /// SDK's root widgets are built for, so `GlobalMaterialLocalizations` is
  /// already installed by the application root, the stock `ScrollBehavior` is
  /// the Material one, and the window frame is whatever the host draws. The
  /// claims exist for the languages that cannot say the same - Fluent checks
  /// its own localisations before it pushes a dialog, and `macos_ui` reads
  /// `MaterialLocalizations` un-guarded in seven files.
  ///
  /// Notably absent, and deliberately: there is no `ThemeData` member anywhere
  /// on the contract. This skin builds its own inside `chrome.wrapRoot`, so a
  /// `ThemeData` never crosses the seam at all.
  @override
  SkinRootClaims get rootClaims => const SkinRootClaims(
    localizationsDelegates: <LocalizationsDelegate<Object?>>[],
    scrollBehavior: MaterialScrollBehavior(),
    windowChrome: WindowChrome.hostDefault,
  );

  @override
  SkinChrome get chrome => const MaterialChrome();

  @override
  SkinControls get controls => const MaterialControls();

  @override
  SkinSurfaces get surfaces => const MaterialSurfaces();

  @override
  SkinType get type => const MaterialType();

  @override
  SkinLayout get layout => const MaterialLayout();

  @override
  SkinMotion get motion => const MaterialMotion();

  @override
  SkinOverlays get overlays => const MaterialOverlays();

  /// Adds Material to this build's list of design languages.
  ///
  /// The whole of what "plugin" can mean on a desktop AOT build with no
  /// dynamic code loading: one pubspec dependency and one call from
  /// `lib/main.dart`. Nothing else in the application learns this package's
  /// name - which is the property that actually matters, and the one the
  /// blueprint exists to falsify.
  static void register() => SkinRegistry.register(const MaterialSkin());
}
