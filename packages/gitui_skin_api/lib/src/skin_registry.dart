import 'package:flutter/widgets.dart';

import 'skin.dart';

/// True in a release build.
///
/// Spelled out here rather than imported, because `kReleaseMode` lives in
/// `package:flutter/foundation.dart` and this package imports
/// `package:flutter/widgets.dart` and nothing else from Flutter. It is the
/// same expression `foundation` itself uses.
const bool _kReleaseMode = bool.fromEnvironment('dart.vm.product');

/// The list of design languages this build knows about.
///
/// A package that registers itself simply appears in the settings picker;
/// nothing else in the application learns its name. That is what "plugin"
/// reduces to on a platform with no dynamic code loading, and it is enough,
/// because the property that matters is that no OTHER file changes per skin.
abstract final class SkinRegistry {
  static final Map<String, Skin> _byId = <String, Skin>{};
  static final List<Skin> _inOrder = <Skin>[];

  /// Adds [skin] to this build's list.
  ///
  /// Registering two skins under one id throws rather than silently replacing:
  /// the id is how a saved preference, a test parameterisation and a bug
  /// report all name the same design language, so a collision is a defect in
  /// the wiring, not a preference about precedence.
  static void register(Skin skin) {
    final Skin? existing = _byId[skin.id];
    if (existing != null && !identical(existing, skin)) {
      throw StateError(
        'Two different skins are registered as "${skin.id}". A skin id is how '
        'a saved setting, a test and a bug report all name one design '
        'language, so it has to be unique across the build.',
      );
    }
    if (existing != null) return;
    _byId[skin.id] = skin;
    _inOrder.add(skin);
  }

  /// Returns the skin registered as [id].
  ///
  /// Throws with the ids that ARE available, because the failure this guards
  /// is a saved preference naming a skin whose package is no longer in the
  /// build - and "material is not registered" is unactionable without the
  /// list.
  static Skin byId(String id) {
    final Skin? skin = _byId[id];
    if (skin == null) {
      throw ArgumentError.value(
        id,
        'id',
        'No skin is registered under that id. Registered: '
            '${_inOrder.map((Skin s) => s.id).join(', ')}',
      );
    }
    return skin;
  }

  /// Every registered skin, in registration order.
  static List<Skin> get all => List<Skin>.unmodifiable(_inOrder);

  /// Every skin a user may choose: [all], minus the instruments in a release
  /// build.
  ///
  /// The blueprint is a measuring device, not a look, and a user who selected
  /// it would find an application drawn in outlines. It stays reachable in
  /// debug precisely because that is when it is being used as an instrument.
  static List<Skin> get selectable => List<Skin>.unmodifiable(
    _inOrder.where((Skin skin) => !(_kReleaseMode && skin.isInstrument)),
  );

  /// Empties the registry.
  ///
  /// For tests that parameterise over skins and must not inherit registrations
  /// from a previous case.
  @visibleForTesting
  static void reset() {
    _byId.clear();
    _inOrder.clear();
  }
}
