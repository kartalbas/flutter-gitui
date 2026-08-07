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
/// value, or an `#AARRGGBB` literal when no role matches (state layers and
/// disabled colors, which are role colors with a reduced alpha, land here).
///
/// Both sides of a conformance comparison go through this function, so a
/// registered deviation can document a foreground as a stable role name
/// (`primary`, `onSurface`) instead of a scheme-dependent hex value, and an
/// alpha-modified color still compares exactly via the quantised literal.
String colorRoleName(ColorScheme scheme, Color color) {
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
    if (role.value == color) {
      return role.key;
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
