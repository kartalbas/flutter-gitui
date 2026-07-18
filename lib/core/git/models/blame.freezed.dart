// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'blame.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$BlameLine {
  int get lineNumber => throw _privateConstructorUsedError;
  String get commitHash => throw _privateConstructorUsedError;
  String get author => throw _privateConstructorUsedError;
  String get authorEmail => throw _privateConstructorUsedError;
  DateTime get authorTime => throw _privateConstructorUsedError;
  String get summary => throw _privateConstructorUsedError;
  String get lineContent => throw _privateConstructorUsedError;
  String? get filename => throw _privateConstructorUsedError;

  /// Create a copy of BlameLine
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BlameLineCopyWith<BlameLine> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BlameLineCopyWith<$Res> {
  factory $BlameLineCopyWith(BlameLine value, $Res Function(BlameLine) then) =
      _$BlameLineCopyWithImpl<$Res, BlameLine>;
  @useResult
  $Res call({
    int lineNumber,
    String commitHash,
    String author,
    String authorEmail,
    DateTime authorTime,
    String summary,
    String lineContent,
    String? filename,
  });
}

/// @nodoc
class _$BlameLineCopyWithImpl<$Res, $Val extends BlameLine>
    implements $BlameLineCopyWith<$Res> {
  _$BlameLineCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BlameLine
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? lineNumber = null,
    Object? commitHash = null,
    Object? author = null,
    Object? authorEmail = null,
    Object? authorTime = null,
    Object? summary = null,
    Object? lineContent = null,
    Object? filename = freezed,
  }) {
    return _then(
      _value.copyWith(
            lineNumber: null == lineNumber
                ? _value.lineNumber
                : lineNumber // ignore: cast_nullable_to_non_nullable
                      as int,
            commitHash: null == commitHash
                ? _value.commitHash
                : commitHash // ignore: cast_nullable_to_non_nullable
                      as String,
            author: null == author
                ? _value.author
                : author // ignore: cast_nullable_to_non_nullable
                      as String,
            authorEmail: null == authorEmail
                ? _value.authorEmail
                : authorEmail // ignore: cast_nullable_to_non_nullable
                      as String,
            authorTime: null == authorTime
                ? _value.authorTime
                : authorTime // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            summary: null == summary
                ? _value.summary
                : summary // ignore: cast_nullable_to_non_nullable
                      as String,
            lineContent: null == lineContent
                ? _value.lineContent
                : lineContent // ignore: cast_nullable_to_non_nullable
                      as String,
            filename: freezed == filename
                ? _value.filename
                : filename // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BlameLineImplCopyWith<$Res>
    implements $BlameLineCopyWith<$Res> {
  factory _$$BlameLineImplCopyWith(
    _$BlameLineImpl value,
    $Res Function(_$BlameLineImpl) then,
  ) = __$$BlameLineImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int lineNumber,
    String commitHash,
    String author,
    String authorEmail,
    DateTime authorTime,
    String summary,
    String lineContent,
    String? filename,
  });
}

/// @nodoc
class __$$BlameLineImplCopyWithImpl<$Res>
    extends _$BlameLineCopyWithImpl<$Res, _$BlameLineImpl>
    implements _$$BlameLineImplCopyWith<$Res> {
  __$$BlameLineImplCopyWithImpl(
    _$BlameLineImpl _value,
    $Res Function(_$BlameLineImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BlameLine
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? lineNumber = null,
    Object? commitHash = null,
    Object? author = null,
    Object? authorEmail = null,
    Object? authorTime = null,
    Object? summary = null,
    Object? lineContent = null,
    Object? filename = freezed,
  }) {
    return _then(
      _$BlameLineImpl(
        lineNumber: null == lineNumber
            ? _value.lineNumber
            : lineNumber // ignore: cast_nullable_to_non_nullable
                  as int,
        commitHash: null == commitHash
            ? _value.commitHash
            : commitHash // ignore: cast_nullable_to_non_nullable
                  as String,
        author: null == author
            ? _value.author
            : author // ignore: cast_nullable_to_non_nullable
                  as String,
        authorEmail: null == authorEmail
            ? _value.authorEmail
            : authorEmail // ignore: cast_nullable_to_non_nullable
                  as String,
        authorTime: null == authorTime
            ? _value.authorTime
            : authorTime // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        summary: null == summary
            ? _value.summary
            : summary // ignore: cast_nullable_to_non_nullable
                  as String,
        lineContent: null == lineContent
            ? _value.lineContent
            : lineContent // ignore: cast_nullable_to_non_nullable
                  as String,
        filename: freezed == filename
            ? _value.filename
            : filename // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$BlameLineImpl extends _BlameLine {
  const _$BlameLineImpl({
    required this.lineNumber,
    required this.commitHash,
    required this.author,
    required this.authorEmail,
    required this.authorTime,
    required this.summary,
    required this.lineContent,
    this.filename,
  }) : super._();

  @override
  final int lineNumber;
  @override
  final String commitHash;
  @override
  final String author;
  @override
  final String authorEmail;
  @override
  final DateTime authorTime;
  @override
  final String summary;
  @override
  final String lineContent;
  @override
  final String? filename;

  @override
  String toString() {
    return 'BlameLine(lineNumber: $lineNumber, commitHash: $commitHash, author: $author, authorEmail: $authorEmail, authorTime: $authorTime, summary: $summary, lineContent: $lineContent, filename: $filename)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BlameLineImpl &&
            (identical(other.lineNumber, lineNumber) ||
                other.lineNumber == lineNumber) &&
            (identical(other.commitHash, commitHash) ||
                other.commitHash == commitHash) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.authorEmail, authorEmail) ||
                other.authorEmail == authorEmail) &&
            (identical(other.authorTime, authorTime) ||
                other.authorTime == authorTime) &&
            (identical(other.summary, summary) || other.summary == summary) &&
            (identical(other.lineContent, lineContent) ||
                other.lineContent == lineContent) &&
            (identical(other.filename, filename) ||
                other.filename == filename));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    lineNumber,
    commitHash,
    author,
    authorEmail,
    authorTime,
    summary,
    lineContent,
    filename,
  );

  /// Create a copy of BlameLine
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BlameLineImplCopyWith<_$BlameLineImpl> get copyWith =>
      __$$BlameLineImplCopyWithImpl<_$BlameLineImpl>(this, _$identity);
}

abstract class _BlameLine extends BlameLine {
  const factory _BlameLine({
    required final int lineNumber,
    required final String commitHash,
    required final String author,
    required final String authorEmail,
    required final DateTime authorTime,
    required final String summary,
    required final String lineContent,
    final String? filename,
  }) = _$BlameLineImpl;
  const _BlameLine._() : super._();

  @override
  int get lineNumber;
  @override
  String get commitHash;
  @override
  String get author;
  @override
  String get authorEmail;
  @override
  DateTime get authorTime;
  @override
  String get summary;
  @override
  String get lineContent;
  @override
  String? get filename;

  /// Create a copy of BlameLine
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BlameLineImplCopyWith<_$BlameLineImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$FileBlame {
  String get filePath => throw _privateConstructorUsedError;
  List<BlameLine> get lines => throw _privateConstructorUsedError;

  /// Create a copy of FileBlame
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FileBlameCopyWith<FileBlame> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FileBlameCopyWith<$Res> {
  factory $FileBlameCopyWith(FileBlame value, $Res Function(FileBlame) then) =
      _$FileBlameCopyWithImpl<$Res, FileBlame>;
  @useResult
  $Res call({String filePath, List<BlameLine> lines});
}

/// @nodoc
class _$FileBlameCopyWithImpl<$Res, $Val extends FileBlame>
    implements $FileBlameCopyWith<$Res> {
  _$FileBlameCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FileBlame
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? filePath = null, Object? lines = null}) {
    return _then(
      _value.copyWith(
            filePath: null == filePath
                ? _value.filePath
                : filePath // ignore: cast_nullable_to_non_nullable
                      as String,
            lines: null == lines
                ? _value.lines
                : lines // ignore: cast_nullable_to_non_nullable
                      as List<BlameLine>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$FileBlameImplCopyWith<$Res>
    implements $FileBlameCopyWith<$Res> {
  factory _$$FileBlameImplCopyWith(
    _$FileBlameImpl value,
    $Res Function(_$FileBlameImpl) then,
  ) = __$$FileBlameImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String filePath, List<BlameLine> lines});
}

/// @nodoc
class __$$FileBlameImplCopyWithImpl<$Res>
    extends _$FileBlameCopyWithImpl<$Res, _$FileBlameImpl>
    implements _$$FileBlameImplCopyWith<$Res> {
  __$$FileBlameImplCopyWithImpl(
    _$FileBlameImpl _value,
    $Res Function(_$FileBlameImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FileBlame
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? filePath = null, Object? lines = null}) {
    return _then(
      _$FileBlameImpl(
        filePath: null == filePath
            ? _value.filePath
            : filePath // ignore: cast_nullable_to_non_nullable
                  as String,
        lines: null == lines
            ? _value._lines
            : lines // ignore: cast_nullable_to_non_nullable
                  as List<BlameLine>,
      ),
    );
  }
}

/// @nodoc

class _$FileBlameImpl extends _FileBlame {
  const _$FileBlameImpl({
    required this.filePath,
    required final List<BlameLine> lines,
  }) : _lines = lines,
       super._();

  @override
  final String filePath;
  final List<BlameLine> _lines;
  @override
  List<BlameLine> get lines {
    if (_lines is EqualUnmodifiableListView) return _lines;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_lines);
  }

  @override
  String toString() {
    return 'FileBlame(filePath: $filePath, lines: $lines)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FileBlameImpl &&
            (identical(other.filePath, filePath) ||
                other.filePath == filePath) &&
            const DeepCollectionEquality().equals(other._lines, _lines));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    filePath,
    const DeepCollectionEquality().hash(_lines),
  );

  /// Create a copy of FileBlame
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FileBlameImplCopyWith<_$FileBlameImpl> get copyWith =>
      __$$FileBlameImplCopyWithImpl<_$FileBlameImpl>(this, _$identity);
}

abstract class _FileBlame extends FileBlame {
  const factory _FileBlame({
    required final String filePath,
    required final List<BlameLine> lines,
  }) = _$FileBlameImpl;
  const _FileBlame._() : super._();

  @override
  String get filePath;
  @override
  List<BlameLine> get lines;

  /// Create a copy of FileBlame
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FileBlameImplCopyWith<_$FileBlameImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
