/// Constants related to UI sizing and dimensions
class UIConstants {
  // List item heights
  static const double listItemHeight = 72.0;
  static const double compactListItemHeight = 48.0;
  static const double commitListItemHeight = 64.0;

  // Icon sizes
  static const double iconSizeXLarge = 64.0;
  static const double iconSizeLarge = 32.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeSmall = 16.0;
  static const double iconSizeXSmall = 12.0;

  // Panel dimensions
  static const double minPanelWidth = 200.0;
  static const double maxPanelWidth = 800.0;
  static const double defaultPanelWidth = 400.0;
  static const double commandLogMinWidth = 300.0;
  static const double commandLogDefaultWidth = 500.0;

  // Tree view
  static const double treeIndentWidth = 24.0;
  static const double treeItemHeight = 32.0;

  // Diff viewer
  static const double diffLineHeight = 20.0;
  static const double diffGutterWidth = 60.0;

  // Animations
  static const Duration shortAnimationDuration = Duration(milliseconds: 150);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);

  // Loading indicators
  static const Duration minLoadingDuration = Duration(milliseconds: 500);

  // Repository cards
  static const double repositoryCardMinWidth = 250.0;
  static const double repositoryCardMaxWidth = 350.0;
  static const double repositoryCardHeight = 200.0;

  // Avatars
  static const double avatarSizeLarge = 48.0;
  static const double avatarSizeMedium = 32.0;
  static const double avatarSizeSmall = 24.0;

  // Private constructor to prevent instantiation
  UIConstants._();
}
