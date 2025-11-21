/// Constants related to Git operations
class GitConstants {
  // Commit limits
  static const int defaultCommitLimit = 100;
  static const int maxCommitLimit = 10000;
  static const int minCommitLimit = 10;

  // File sizes
  static const int maxDiffSizeBytes = 1024 * 1024; // 1MB
  static const int maxPreviewSizeBytes = 512 * 1024; // 512KB
  static const int maxTextFileSizeBytes = 5 * 1024 * 1024; // 5MB

  // Timeouts
  static const Duration gitCommandTimeout = Duration(minutes: 5);
  static const Duration shortCommandTimeout = Duration(seconds: 30);
  static const Duration longCommandTimeout = Duration(minutes: 10);

  // Auto-fetch
  static const Duration defaultAutoFetchInterval = Duration(minutes: 5);
  static const Duration minAutoFetchInterval = Duration(minutes: 1);
  static const Duration maxAutoFetchInterval = Duration(hours: 1);

  // Search
  static const int maxSearchHistory = 20;
  static const int maxSearchResults = 1000;

  // Branch names
  static const int maxBranchNameLength = 255;

  // Commit messages
  static const int maxCommitMessageLength = 72; // For subject line
  static const int recommendedCommitMessageLength = 50;

  // Private constructor to prevent instantiation
  GitConstants._();
}
