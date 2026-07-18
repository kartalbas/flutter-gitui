/// Application asset path constants
///
/// Note: Assets are not currently configured in pubspec.yaml.
/// These constants are provided for when assets are added.
class AppAssets {
  // Images
  static const String imagesPath = 'assets/images/';
  static const String logoPath = '${imagesPath}logo.png';
  static const String emptyStatePath = '${imagesPath}empty_state.svg';
  static const String errorImagePath = '${imagesPath}error.svg';
  static const String noResultsPath = '${imagesPath}no_results.svg';

  // Icons
  static const String iconsPath = 'assets/icons/';
  static const String appIconPath = '${iconsPath}app_icon.png';

  // Fonts (using Google Fonts package instead)
  static const String fontsPath = 'assets/fonts/';

  // Other assets
  static const String dataPath = 'assets/data/';

  // Private constructor to prevent instantiation
  AppAssets._();
}
