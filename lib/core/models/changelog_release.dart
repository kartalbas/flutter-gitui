import 'package:freezed_annotation/freezed_annotation.dart';

part 'changelog_release.freezed.dart';
part 'changelog_release.g.dart';

@freezed
class ChangelogData with _$ChangelogData {
  const factory ChangelogData({
    required List<ChangelogRelease> releases,
  }) = _ChangelogData;

  factory ChangelogData.fromJson(Map<String, dynamic> json) =>
      _$ChangelogDataFromJson(json);
}

@freezed
class ChangelogRelease with _$ChangelogRelease {
  const factory ChangelogRelease({
    required String version,
    required String date,
    required String changelog,
    required String commit,
  }) = _ChangelogRelease;

  factory ChangelogRelease.fromJson(Map<String, dynamic> json) =>
      _$ChangelogReleaseFromJson(json);
}
