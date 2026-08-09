import 'dart:ui';

/// The accent colour, as Windows carries it: a seven-stop swatch, with the
/// stop - not the base colour - chosen per brightness and per state.
///
/// WinUI never paints "the accent colour" directly. A control picks a stop
/// (`AccentColorDark1` on light, `AccentColorLight2` on dark) and then dims
/// it by opacity for hover and press. Both halves of that behaviour live
/// here, so a control can only ask for a brush and never invent a stop.
final class FluentAccent {
  const FluentAccent({
    required this.darkest,
    required this.darker,
    required this.dark,
    required this.normal,
    required this.light,
    required this.lighter,
    required this.lightest,
  });

  /// The Windows default accent swatch ("blue", #0078D4 at its base).
  ///
  /// Values: fluent_ui@4.16.1 lib/src/styles/color.dart:168-176
  /// (`Colors.blue`), the checkout's transcription of the Windows 11 default
  /// accent ramp.
  const FluentAccent.windowsDefault()
    : darkest = const Color(0xff004a83), // color.dart:169
      darker = const Color(0xff005494), // color.dart:170
      dark = const Color(0xff0066b4), // color.dart:171
      normal = const Color(0xff0078d4), // color.dart:172
      light = const Color(0xff268cda), // color.dart:173
      lighter = const Color(0xff4ca0e0), // color.dart:174
      lightest = const Color(0xff60abe4); // color.dart:175

  /// AccentColorDark3.
  final Color darkest;

  /// AccentColorDark2.
  final Color darker;

  /// AccentColorDark1.
  final Color dark;

  /// The system accent colour itself.
  final Color normal;

  /// AccentColorLight1.
  final Color light;

  /// AccentColorLight2.
  final Color lighter;

  /// AccentColorLight3.
  final Color lightest;

  /// The resting accent fill: Dark1 on a light ground, Light2 on a dark one.
  ///
  /// fluent_ui@4.16.1 lib/src/styles/color.dart:347-352
  /// (`AccentColor.defaultBrushFor`), which cites microsoft-ui-xaml
  /// Common_themeresources_any.xaml L163-166 (AccentFillColorDefaultBrush).
  Color defaultBrushFor(Brightness brightness) {
    return switch (brightness) {
      Brightness.light => dark,
      Brightness.dark => lighter,
    };
  }

  /// The hover accent fill: the resting brush at 90% opacity
  /// (AccentFillColorSecondaryBrush, Opacity 0.9).
  ///
  /// fluent_ui@4.16.1 lib/src/styles/color.dart:358-360; microsoft-ui-xaml
  /// Common_themeresources_any.xaml L163-166.
  Color secondaryBrushFor(Brightness brightness) {
    return defaultBrushFor(brightness).withValues(alpha: 0.9);
  }

  /// The pressed accent fill: the resting brush at 80% opacity
  /// (AccentFillColorTertiaryBrush, Opacity 0.8). Pressing an accent control
  /// therefore FADES it toward the ground rather than tinting it - the
  /// opposite family of gesture from Material's white pressed overlay.
  ///
  /// fluent_ui@4.16.1 lib/src/styles/color.dart:366-368; microsoft-ui-xaml
  /// Common_themeresources_any.xaml L163-166.
  Color tertiaryBrushFor(Brightness brightness) {
    return defaultBrushFor(brightness).withValues(alpha: 0.8);
  }
}
