/// Pins the type facet's numbers: the Windows 11 ramp as published, the
/// nine-role mapping as decided, and the resolution door's handling of the
/// user's families and text scale.
///
/// Every expectation here restates a value whose provenance is recorded in
/// `lib/src/fluent_typography.dart` - the point of the pin is that a ramp
/// step or a mapping arm can only ever change as a DECISION, never as a
/// side effect.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_fluent/src/fluent_request_scope.dart';
import 'package:gitui_skin_fluent/src/fluent_typography.dart';

/// A request with every field at the value the assertions below expect.
const SkinRequest _request = SkinRequest(
  brightness: Brightness.dark,
  accentSeed: 0,
  textScale: 1.0,
  codeScale: 1.0,
  animationScale: 1.0,
  monoFamily: 'JetBrains Mono',
  uiFamily: 'Inter',
);

/// Resolves [role] through the door, inside a scope carrying [request] when
/// one is given and bare otherwise.
Future<TextStyle> _resolve(
  WidgetTester tester,
  TextRole role, {
  SkinRequest? request,
}) async {
  late TextStyle resolved;
  Widget probe = Builder(
    builder: (BuildContext context) {
      resolved = FluentTypeResolution.styleOf(context, role);
      return const SizedBox.shrink();
    },
  );
  if (request != null) {
    probe = FluentRequestScope(request: request, child: probe);
  }
  await tester.pumpWidget(probe);
  return resolved;
}

void main() {
  group('the ramp is the published Windows 11 type ramp', () {
    // (step, size, line height) exactly as the specification's type-ramp
    // table pairs them; the height assertion divides them back out.
    const List<(String, TextStyle, double, double, FontWeight)> steps =
        <(String, TextStyle, double, double, FontWeight)>[
          ('display', FluentTypeRamp.display, 68, 92, FontWeight.w600),
          ('titleLarge', FluentTypeRamp.titleLarge, 40, 52, FontWeight.w600),
          ('title', FluentTypeRamp.title, 28, 36, FontWeight.w600),
          ('subtitle', FluentTypeRamp.subtitle, 20, 28, FontWeight.w600),
          ('bodyLarge', FluentTypeRamp.bodyLarge, 18, 24, FontWeight.w400),
          ('bodyStrong', FluentTypeRamp.bodyStrong, 14, 20, FontWeight.w600),
          ('body', FluentTypeRamp.body, 14, 20, FontWeight.w400),
          ('caption', FluentTypeRamp.caption, 12, 16, FontWeight.w400),
        ];

    for (final (
          String name,
          TextStyle step,
          double size,
          double line,
          FontWeight weight,
        )
        in steps) {
      test('$name is $size/$line at $weight', () {
        expect(step.fontSize, size);
        expect(step.height, line / size);
        expect(step.fontWeight, weight);
        expect(step.fontFamily, 'Segoe UI Variable');
        expect(step.fontFamilyFallback, const <String>['Segoe UI']);
        // The ramp is colourless on purpose: text follows the surface it
        // sits on, and the colour side resolves the foreground.
        expect(step.color, isNull);
      });
    }

    test('caption is Regular, not the reference checkout\'s w300', () {
      // The published ramp says "Caption | Regular | 12"; the reference's
      // code sets w300 against its own doc table. The specification wins,
      // and this pin is what keeps that a decision.
      expect(FluentTypeRamp.caption.fontWeight, FontWeight.w400);
    });
  });

  group('the mapping lands each role where the judgement put it', () {
    test('the seven Segoe roles map onto exactly four rungs', () {
      expect(
        identical(
          FluentTypeScale.stepOf(TextRole.pageTitle),
          FluentTypeRamp.subtitle,
        ),
        isTrue,
      );
      expect(
        identical(
          FluentTypeScale.stepOf(TextRole.sectionTitle),
          FluentTypeRamp.bodyStrong,
        ),
        isTrue,
      );
      expect(
        identical(
          FluentTypeScale.stepOf(TextRole.itemTitle),
          FluentTypeRamp.body,
        ),
        isTrue,
      );
      expect(
        identical(FluentTypeScale.stepOf(TextRole.body), FluentTypeRamp.body),
        isTrue,
      );
      expect(
        identical(
          FluentTypeScale.stepOf(TextRole.emphasis),
          FluentTypeRamp.bodyStrong,
        ),
        isTrue,
      );
      expect(
        identical(
          FluentTypeScale.stepOf(TextRole.detail),
          FluentTypeRamp.caption,
        ),
        isTrue,
      );
      expect(
        identical(
          FluentTypeScale.stepOf(TextRole.micro),
          FluentTypeRamp.caption,
        ),
        isTrue,
      );
      expect(
        identical(
          FluentTypeScale.stepOf(TextRole.control),
          FluentTypeRamp.body,
        ),
        isTrue,
      );
    });

    test('emphasis differs from body in weight and in nothing else', () {
      // THE distinction this language draws at one size - and the place the
      // contract either holds or bends. It holds: the role states
      // prominence, Body Strong answers it.
      final TextStyle emphasis = FluentTypeScale.stepOf(TextRole.emphasis);
      final TextStyle body = FluentTypeScale.stepOf(TextRole.body);
      expect(emphasis.fontSize, body.fontSize);
      expect(emphasis.height, body.height);
      expect(emphasis.fontFamily, body.fontFamily);
      expect(emphasis.fontWeight, FontWeight.w600);
      expect(body.fontWeight, FontWeight.w400);
    });

    test('code takes Body\'s metrics on the published fixed-width floor', () {
      final TextStyle code = FluentTypeScale.stepOf(TextRole.code);
      expect(code.fontSize, FluentTypeRamp.body.fontSize);
      expect(code.height, FluentTypeRamp.body.height);
      expect(code.fontWeight, FluentTypeRamp.body.fontWeight);
      // Never Segoe: even with no request in the tree a code line keeps its
      // columns, on the fixed-width face the specification publishes.
      expect(code.fontFamily, 'Consolas');
      expect(code.fontFamilyFallback, const <String>['monospace']);
    });

    test('the collapses are the language\'s own, pinned as decisions', () {
      // Fluent builds hierarchy from placement and colour, not from a size
      // step per job. These three pairs LOOK identical by design; breaking
      // any of them apart is a mapping decision, not a tuning tweak.
      expect(
        FluentTypeScale.stepOf(TextRole.sectionTitle),
        same(FluentTypeScale.stepOf(TextRole.emphasis)),
      );
      expect(
        FluentTypeScale.stepOf(TextRole.itemTitle),
        same(FluentTypeScale.stepOf(TextRole.control)),
      );
      expect(
        FluentTypeScale.stepOf(TextRole.detail),
        same(FluentTypeScale.stepOf(TextRole.micro)),
      );
    });
  });

  group('the resolution door', () {
    testWidgets('without a scope the bare ramp step answers', (
      WidgetTester tester,
    ) async {
      final TextStyle resolved = await _resolve(tester, TextRole.body);
      expect(identical(resolved, FluentTypeRamp.body), isTrue);
    });

    testWidgets('the user\'s interface family lands on every Segoe role', (
      WidgetTester tester,
    ) async {
      final TextStyle resolved = await _resolve(
        tester,
        TextRole.body,
        request: _request,
      );
      expect(resolved.fontFamily, isNot(FluentTypeRamp.body.fontFamily));
      expect(resolved.fontFamily!.toLowerCase(), contains('inter'));
      // The family is the only thing the user's choice moves: the step's
      // metrics survive the resolution untouched.
      expect(resolved.fontSize, FluentTypeRamp.body.fontSize);
      expect(resolved.fontWeight, FluentTypeRamp.body.fontWeight);
      expect(resolved.height, FluentTypeRamp.body.height);
    });

    testWidgets('code takes the mono family, not the interface family', (
      WidgetTester tester,
    ) async {
      final TextStyle resolved = await _resolve(
        tester,
        TextRole.code,
        request: _request,
      );
      final String family = resolved.fontFamily!.toLowerCase().replaceAll(
        ' ',
        '',
      );
      expect(family, contains('jetbrainsmono'));
      expect(family, isNot(contains('inter')));
      expect(resolved.fontSize, FluentTypeRamp.body.fontSize);
    });

    testWidgets('an unknown family keeps the language\'s own face', (
      WidgetTester tester,
    ) async {
      const SkinRequest unknown = SkinRequest(
        brightness: Brightness.dark,
        accentSeed: 0,
        textScale: 1.0,
        codeScale: 1.0,
        animationScale: 1.0,
        monoFamily: 'No Such Mono 2026',
        uiFamily: 'No Such Family 2026',
      );
      final TextStyle body = await _resolve(
        tester,
        TextRole.body,
        request: unknown,
      );
      final TextStyle code = await _resolve(
        tester,
        TextRole.code,
        request: unknown,
      );
      expect(body.fontFamily, 'Segoe UI Variable');
      expect(code.fontFamily, 'Consolas');
    });

    testWidgets('the text scale multiplies and rounds, as the same user '
        'setting resolves under the Material skin', (
      WidgetTester tester,
    ) async {
      Future<TextStyle> at(double scale, TextRole role) => _resolve(
        tester,
        role,
        request: SkinRequest(
          brightness: Brightness.dark,
          accentSeed: 0,
          textScale: scale,
          codeScale: 1.0,
          animationScale: 1.0,
          monoFamily: '',
          uiFamily: '',
        ),
      );
      // 14 * 1.10 = 15.4 -> 15; 14 * 0.85 = 11.9 -> 12; 20 * 1.10 = 22.
      expect((await at(1.10, TextRole.body)).fontSize, 15);
      expect((await at(0.85, TextRole.body)).fontSize, 12);
      expect((await at(1.10, TextRole.pageTitle)).fontSize, 22);
      // The height is a ratio, so the line grows with the size on its own.
      expect(
        (await at(1.10, TextRole.body)).height,
        FluentTypeRamp.body.height,
      );
      // An empty family means "nothing chosen": the scaled step passes
      // through in the language's own face.
      expect((await at(1.10, TextRole.body)).fontFamily, 'Segoe UI Variable');
    });

    testWidgets('the code scale multiplies into the code step and only the '
        'code step', (WidgetTester tester) async {
      Future<TextStyle> at(double text, double code, TextRole role) => _resolve(
        tester,
        role,
        request: SkinRequest(
          brightness: Brightness.dark,
          accentSeed: 0,
          textScale: text,
          codeScale: code,
          animationScale: 1.0,
          monoFamily: '',
          uiFamily: '',
        ),
      );
      // The contract states codeScale as a refinement ON TOP of textScale,
      // and this door multiplies once and rounds once:
      // 14 * 1.0 * 1.15 = 16.1 -> 16; 14 * 1.10 * 1.15 = 17.71 -> 18.
      expect((await at(1.0, 1.15, TextRole.code)).fontSize, 16);
      expect((await at(1.10, 1.15, TextRole.code)).fontSize, 18);
      // Every other role ignores it - the code size is the code font's, and
      // the code font is [TextRole.code]'s alone.
      expect((await at(1.0, 1.15, TextRole.body)).fontSize, 14);
      expect((await at(1.0, 1.15, TextRole.detail)).fontSize, 12);
    });
  });

  group('the request scope', () {
    testWidgets('publishes the request to its subtree', (
      WidgetTester tester,
    ) async {
      SkinRequest? seen;
      await tester.pumpWidget(
        FluentRequestScope(
          request: _request,
          child: Builder(
            builder: (BuildContext context) {
              seen = FluentRequestScope.maybeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(seen, _request);
    });

    testWidgets('is absent, not defaulted, outside the root', (
      WidgetTester tester,
    ) async {
      SkinRequest? seen = _request;
      await tester.pumpWidget(
        Builder(
          builder: (BuildContext context) {
            seen = FluentRequestScope.maybeOf(context);
            return const SizedBox.shrink();
          },
        ),
      );
      expect(seen, isNull);
    });
  });
}
