/// Application route constants
///
/// Note: This app uses go_router for navigation.
/// These constants are provided for route path references.
class AppRoutes {
  // Main navigation routes
  static const String workspaces = '/workspaces';
  static const String repositories = '/repositories';
  static const String repository = '/repository';
  static const String changes = '/changes';
  static const String history = '/history';
  static const String browse = '/browse';
  static const String branches = '/branches';
  static const String remotes = '/remotes';
  static const String stashes = '/stashes';
  static const String tags = '/tags';
  static const String settings = '/settings';

  // Query parameters
  static const String paramRepositoryId = 'repositoryId';
  static const String paramWorkspaceId = 'workspaceId';
  static const String paramBranchName = 'branchName';
  static const String paramCommitHash = 'commitHash';
  static const String paramFilePath = 'filePath';

  // Private constructor to prevent instantiation
  AppRoutes._();
}
