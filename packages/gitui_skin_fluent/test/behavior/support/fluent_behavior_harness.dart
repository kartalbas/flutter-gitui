/// The Fluent behaviour harness: what turns "it feels like Fluent" into
/// assertions.
///
/// A drawn skin inherits none of a widget library's hand-tuning, so every
/// behaviour it claims has to be MEASURED. The idiom is the one the Material
/// conformance suite already uses (gitui_skin_material/test/conformance/
/// support/conformance_harness.dart, itself the idiom of Flutter's own
/// ink_well_test.dart): drive a state with real input - a mouse pointer, a
/// held gesture, a Tab key - and read what got PAINTED back out of the paint
/// stream, never out of widget properties. A widget property is what the
/// code asked for; the paint stream is what the user gets.
///
/// One difference from the Material harness, and it is structural: Material
/// state layers are ink painted into a `Material`'s ink layer, so that suite
/// reads `_RenderInkFeatures`. A Fluent control has no ink layer - its
/// states are its OWN fill, border and strokes - so this harness replays the
/// control's render subtree onto a recording canvas and classifies the
/// calls:
///
///  * a fill-style `drawRRect`/`drawRect`/`drawPath` is a CONTAINER FILL;
///  * a `drawDRRect` is a painted STROKE - the ring between two rounded
///    rectangles, which is how both the control's elevation stroke
///    (fluent_ui@4.16.1 lib/src/controls/utils/
///    rounded_rectangle_gradient_border.dart:141-153, shader-painted) and a
///    `RoundedRectangleBorder` side (the focus rectangle's strokes) reach
///    the canvas. The two are told apart by SUBTREE, not by style: what is
///    read under [buttonContainer] is the control's outline, what is read
///    under [focusRingBox] is the focus rectangle's.
///
/// State drivers:
///  * hover    -> [hoverOver] (a real mouse pointer, kept until teardown)
///  * press    -> [pressAndHold] (caller ends it with `gesture.up()`)
///  * focus    -> [focusWithTab] (the keyboard, which is the only input
///                that may reveal the focus rectangle)
///  * disabled -> construction state: build the spec with `onPressed: null`
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_fluent/src/controls/fluent_button.dart';
import 'package:gitui_skin_fluent/src/fluent_focus_ring.dart';
import 'package:gitui_skin_fluent/src/fluent_theme.dart';

/// Logical surface every behaviour test renders into - the same surface the
/// Material conformance suite pins, so a measurement here is comparable.
const Size kFluentBehaviorSurface = Size(1280, 800);

/// Pumps [child] centred over the theme's own page ground
/// (`SolidBackgroundFillColorBase`), under a [FluentTheme] scope, inside a
/// bare [WidgetsApp].
///
/// A `WidgetsApp` and not any design language's app shell: it contributes
/// exactly the plumbing a keyboard user needs - the default activation
/// shortcuts (Enter/Space -> `ActivateIntent`) and a focus traversal group -
/// and no theme of its own, so everything measured afterwards was painted by
/// the skin.
///
/// The ground matters and is not decoration: Fluent's control fills are
/// translucent, so "hover darkens" is only a measurable statement about the
/// COMPOSITE over the ground the language itself specifies.
Future<void> pumpFluentBehavior(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = kFluentBehaviorSurface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // The suite measures a WINDOWS design language, so it runs in the focus
  // highlight mode a desktop rests in. This is a measurement precondition,
  // not a preference: the framework only delivers hover and focus
  // highlights in the "traditional" highlight mode (FocusableActionDetector
  // gates both on it, flutter widgets/actions.dart:1301-1314), which is the
  // resting mode on desktop platforms - while the test binding's default
  // platform is Android, which rests in "touch" mode where a hover would
  // never highlight and every hover assertion would measure the harness,
  // not the skin. Pinned via the strategy rather than
  // `debugDefaultTargetPlatformOverride` because the binding verifies the
  // foundation overrides are unset BEFORE `addTearDown` callbacks run, so
  // the platform override cannot be cleaned up from a shared pump helper.
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );

  final FluentThemeData data = brightness == Brightness.light
      ? const FluentThemeData.light()
      : const FluentThemeData.dark();
  await tester.pumpWidget(
    WidgetsApp(
      color: data.resources.solidBackgroundFillColorBase,
      debugShowCheckedModeBanner: false,
      builder: (BuildContext context, Widget? navigator) => FluentTheme(
        data: data,
        child: ColoredBox(
          color: data.resources.solidBackgroundFillColorBase,
          // A desktop window's root focus scope holds focus from the moment
          // the window is foreground; without it `primaryFocus` is null and
          // a Tab has nowhere to travel FROM. (A MaterialApp gets this from
          // its Navigator; this harness deliberately has neither.)
          child: FocusScope(autofocus: true, child: Center(child: child)),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The visual container of the pumped [FluentButton] - the box whose fill,
/// outline and padding are the button's appearance.
Finder buttonContainer() => find.descendant(
  of: find.byType(FluentButton),
  matching: find.byType(AnimatedContainer),
);

/// The focus rectangle's own subtree: the two nested decorations behind
/// [FluentFocusRing]'s `IgnorePointer`, and nothing of the control they
/// mark.
Finder focusRingBox() => find.descendant(
  of: find.byType(FluentFocusRing),
  matching: find.byType(IgnorePointer),
);

/// One focus-rectangle stroke read back out of the stream.
///
/// A non-hairline `RoundedRectangleBorder` side paints as a `drawDRRect` -
/// the ring between the shape's outer rounded rectangle and that rectangle
/// deflated by the stroke width - so the width is recovered from the two
/// rectangles and the outer rectangle's corner is the shape's own corner.
final class PaintedStroke {
  const PaintedStroke({
    required this.color,
    required this.width,
    required this.outerRadius,
  });

  /// The stroke's colour.
  final Color color;

  /// The stroke's width in logical pixels: half the difference between the
  /// outer and inner rectangle widths.
  final double width;

  /// The corner radius of the stroke's outer edge - the shape's radius.
  final double outerRadius;
}

/// One control-outline paint (a `drawDRRect` ring) read back out of the
/// stream.
final class PaintedOutline {
  const PaintedOutline({required this.color, required this.hasShader});

  /// The flat colour, meaningful only when [hasShader] is false.
  final Color color;

  /// True when the outline was painted through a gradient shader - the
  /// elevation stroke; false for the flat pressed/disabled stroke.
  final bool hasShader;
}

/// Replays every render object under [finder] onto a recording canvas, in
/// paint order.
List<RecordedInvocation> _recordPaint(WidgetTester tester, Finder finder) {
  final List<RecordedInvocation> recorded = <RecordedInvocation>[];
  for (final Element element in finder.evaluate()) {
    final RenderObject? renderObject = element.renderObject;
    if (renderObject == null) {
      continue;
    }
    final TestRecordingCanvas canvas = TestRecordingCanvas();
    final TestRecordingPaintingContext context = TestRecordingPaintingContext(
      canvas,
    );
    renderObject.paint(context, Offset.zero);
    recorded.addAll(canvas.invocations);
  }
  return recorded;
}

/// Every container fill painted under [finder], in paint order: the colours
/// of fill-style paints from plain shape drawing. `drawDRRect` is excluded
/// on purpose - that call is how an outline paints (see the library doc).
List<Color> paintedFillColors(WidgetTester tester, Finder finder) {
  const Set<Symbol> fillCalls = <Symbol>{#drawRRect, #drawRect, #drawPath};
  final List<Color> colors = <Color>[];
  for (final RecordedInvocation recorded in _recordPaint(tester, finder)) {
    final Invocation invocation = recorded.invocation;
    if (!invocation.isMethod || !fillCalls.contains(invocation.memberName)) {
      continue;
    }
    for (final Object? argument in invocation.positionalArguments) {
      if (argument is Paint && argument.style == PaintingStyle.fill) {
        colors.add(argument.color);
      }
    }
  }
  return colors;
}

/// The single fill the button's container paints right now. Fails the test
/// when the container paints no fill or several - either would mean the
/// container is no longer the one box the button promises.
Color containerFill(WidgetTester tester) {
  final List<Color> fills = paintedFillColors(tester, buttonContainer());
  expect(
    fills,
    hasLength(1),
    reason: 'the button container must paint exactly one fill, found $fills',
  );
  return fills.single;
}

/// Every control outline painted under [finder], in paint order.
List<PaintedOutline> paintedOutlines(WidgetTester tester, Finder finder) {
  final List<PaintedOutline> outlines = <PaintedOutline>[];
  for (final RecordedInvocation recorded in _recordPaint(tester, finder)) {
    final Invocation invocation = recorded.invocation;
    if (!invocation.isMethod || invocation.memberName != #drawDRRect) {
      continue;
    }
    for (final Object? argument in invocation.positionalArguments) {
      if (argument is Paint) {
        outlines.add(
          PaintedOutline(
            color: argument.color,
            hasShader: argument.shader != null,
          ),
        );
      }
    }
  }
  return outlines;
}

/// Every focus-rectangle stroke painted under [finder], in paint order.
///
/// Scoped by SUBTREE, not by paint style: a `RoundedRectangleBorder` side
/// paints as a `drawDRRect` ring exactly like a control outline does, so
/// what makes these the rectangle's strokes is that [finder] is
/// [focusRingBox] - nothing of the control lives under it.
List<PaintedStroke> paintedStrokes(WidgetTester tester, Finder finder) {
  final List<PaintedStroke> strokes = <PaintedStroke>[];
  for (final RecordedInvocation recorded in _recordPaint(tester, finder)) {
    final Invocation invocation = recorded.invocation;
    if (!invocation.isMethod || invocation.memberName != #drawDRRect) {
      continue;
    }
    final List<Object?> arguments = invocation.positionalArguments;
    if (arguments.length < 3) {
      continue;
    }
    final Object? outer = arguments[0];
    final Object? inner = arguments[1];
    final Object? paint = arguments[2];
    if (outer is! RRect || inner is! RRect || paint is! Paint) {
      continue;
    }
    strokes.add(
      PaintedStroke(
        color: paint.color,
        width: (outer.width - inner.width) / 2,
        outerRadius: outer.tlRadiusX,
      ),
    );
  }
  return strokes;
}

/// Every rounded rectangle painted under [finder], in paint order - for
/// measuring a painted corner radius.
List<RRect> paintedRRects(WidgetTester tester, Finder finder) {
  final List<RRect> rects = <RRect>[];
  for (final RecordedInvocation recorded in _recordPaint(tester, finder)) {
    final Invocation invocation = recorded.invocation;
    if (!invocation.isMethod || invocation.memberName != #drawRRect) {
      continue;
    }
    for (final Object? argument in invocation.positionalArguments) {
      if (argument is RRect) {
        rects.add(argument);
      }
    }
  }
  return rects;
}

/// The colour the button's label is rendered in right now, read from the
/// paragraph that actually paints so the animated text style is part of the
/// measurement.
Color renderedLabelColor(WidgetTester tester, String label) {
  final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
    find.text(label),
  );
  final Color? color = paragraph.text.style?.color;
  expect(color, isNotNull, reason: 'the label "$label" must carry a colour');
  return color!;
}

/// Asserts that [actual] paints as [expected], allowing the alpha channel a
/// single 8-bit half-step.
///
/// The slack is measured, not defensive: a `Paint` stores its colour as
/// float32 components, so an opacity like 0.9 - exactly WinUI's accent hover
/// brush - reads back as 229.49999.../255 where double arithmetic says
/// 229.5, and the two round to neighbouring 8-bit values. The R/G/B
/// channels are compared exactly.
void expectPaintedColor(Color actual, Color expected, {String? reason}) {
  expect(
    actual.withValues(alpha: 1.0).toARGB32(),
    expected.withValues(alpha: 1.0).toARGB32(),
    reason: reason,
  );
  expect(actual.a * 255, closeTo(expected.a * 255, 1.0), reason: reason);
}

/// [fill] composited over [ground] - what the eye actually receives from a
/// translucent resource. Every directional claim ("press darkens") is a
/// claim about this, never about the raw resource.
Color composedOver(Color ground, Color fill) => Color.alphaBlend(fill, ground);

/// Relative luminance of [fill] over [ground], 0 (black) to 1 (white).
double luminanceOver(Color ground, Color fill) =>
    composedOver(ground, fill).computeLuminance();

/// Moves a real mouse pointer over [finder] and settles - the hover driver.
/// The pointer stays until test teardown; use [hoverAway] mid-test.
Future<TestGesture> hoverOver(WidgetTester tester, Finder finder) async {
  final TestGesture gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  await gesture.addPointer(location: Offset.zero);
  addTearDown(() => gesture.removePointer());
  await tester.pump();
  await gesture.moveTo(tester.getCenter(finder));
  await tester.pumpAndSettle();
  return gesture;
}

/// Moves [gesture] far away from everything and settles.
Future<void> hoverAway(WidgetTester tester, TestGesture gesture) async {
  await gesture.moveTo(Offset.zero);
  await tester.pumpAndSettle();
}

/// Presses [finder] and holds, pumping past the container animation so the
/// pressed appearance is fully painted. The caller MUST end the interaction
/// with `await gesture.up()` followed by `pumpAndSettle` (release keeps the
/// pressed state for 100 ms - FluentMotion.pressedRelease - so a plain pump
/// leaves a live timer).
Future<TestGesture> pressAndHold(WidgetTester tester, Finder finder) async {
  final TestGesture gesture = await tester.startGesture(
    tester.getCenter(finder),
  );
  await tester.pump();
  // Past the 83 ms container animation (FluentMotion.faster).
  await tester.pump(const Duration(milliseconds: 100));
  return gesture;
}

/// Drives keyboard focus onto the first focusable control by sending Tab -
/// the way a keyboard user reaches it, and the only input that may reveal
/// the focus rectangle. Sending a key also flips the framework's focus
/// highlight mode to traditional, exactly as a physical keystroke does.
Future<void> focusWithTab(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pumpAndSettle();
}
