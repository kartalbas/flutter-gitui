/// Auto-generated build information
/// This file is generated during the build process
/// DO NOT EDIT MANUALLY
class BuildInfo {
  static const String buildCommit = String.fromEnvironment('BUILD_COMMIT', defaultValue: 'unknown');
  static const String buildDate = String.fromEnvironment('BUILD_DATE', defaultValue: 'unknown');
  static const bool isReleaseBuild = bool.fromEnvironment('dart.vm.product');

  static String get displayCommit => buildCommit == 'unknown' ? 'dev' : buildCommit;
  static String get displayDate => buildDate == 'unknown' ? '' : buildDate;
}
