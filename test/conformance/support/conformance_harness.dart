/// Shared fixture for Material 3 conformance measurements.
///
/// Every conformance test renders its widget through [pumpConformance] so
/// all measurements happen under the application's REAL theme
/// (`AppTheme.lightTheme()`/`AppTheme.darkTheme()` with their defaults,
/// lib/shared/theme/app_theme.dart), at a fixed surface size and pixel
/// ratio, with google_fonts pinned to the bundled font assets.
///
/// State drivers:
///   * hover    -> [hoverOver]
///   * press    -> [pressAndHold] (caller ends it with `gesture.up()`)
///   * focus    -> [focusFirstWithTab]
///   * disabled -> a construction-time state: build the widget with
///     `onPressed: null` (or `isDisabled: true`); there is nothing to drive.
///
/// State layers are painted ink, not widget properties: read them from the
/// paint stream via [inkFeatures] with the `paints` matcher
/// (flutter_test src/mock_canvas.dart), the same idiom Flutter's own
/// test/material/ink_well_test.dart uses.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Logical surface every conformance test renders into.
const Size kConformanceSurface = Size(1280, 800);

/// Pumps [child] under the app's real theme inside a MaterialApp + Scaffold.
Future<void> pumpConformance(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
}) async {
  // Tests must never fetch fonts from the network. The app bundles every
  // font it uses under assets/google_fonts/ and `flutter test` serves those
  // assets, so google_fonts resolves them locally.
  GoogleFonts.config.allowRuntimeFetching = false;

  tester.view.physicalSize = kConformanceSurface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      // Container components read localized strings for their built-in
      // affordances (BaseListItem's overflow menu tooltip, for example), so
      // the harness always supplies the app's delegates; a suite that forgets
      // them would fail on a null AppLocalizations rather than on a
      // conformance mismatch.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: brightness == Brightness.light
          ? AppTheme.lightTheme()
          : AppTheme.darkTheme(),
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pump();
}

/// Material 3 defaults for a filled button, straight from the framework.
///
/// `defaultStyleOf` is public API on ButtonStyleButton and returns the
/// generated `_FilledButtonDefaultsM3`
/// (flutter/lib/src/material/filled_button.dart), which encodes the
/// md.comp.filled-button.* tokens against the current Theme. It deliberately
/// ignores app-theme component overrides (those come from `themeStyleOf`),
/// which is exactly what makes it the M3 oracle. It only reads
/// `Theme.of(context)`, so any context under the pumped MaterialApp works.
///
/// Note: the same trick does NOT exist for IconButton — its generated
/// defaults live on the private `_IconButtonM3` (icon_button.dart), and
/// `IconButton` is a plain StatelessWidget. A BaseIconButton suite must pin
/// the documented constants with source citations instead.
ButtonStyle m3FilledButtonDefaults(WidgetTester tester) {
  final BuildContext context = tester.element(find.byType(Scaffold));
  // The raw framework widget is constructed deliberately: its
  // `defaultStyleOf` IS the Material 3 oracle this suite measures Base*
  // components against. It is never pumped, only asked for its generated
  // defaults, so the design-system ban on shipping FilledButton in UI code
  // does not apply here.
  // ignore: avoid_filled_button
  return const FilledButton(
    onPressed: null,
    child: SizedBox.shrink(),
  ).defaultStyleOf(context);
}

/// Material 3 defaults for a text button, straight from the framework.
///
/// Same construction as [m3FilledButtonDefaults]: `defaultStyleOf` returns
/// the generated `_TextButtonDefaultsM3`
/// (flutter/lib/src/material/text_button.dart), which encodes the
/// md.comp.text-button.* tokens against the current Theme and deliberately
/// ignores app-theme component overrides.
ButtonStyle m3TextButtonDefaults(WidgetTester tester) {
  final BuildContext context = tester.element(find.byType(Scaffold));
  // Constructed only to read its generated defaults, never pumped; the
  // design-system ban on shipping TextButton in UI code does not apply.
  // ignore: avoid_text_button
  return const TextButton(
    onPressed: null,
    child: SizedBox.shrink(),
  ).defaultStyleOf(context);
}

/// Material 3 defaults for an outlined button, straight from the framework.
///
/// Same construction as [m3FilledButtonDefaults]: `defaultStyleOf` returns
/// the generated `_OutlinedButtonDefaultsM3`
/// (flutter/lib/src/material/outlined_button.dart), which encodes the
/// md.comp.outlined-button.* tokens against the current Theme and
/// deliberately ignores app-theme component overrides.
ButtonStyle m3OutlinedButtonDefaults(WidgetTester tester) {
  final BuildContext context = tester.element(find.byType(Scaffold));
  // Constructed only to read its generated defaults, never pumped; the
  // design-system ban on shipping OutlinedButton in UI code does not apply.
  // ignore: avoid_outlined_button
  return const OutlinedButton(
    onPressed: null,
    child: SizedBox.shrink(),
  ).defaultStyleOf(context);
}

/// Maps [color] onto the name of the [scheme] role that carries exactly that
/// value, `role @ NN%` when it is a role color at a reduced opacity (the shape
/// every M3 disabled and state-layer color has), or an `#AARRGGBB` literal
/// when neither matches.
///
/// Both sides of a conformance comparison go through this function, so a
/// registered deviation can document a foreground as a stable role name
/// (`primary`, `onSurface @ 12%`) instead of a scheme-dependent hex value.
///
/// Colors are compared through [Color.toARGB32] rather than `==`: a color
/// read back out of a `Paint` has been quantised to eight bits per channel,
/// so comparing the floating-point components against a scheme role would
/// report a spurious mismatch for a color that paints identically.
String colorRoleName(ColorScheme scheme, Color color) {
  // A fully transparent color carries no role: every role matches it at 0%,
  // so naming one would be arbitrary. It is its own descriptor.
  if (color.a == 0) {
    return 'transparent';
  }
  final Map<String, Color> roles = <String, Color>{
    'primary': scheme.primary,
    'onPrimary': scheme.onPrimary,
    'primaryContainer': scheme.primaryContainer,
    'onPrimaryContainer': scheme.onPrimaryContainer,
    'secondary': scheme.secondary,
    'onSecondary': scheme.onSecondary,
    'secondaryContainer': scheme.secondaryContainer,
    'onSecondaryContainer': scheme.onSecondaryContainer,
    'tertiary': scheme.tertiary,
    'onTertiary': scheme.onTertiary,
    'tertiaryContainer': scheme.tertiaryContainer,
    'onTertiaryContainer': scheme.onTertiaryContainer,
    'error': scheme.error,
    'onError': scheme.onError,
    'errorContainer': scheme.errorContainer,
    'onErrorContainer': scheme.onErrorContainer,
    'surface': scheme.surface,
    'onSurface': scheme.onSurface,
    'surfaceContainerLowest': scheme.surfaceContainerLowest,
    'surfaceContainerLow': scheme.surfaceContainerLow,
    'surfaceContainer': scheme.surfaceContainer,
    'surfaceContainerHigh': scheme.surfaceContainerHigh,
    'surfaceContainerHighest': scheme.surfaceContainerHighest,
    'onSurfaceVariant': scheme.onSurfaceVariant,
    'outline': scheme.outline,
    'outlineVariant': scheme.outlineVariant,
    'inverseSurface': scheme.inverseSurface,
    'onInverseSurface': scheme.onInverseSurface,
    'inversePrimary': scheme.inversePrimary,
  };
  for (final MapEntry<String, Color> role in roles.entries) {
    if (role.value.toARGB32() == color.toARGB32()) {
      return role.key;
    }
  }
  // A translucent color is often a role at a reduced opacity — M3 spells its
  // disabled and state-layer values exactly that way ("onSurface at 12%").
  // Naming it that way keeps a register entry readable and stable across color
  // schemes, where the raw hex would be neither.
  //
  // Two guards keep that name honest. A role name is only used when exactly
  // ONE role carries the opaque color, since picking whichever came first out
  // of several would attach an arbitrary name. And pure black or pure white at
  // a reduced alpha is never named at all: those are the framework's own ink
  // constants (`ThemeData.focusColor`, `hoverColor` and `splashColor` are all
  // black or white with an alpha), and a scheme whose `onSecondary` happens to
  // be black would otherwise turn "the focus highlight" into "onSecondary at
  // 12%", which is a different statement about a color that only coincides.
  final int alpha = (color.a * 255).round();
  final int opaque = color.withValues(alpha: 1.0).toARGB32();
  const int black = 0xFF000000;
  const int white = 0xFFFFFFFF;
  if (alpha != 0xFF && opaque != black && opaque != white) {
    final List<String> matches = roles.entries
        .where(
          (MapEntry<String, Color> role) =>
              role.value.withValues(alpha: 1.0).toARGB32() == opaque,
        )
        .map((MapEntry<String, Color> role) => role.key)
        .toList();
    if (matches.length == 1) {
      return '${matches.single} @ ${(alpha * 100 / 255).round()}%';
    }
  }
  final String hex = color
      .toARGB32()
      .toRadixString(16)
      .padLeft(8, '0')
      .toUpperCase();
  return '#$hex';
}

/// Normalises an oracle [shape] to a corner radius in dp so it can be
/// compared against a measured BorderRadius. A StadiumBorder is fully
/// rounded, i.e. half the container height.
double m3CornerRadius(OutlinedBorder shape, {required double containerHeight}) {
  if (shape is StadiumBorder) {
    return containerHeight / 2;
  }
  if (shape is RoundedRectangleBorder) {
    final BorderRadiusGeometry radius = shape.borderRadius;
    if (radius is BorderRadius) {
      return radius.topLeft.x;
    }
  }
  throw ArgumentError('Unsupported oracle shape: $shape');
}

/// Moves a mouse pointer over [finder] and settles, driving the hovered
/// state. The returned gesture can be moved away again; the pointer is
/// removed automatically at test teardown.
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

/// Moves a mouse pointer over [finder], evaluates [measure] while it is there
/// and takes the pointer away again.
///
/// A conformance test hovers twice — once on the oracle, once on the Base
/// component — and the two runs share one mouse device, so the pointer of the
/// first hover has to be gone before the second one is added. [hoverOver]
/// keeps its pointer until teardown and is therefore only usable once per
/// test; this is the two-sided form.
Future<T> whileHovering<T>(
  WidgetTester tester,
  Finder finder,
  T Function() measure,
) async {
  final TestGesture gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  await gesture.addPointer(location: Offset.zero);
  await tester.pump();
  await gesture.moveTo(tester.getCenter(finder));
  await tester.pumpAndSettle();
  final T measured = measure();
  await gesture.removePointer();
  await tester.pumpAndSettle();
  return measured;
}

/// Presses [finder] and holds, pumping long enough for the pressed state
/// layer/ripple to become measurable. The caller MUST end the interaction
/// with `await gesture.up()` followed by a pump.
Future<TestGesture> pressAndHold(WidgetTester tester, Finder finder) async {
  final TestGesture gesture = await tester.startGesture(
    tester.getCenter(finder),
  );
  await tester.pump(const Duration(milliseconds: 200));
  return gesture;
}

/// Drives keyboard focus onto the first focusable control by sending Tab,
/// the way a keyboard user reaches it.
Future<void> focusFirstWithTab(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pumpAndSettle();
}

/// The render object that paints ink (state layers, ripples). Assert on it
/// with the `paints` matcher, e.g.
/// `expect(inkFeatures(tester), paints..rect(color: overlay))`.
/// Same idiom as flutter/test/material/ink_well_test.dart.
RenderObject inkFeatures(WidgetTester tester) {
  return tester.allRenderObjects.firstWhere(
    (RenderObject renderObject) =>
        renderObject.runtimeType.toString() == '_RenderInkFeatures',
  );
}

/// Every fill color the ink layer paints right now, in paint order.
///
/// State layers are painted ink rather than widget properties, so the only
/// way to *measure* one (as opposed to asserting it with the `paints`
/// matcher) is to replay the ink render object onto a recording canvas and
/// read the colors back out. The recording covers the whole subtree below
/// the ink layer, which is exactly what [inkColorsAddedBy] needs to diff.
List<Color> paintedInkColors(WidgetTester tester) {
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  final TestRecordingPaintingContext context = TestRecordingPaintingContext(
    canvas,
  );
  inkFeatures(tester).paint(context, Offset.zero);
  const Set<Symbol> fillCalls = <Symbol>{
    #drawRect,
    #drawRRect,
    #drawDRRect,
    #drawPath,
    #drawCircle,
    #drawOval,
  };
  final List<Color> colors = <Color>[];
  for (final RecordedInvocation recorded in canvas.invocations) {
    final Invocation invocation = recorded.invocation;
    if (!invocation.isMethod || !fillCalls.contains(invocation.memberName)) {
      continue;
    }
    for (final Object? argument in invocation.positionalArguments) {
      if (argument is Paint) {
        colors.add(argument.color);
      }
    }
  }
  return colors;
}

/// The colors that appear in the ink layer only after [drive] has run —
/// i.e. the state layer that driving the state added.
///
/// Diffing against the resting frame is what makes the probe symmetric: it
/// works the same on a Base component and on the SDK widget it is measured
/// against, and it reports a hand-painted container swap (a *new container
/// color*) just as faithfully as a real state layer, which is precisely the
/// distinction this suite has to detect.
Future<List<Color>> inkColorsAddedBy(
  WidgetTester tester,
  Future<void> Function() drive,
) async {
  final List<Color> before = paintedInkColors(tester);
  await drive();
  final List<Color> after = paintedInkColors(tester);
  final List<Color> added = <Color>[];
  final List<Color> remaining = List<Color>.of(before);
  for (final Color color in after) {
    if (!remaining.remove(color)) {
      added.add(color);
    }
  }
  return added;
}

/// The ink the layer gains while [finder] is hovered, with the pointer
/// removed again so a later pump in the same test starts clean.
Future<List<Color>> hoverStateLayer(WidgetTester tester, Finder finder) async {
  final TestGesture gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  await gesture.addPointer(location: Offset.zero);
  await tester.pump();
  final List<Color> added = await inkColorsAddedBy(tester, () async {
    await gesture.moveTo(tester.getCenter(finder));
    await tester.pumpAndSettle();
  });
  await gesture.removePointer();
  await tester.pumpAndSettle();
  return added;
}

/// The ink the layer gains while [finder] is held pressed, with the gesture
/// released again.
Future<List<Color>> pressStateLayer(WidgetTester tester, Finder finder) async {
  late TestGesture gesture;
  final List<Color> added = await inkColorsAddedBy(tester, () async {
    gesture = await pressAndHold(tester, finder);
    // pressAndHold's pump only starts the highlight's fade-in ticker (its
    // first tick is at elapsed zero); one more pump completes the fade.
    await tester.pump(const Duration(milliseconds: 200));
  });
  await gesture.up();
  await tester.pumpAndSettle();
  return added;
}

/// The ink the layer gains once Tab has moved keyboard focus. A component
/// that deliberately refuses focus (because its collection owns the Tab stop)
/// adds nothing, which is exactly the measurement a deviation documents.
Future<List<Color>> focusStateLayer(WidgetTester tester) async {
  return inkColorsAddedBy(tester, () => focusFirstWithTab(tester));
}

/// Renders a measured state layer as a stable descriptor: role names where a
/// color is a scheme role, `#AARRGGBB` otherwise, and `none` for a component
/// that paints no layer at all.
String describeStateLayer(WidgetTester tester, List<Color> colors) {
  if (colors.isEmpty) {
    return 'none';
  }
  final ColorScheme scheme = Theme.of(
    tester.element(find.byType(Scaffold)),
  ).colorScheme;
  return colors.map((Color color) => colorRoleName(scheme, color)).join(' + ');
}

/// Replays every render object under [finder] onto a recording canvas and
/// returns the calls it made, so a painted-only property (a border, a corner
/// radius, a fill) can be *measured* instead of merely asserted.
///
/// Input components need this because their visual container is drawn by
/// `InputDecorator`'s border painter rather than exposed as widget state: the
/// SDK resolves the border for the current widget state deep inside
/// `_InputDecoratorState`, so reading the widget's `decoration` would compare
/// what each side *asked for* (null on the oracle) instead of what both sides
/// actually render.
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

/// Every stroked outline painted under [finder], as the [BorderSide] it was
/// drawn with — `BorderSide.toPaint()` is exactly how a Material border turns
/// its color and width into a stroke, so reading them back reconstructs the
/// side. A side of `BorderSide.none` means "painted nothing visible".
List<BorderSide> paintedBorderSides(WidgetTester tester, Finder finder) {
  final List<BorderSide> sides = <BorderSide>[];
  for (final RecordedInvocation recorded in _recordPaint(tester, finder)) {
    final Invocation invocation = recorded.invocation;
    if (!invocation.isMethod) {
      continue;
    }
    for (final Object? argument in invocation.positionalArguments) {
      if (argument is Paint && argument.style == PaintingStyle.stroke) {
        sides.add(
          BorderSide(color: argument.color, width: argument.strokeWidth),
        );
      }
    }
  }
  return sides;
}

/// Every filled area painted under [finder], as the color it was filled with,
/// in paint order. An `InputDecorator` paints its container fill from the same
/// painter that draws its border, so this is the only place a filled field's
/// resolved fill color can be read.
List<Color> paintedFillColors(WidgetTester tester, Finder finder) {
  final List<Color> colors = <Color>[];
  for (final RecordedInvocation recorded in _recordPaint(tester, finder)) {
    final Invocation invocation = recorded.invocation;
    if (!invocation.isMethod) {
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

/// Every rounded rectangle painted under [finder], in paint order. The corner
/// radii of a component whose shape is decided by the SDK — an
/// `InputDecorator`'s border, for instance — can only be read here.
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

/// The `CustomPaint` that draws an `InputDecorator`'s border, i.e. the visual
/// container of every input component.
///
/// It is matched by its painter type rather than by position: a field with an
/// icon button in its suffix slot contains several `CustomPaint`s, and the
/// first one in tree order is not necessarily the border.
Finder inputBorderPainter(Finder field) {
  return find.descendant(
    of: field,
    matching: find.byWidgetPredicate(
      (Widget widget) =>
          widget is CustomPaint &&
          widget.foregroundPainter.runtimeType.toString() ==
              '_InputBorderPainter',
      description: "InputDecorator's border painter",
    ),
  );
}

/// The size of an input component's visual container — the bordered box,
/// without the helper/error line an `InputDecorator` renders underneath it.
Size inputContainerSize(WidgetTester tester, Finder field) {
  return tester.getSize(inputBorderPainter(field));
}

/// The border an input component paints right now, as the [BorderSide] it was
/// drawn with, or [BorderSide.none] when it paints no outline at all.
BorderSide inputBorderSide(WidgetTester tester, Finder field) {
  final List<BorderSide> sides = paintedBorderSides(
    tester,
    inputBorderPainter(field),
  );
  return sides.isEmpty ? BorderSide.none : sides.first;
}

/// The corner radius of an input component's container.
///
/// The radius is read off the painted rounded rectangle and corrected back to
/// the container's own corner: a stroked border paints its path along the
/// centre of the stroke, so the painted rectangle is inset by half the border
/// width on every side, and a 1 dp border therefore paints a 4 dp corner as
/// 3.5. Undoing that inset makes an outlined field and a filled one — whose
/// shape is painted as a fill, with no inset at all — directly comparable.
double inputCornerRadius(WidgetTester tester, Finder field) {
  final Finder painter = inputBorderPainter(field);
  final List<RRect> rects = paintedRRects(tester, painter);
  if (rects.isEmpty) {
    fail('The input component under $field painted no rounded rectangle.');
  }
  final double inset =
      (tester.getSize(painter).height - rects.first.height) / 2;
  return rects.first.tlRadiusX + inset;
}

/// The bottom corner radius of an input component's container, corrected the
/// same way as [inputCornerRadius]. Material 3's filled field rounds only its
/// top corners, so the bottom pair is what distinguishes the two shapes.
double inputBottomCornerRadius(WidgetTester tester, Finder field) {
  final Finder painter = inputBorderPainter(field);
  final List<RRect> rects = paintedRRects(tester, painter);
  if (rects.isEmpty) {
    fail('The input component under $field painted no rounded rectangle.');
  }
  final double inset =
      (tester.getSize(painter).height - rects.first.height) / 2;
  return rects.first.blRadiusX + inset;
}

/// Renders a border as a stable descriptor — `role width dp`, or `none` — so a
/// component's outline in one state can be compared and registered as a single
/// value instead of as two loosely coupled ones.
String describeBorderSide(ColorScheme scheme, BorderSide side) {
  if (side.style == BorderStyle.none || side.width == 0) {
    return 'none';
  }
  return '${colorRoleName(scheme, side.color)} ${side.width} dp';
}

/// The size an icon really renders at: its own, or the one its enclosing
/// [IconTheme] hands down.
///
/// Both sides of a comparison go through this, so an explicitly sized icon
/// (what the Base components pass) and a theme-sized one (what the SDK
/// components rely on) are described the same way. Measuring the icon's
/// layout box instead would report the 48 dp minimum-touch box that
/// `InputDecorator` wraps a prefix icon in, not the glyph.
double effectiveIconSize(WidgetTester tester, Finder finder) {
  final Icon icon = tester.widget<Icon>(finder);
  return icon.size ?? IconTheme.of(tester.element(finder)).size!;
}

/// All fifteen Material 3 text roles of [textTheme], keyed by role name, in
/// the M3 type-scale order. Shared by [describeTextRole] and the typography
/// conformance suite so role iteration cannot drift between the two.
Map<String, TextStyle?> textThemeRoles(TextTheme textTheme) {
  return <String, TextStyle?>{
    'displayLarge': textTheme.displayLarge,
    'displayMedium': textTheme.displayMedium,
    'displaySmall': textTheme.displaySmall,
    'headlineLarge': textTheme.headlineLarge,
    'headlineMedium': textTheme.headlineMedium,
    'headlineSmall': textTheme.headlineSmall,
    'titleLarge': textTheme.titleLarge,
    'titleMedium': textTheme.titleMedium,
    'titleSmall': textTheme.titleSmall,
    'labelLarge': textTheme.labelLarge,
    'labelMedium': textTheme.labelMedium,
    'labelSmall': textTheme.labelSmall,
    'bodyLarge': textTheme.bodyLarge,
    'bodyMedium': textTheme.bodyMedium,
    'bodySmall': textTheme.bodySmall,
  };
}

/// Maps [style] onto the theme's TextTheme role it corresponds to, matching
/// on the metric triple (fontSize, letterSpacing, height) so color/weight
/// copies still resolve to their role. Returns a stable descriptor string
/// used for typography conformance comparisons.
String describeTextRole(ThemeData theme, TextStyle? style) {
  if (style == null) {
    return 'no explicit style (inherits DefaultTextStyle)';
  }
  for (final MapEntry<String, TextStyle?> role in textThemeRoles(
    theme.textTheme,
  ).entries) {
    final TextStyle? candidate = role.value;
    if (candidate == null) {
      continue;
    }
    if (_sameMetric(candidate.fontSize, style.fontSize) &&
        _sameMetric(candidate.letterSpacing, style.letterSpacing) &&
        _sameMetric(candidate.height, style.height)) {
      return '${role.key} (fontSize ${style.fontSize}, '
          'weight ${style.fontWeight ?? 'inherit'})';
    }
  }
  return 'unmapped role (fontSize ${style.fontSize}, '
      'letterSpacing ${style.letterSpacing}, height ${style.height})';
}

bool _sameMetric(double? a, double? b) {
  if (a == null || b == null) {
    return a == b;
  }
  return (a - b).abs() < 0.01;
}
