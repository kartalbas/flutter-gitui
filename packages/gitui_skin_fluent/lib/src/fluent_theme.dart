import 'package:flutter/widgets.dart';

import 'fluent_accent.dart';
import 'fluent_resources.dart';

/// What the colour side of this skin resolves against: a brightness, the
/// WinUI resource dictionary for it, and the accent swatch.
final class FluentThemeData {
  const FluentThemeData({
    required this.brightness,
    required this.resources,
    required this.accent,
  });

  /// The light theme with the Windows default accent.
  const FluentThemeData.light()
    : brightness = Brightness.light,
      resources = const FluentResources.light(),
      accent = const FluentAccent.windowsDefault();

  /// The dark theme with the Windows default accent.
  const FluentThemeData.dark()
    : brightness = Brightness.dark,
      resources = const FluentResources.dark(),
      accent = const FluentAccent.windowsDefault();

  /// Which of the two resource dictionaries is in force.
  final Brightness brightness;

  /// The WinUI resource slice for [brightness].
  final FluentResources resources;

  /// The accent swatch. Today always the Windows default; the mapping of
  /// `SkinRequest.accentSeed` onto a swatch is the colour facet's work and
  /// lands with it.
  final FluentAccent accent;
}

/// Where [FluentThemeData] lives while this skin is drawing.
///
/// A plain inherited widget, deliberately: the reference's `FluentTheme` is
/// an `InheritedTheme` with no app-level obligations (fluent_ui@4.16.1
/// lib/src/styles/theme.dart), which is exactly what lets a skin own its own
/// scope instead of claiming the application root. `chrome.wrapRoot` will
/// install this once; until then the behaviour harness installs it the same
/// way.
final class FluentTheme extends InheritedWidget {
  /// Installs [data] over [child].
  const FluentTheme({super.key, required this.data, required super.child});

  /// The values in force below this widget.
  final FluentThemeData data;

  /// The theme at [context]. A Fluent widget outside a [FluentTheme] is a
  /// wiring error, not a state to style for.
  static FluentThemeData of(BuildContext context) {
    final FluentTheme? scope = context
        .dependOnInheritedWidgetOfExactType<FluentTheme>();
    assert(
      scope != null,
      'FluentTheme.of() called outside a FluentTheme scope. Every Fluent '
      'widget draws from the resource dictionary, so the scope must be '
      'installed above it (chrome.wrapRoot in the application, '
      'pumpFluentBehavior in a test).',
    );
    return scope!.data;
  }

  @override
  bool updateShouldNotify(covariant FluentTheme oldWidget) =>
      oldWidget.data != data;
}
