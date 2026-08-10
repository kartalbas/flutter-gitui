/// The Skin implementation: what the package promises the registry - every
/// facet getter now answers with this package's own facet, and the only
/// remaining fences are the overlay facet's pending members.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_fluent/gitui_skin_fluent.dart';
import 'package:gitui_skin_fluent/src/facets/fluent_chrome.dart';
import 'package:gitui_skin_fluent/src/facets/fluent_controls.dart';
import 'package:gitui_skin_fluent/src/facets/fluent_surfaces.dart';
import 'package:gitui_skin_fluent/src/facets/fluent_layout.dart';
import 'package:gitui_skin_fluent/src/facets/fluent_motion_facet.dart';
import 'package:gitui_skin_fluent/src/facets/fluent_overlays.dart';
import 'package:gitui_skin_fluent/src/facets/fluent_type.dart';

void main() {
  setUp(SkinRegistry.reset);
  tearDown(SkinRegistry.reset);

  test('registers as a selectable design language, not an instrument', () {
    FluentSkin.register();
    final Skin skin = SkinRegistry.byId('fluent');
    expect(skin.id, 'fluent');
    expect(skin.nameKey, 'skinFluent');
    expect(skin.isInstrument, isFalse);
    expect(
      SkinRegistry.selectable.map((Skin s) => s.id),
      contains('fluent'),
      reason: 'a non-instrument skin is offered to the user',
    );
  });

  test('registering twice is a no-op, exactly as main() and a booting test '
      'both require', () {
    FluentSkin.register();
    FluentSkin.register();
    expect(SkinRegistry.all.where((Skin s) => s.id == 'fluent'), hasLength(1));
  });

  test('claims nothing on the application root', () {
    const FluentSkin skin = FluentSkin();
    expect(skin.rootClaims.localizationsDelegates, isEmpty);
    expect(skin.rootClaims.windowChrome, WindowChrome.hostDefault);
  });

  test('the implemented facets are this package\'s own', () {
    const FluentSkin skin = FluentSkin();
    expect(skin.chrome, isA<FluentChrome>());
    expect(skin.controls, isA<FluentControls>());
    expect(skin.surfaces, isA<FluentSurfaces>());
    expect(skin.type, isA<FluentType>());
    expect(skin.layout, isA<FluentLayout>());
    expect(skin.motion, isA<FluentMotionFacet>());
    expect(skin.overlays, isA<FluentOverlays>());
  });

  // The overlay facet's four pending members each fence themselves with a
  // throw of their own. That is asserted where real hosts exist - the
  // overlay behaviour suite (`test/behavior/fluent_menu_test.dart`) - since
  // a host's constructor is deliberately private to the API package.
}
