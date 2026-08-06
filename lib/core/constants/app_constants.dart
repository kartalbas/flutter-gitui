/// General application-level constants
///
/// Every member here has at least one reader. A constant nobody reads is worse
/// than no constant: it invites the next author to trust a value the app does
/// not actually use, which is how `appVersion` came to claim 1.0.0 while the
/// app shipped 0.5.x.
class AppConstants {
  // App metadata. The version is deliberately absent: it is read from the
  // package at runtime, so a second copy here could only ever be wrong.
  static const String appName = 'Flutter GitUI';

  // Window sizing. Consumed by the window_manager setup in main.dart.
  static const double minWindowWidth = 800;
  static const double minWindowHeight = 600;

  /// FHD (1920x1080) minus ten percent, so the window still shows its own
  /// chrome and the taskbar on a 1080p display.
  static const double defaultWindowWidth = 1728;
  static const double defaultWindowHeight = 972;

  // Dialog sizing
  static const double maxDialogWidth = 800;
  static const double defaultDialogWidth = 650;
  static const double minDialogWidth = 300;

  // Debouncing & timing
  static const Duration debounceMilliseconds = Duration(milliseconds: 300);

  /// Upper bound on matches a whole-history search returns. Bounds both the
  /// git process output and the widget count; the results banner says when
  /// the cap was hit.
  static const int deepSearchResultLimit = 1000;

  // Private constructor to prevent instantiation
  AppConstants._();
}
