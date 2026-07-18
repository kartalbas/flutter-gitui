/// General application-level constants
class AppConstants {
  // App metadata
  static const String appName = 'Flutter GitUI';
  static const String appVersion = '1.0.0';
  static const int appBuildNumber = 1;

  // Window sizing
  static const double minWindowWidth = 800;
  static const double minWindowHeight = 600;
  static const double defaultWindowWidth = 1280;
  static const double defaultWindowHeight = 720;

  // Dialog sizing
  static const double maxDialogWidth = 800;
  static const double defaultDialogWidth = 650;
  static const double minDialogWidth = 300;

  // Debouncing & timing
  static const Duration debounceMilliseconds = Duration(milliseconds: 300);
  static const Duration shortDelay = Duration(milliseconds: 100);
  static const Duration mediumDelay = Duration(milliseconds: 300);
  static const Duration longDelay = Duration(milliseconds: 500);

  // Pagination
  static const int defaultPageSize = 50;
  static const int maxPageSize = 1000;
  static const int minPageSize = 10;

  // Recent items
  static const int maxRecentRepositories = 10;
  static const int maxRecentWorkspaces = 5;
  static const int maxRecentSearches = 20;

  // Performance
  static const int maxCachedItems = 100;
  static const Duration cacheExpiration = Duration(minutes: 15);

  // Private constructor to prevent instantiation
  AppConstants._();
}
