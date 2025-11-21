// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'changelog_release.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChangelogDataImpl _$$ChangelogDataImplFromJson(Map<String, dynamic> json) =>
    _$ChangelogDataImpl(
      releases: (json['releases'] as List<dynamic>)
          .map((e) => ChangelogRelease.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$ChangelogDataImplToJson(_$ChangelogDataImpl instance) =>
    <String, dynamic>{'releases': instance.releases};

_$ChangelogReleaseImpl _$$ChangelogReleaseImplFromJson(
  Map<String, dynamic> json,
) => _$ChangelogReleaseImpl(
  version: json['version'] as String,
  date: json['date'] as String,
  changelog: json['changelog'] as String,
  commit: json['commit'] as String,
);

Map<String, dynamic> _$$ChangelogReleaseImplToJson(
  _$ChangelogReleaseImpl instance,
) => <String, dynamic>{
  'version': instance.version,
  'date': instance.date,
  'changelog': instance.changelog,
  'commit': instance.commit,
};
