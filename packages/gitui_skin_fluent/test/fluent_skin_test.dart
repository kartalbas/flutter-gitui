/// The Skin implementation: what the package promises the registry, and
/// what it honestly refuses until the remaining slices land.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_fluent/gitui_skin_fluent.dart';
import 'package:gitui_skin_fluent/src/facets/fluent_controls.dart';

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

  test('the controls facet is implemented', () {
    expect(const FluentSkin().controls, isA<FluentControls>());
  });

  test('every pending facet refuses loudly rather than delegating quietly', () {
    const FluentSkin skin = FluentSkin();
    // Each facet lands with its own slice; until it does, reaching it is a
    // wiring error the assembler must see - never a silent fallback to
    // another design language.
    expect(() => skin.chrome, throwsUnimplementedError);
    expect(() => skin.surfaces, throwsUnimplementedError);
    expect(() => skin.type, throwsUnimplementedError);
    expect(() => skin.layout, throwsUnimplementedError);
    expect(() => skin.motion, throwsUnimplementedError);
    expect(() => skin.overlays, throwsUnimplementedError);
  });
}
