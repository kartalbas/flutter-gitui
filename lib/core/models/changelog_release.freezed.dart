// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'changelog_release.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ChangelogData _$ChangelogDataFromJson(Map<String, dynamic> json) {
  return _ChangelogData.fromJson(json);
}

/// @nodoc
mixin _$ChangelogData {
  List<ChangelogRelease> get releases => throw _privateConstructorUsedError;

  /// Serializes this ChangelogData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChangelogData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChangelogDataCopyWith<ChangelogData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChangelogDataCopyWith<$Res> {
  factory $ChangelogDataCopyWith(
    ChangelogData value,
    $Res Function(ChangelogData) then,
  ) = _$ChangelogDataCopyWithImpl<$Res, ChangelogData>;
  @useResult
  $Res call({List<ChangelogRelease> releases});
}

/// @nodoc
class _$ChangelogDataCopyWithImpl<$Res, $Val extends ChangelogData>
    implements $ChangelogDataCopyWith<$Res> {
  _$ChangelogDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChangelogData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? releases = null}) {
    return _then(
      _value.copyWith(
            releases: null == releases
                ? _value.releases
                : releases // ignore: cast_nullable_to_non_nullable
                      as List<ChangelogRelease>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ChangelogDataImplCopyWith<$Res>
    implements $ChangelogDataCopyWith<$Res> {
  factory _$$ChangelogDataImplCopyWith(
    _$ChangelogDataImpl value,
    $Res Function(_$ChangelogDataImpl) then,
  ) = __$$ChangelogDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<ChangelogRelease> releases});
}

/// @nodoc
class __$$ChangelogDataImplCopyWithImpl<$Res>
    extends _$ChangelogDataCopyWithImpl<$Res, _$ChangelogDataImpl>
    implements _$$ChangelogDataImplCopyWith<$Res> {
  __$$ChangelogDataImplCopyWithImpl(
    _$ChangelogDataImpl _value,
    $Res Function(_$ChangelogDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ChangelogData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? releases = null}) {
    return _then(
      _$ChangelogDataImpl(
        releases: null == releases
            ? _value._releases
            : releases // ignore: cast_nullable_to_non_nullable
                  as List<ChangelogRelease>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ChangelogDataImpl implements _ChangelogData {
  const _$ChangelogDataImpl({required final List<ChangelogRelease> releases})
    : _releases = releases;

  factory _$ChangelogDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChangelogDataImplFromJson(json);

  final List<ChangelogRelease> _releases;
  @override
  List<ChangelogRelease> get releases {
    if (_releases is EqualUnmodifiableListView) return _releases;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_releases);
  }

  @override
  String toString() {
    return 'ChangelogData(releases: $releases)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChangelogDataImpl &&
            const DeepCollectionEquality().equals(other._releases, _releases));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_releases));

  /// Create a copy of ChangelogData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChangelogDataImplCopyWith<_$ChangelogDataImpl> get copyWith =>
      __$$ChangelogDataImplCopyWithImpl<_$ChangelogDataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChangelogDataImplToJson(this);
  }
}

abstract class _ChangelogData implements ChangelogData {
  const factory _ChangelogData({
    required final List<ChangelogRelease> releases,
  }) = _$ChangelogDataImpl;

  factory _ChangelogData.fromJson(Map<String, dynamic> json) =
      _$ChangelogDataImpl.fromJson;

  @override
  List<ChangelogRelease> get releases;

  /// Create a copy of ChangelogData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChangelogDataImplCopyWith<_$ChangelogDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ChangelogRelease _$ChangelogReleaseFromJson(Map<String, dynamic> json) {
  return _ChangelogRelease.fromJson(json);
}

/// @nodoc
mixin _$ChangelogRelease {
  String get version => throw _privateConstructorUsedError;
  String get date => throw _privateConstructorUsedError;
  String get changelog => throw _privateConstructorUsedError;
  String get commit => throw _privateConstructorUsedError;

  /// Serializes this ChangelogRelease to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChangelogRelease
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChangelogReleaseCopyWith<ChangelogRelease> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChangelogReleaseCopyWith<$Res> {
  factory $ChangelogReleaseCopyWith(
    ChangelogRelease value,
    $Res Function(ChangelogRelease) then,
  ) = _$ChangelogReleaseCopyWithImpl<$Res, ChangelogRelease>;
  @useResult
  $Res call({String version, String date, String changelog, String commit});
}

/// @nodoc
class _$ChangelogReleaseCopyWithImpl<$Res, $Val extends ChangelogRelease>
    implements $ChangelogReleaseCopyWith<$Res> {
  _$ChangelogReleaseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChangelogRelease
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? version = null,
    Object? date = null,
    Object? changelog = null,
    Object? commit = null,
  }) {
    return _then(
      _value.copyWith(
            version: null == version
                ? _value.version
                : version // ignore: cast_nullable_to_non_nullable
                      as String,
            date: null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as String,
            changelog: null == changelog
                ? _value.changelog
                : changelog // ignore: cast_nullable_to_non_nullable
                      as String,
            commit: null == commit
                ? _value.commit
                : commit // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ChangelogReleaseImplCopyWith<$Res>
    implements $ChangelogReleaseCopyWith<$Res> {
  factory _$$ChangelogReleaseImplCopyWith(
    _$ChangelogReleaseImpl value,
    $Res Function(_$ChangelogReleaseImpl) then,
  ) = __$$ChangelogReleaseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String version, String date, String changelog, String commit});
}

/// @nodoc
class __$$ChangelogReleaseImplCopyWithImpl<$Res>
    extends _$ChangelogReleaseCopyWithImpl<$Res, _$ChangelogReleaseImpl>
    implements _$$ChangelogReleaseImplCopyWith<$Res> {
  __$$ChangelogReleaseImplCopyWithImpl(
    _$ChangelogReleaseImpl _value,
    $Res Function(_$ChangelogReleaseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ChangelogRelease
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? version = null,
    Object? date = null,
    Object? changelog = null,
    Object? commit = null,
  }) {
    return _then(
      _$ChangelogReleaseImpl(
        version: null == version
            ? _value.version
            : version // ignore: cast_nullable_to_non_nullable
                  as String,
        date: null == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as String,
        changelog: null == changelog
            ? _value.changelog
            : changelog // ignore: cast_nullable_to_non_nullable
                  as String,
        commit: null == commit
            ? _value.commit
            : commit // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ChangelogReleaseImpl implements _ChangelogRelease {
  const _$ChangelogReleaseImpl({
    required this.version,
    required this.date,
    required this.changelog,
    required this.commit,
  });

  factory _$ChangelogReleaseImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChangelogReleaseImplFromJson(json);

  @override
  final String version;
  @override
  final String date;
  @override
  final String changelog;
  @override
  final String commit;

  @override
  String toString() {
    return 'ChangelogRelease(version: $version, date: $date, changelog: $changelog, commit: $commit)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChangelogReleaseImpl &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.changelog, changelog) ||
                other.changelog == changelog) &&
            (identical(other.commit, commit) || other.commit == commit));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, version, date, changelog, commit);

  /// Create a copy of ChangelogRelease
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChangelogReleaseImplCopyWith<_$ChangelogReleaseImpl> get copyWith =>
      __$$ChangelogReleaseImplCopyWithImpl<_$ChangelogReleaseImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ChangelogReleaseImplToJson(this);
  }
}

abstract class _ChangelogRelease implements ChangelogRelease {
  const factory _ChangelogRelease({
    required final String version,
    required final String date,
    required final String changelog,
    required final String commit,
  }) = _$ChangelogReleaseImpl;

  factory _ChangelogRelease.fromJson(Map<String, dynamic> json) =
      _$ChangelogReleaseImpl.fromJson;

  @override
  String get version;
  @override
  String get date;
  @override
  String get changelog;
  @override
  String get commit;

  /// Create a copy of ChangelogRelease
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChangelogReleaseImplCopyWith<_$ChangelogReleaseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
