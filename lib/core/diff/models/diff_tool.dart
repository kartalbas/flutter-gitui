import 'package:flutter/foundation.dart';

/// Type of diff/merge tool
enum DiffToolType {
  vscode,
  vscodium,
  intellijIdea,
  beyondCompare,
  kdiff3,
  p4merge,
  meld,
  winMerge,
  tortoiseGitMerge,
  araxis,
  diffMerge,
  xxdiff,
  opendiff,
  vimdiff,
  custom;

  String get displayName {
    switch (this) {
      case DiffToolType.vscode:
        return 'Visual Studio Code';
      case DiffToolType.vscodium:
        return 'VSCodium';
      case DiffToolType.intellijIdea:
        return 'IntelliJ IDEA';
      case DiffToolType.beyondCompare:
        return 'Beyond Compare';
      case DiffToolType.kdiff3:
        return 'KDiff3';
      case DiffToolType.p4merge:
        return 'P4Merge';
      case DiffToolType.meld:
        return 'Meld';
      case DiffToolType.winMerge:
        return 'WinMerge';
      case DiffToolType.tortoiseGitMerge:
        return 'TortoiseGitMerge';
      case DiffToolType.araxis:
        return 'Araxis Merge';
      case DiffToolType.diffMerge:
        return 'DiffMerge';
      case DiffToolType.xxdiff:
        return 'xxdiff';
      case DiffToolType.opendiff:
        return 'opendiff (FileMerge)';
      case DiffToolType.vimdiff:
        return 'vimdiff';
      case DiffToolType.custom:
        return 'Custom Tool';
    }
  }

  /// Get standard diff arguments for this tool type
  /// Placeholders: $LOCAL, $REMOTE, $BASE, $MERGED, $LABEL
  String get standardDiffArgs {
    switch (this) {
      case DiffToolType.vscode:
      case DiffToolType.vscodium:
        return '--wait --diff \$LOCAL \$REMOTE';
      case DiffToolType.intellijIdea:
        return 'diff \$LOCAL \$REMOTE';
      case DiffToolType.beyondCompare:
        return '\$LOCAL \$REMOTE /title1=\$LABEL /title2=\$LABEL';
      case DiffToolType.kdiff3:
        return '\$LOCAL \$REMOTE';
      case DiffToolType.p4merge:
        return '\$LOCAL \$REMOTE';
      case DiffToolType.meld:
        return '\$LOCAL \$REMOTE';
      case DiffToolType.winMerge:
        return '-e -u \$LOCAL \$REMOTE';
      case DiffToolType.tortoiseGitMerge:
        return '/base:\$LOCAL /mine:\$REMOTE';
      case DiffToolType.araxis:
        return '-wait -2 \$LOCAL \$REMOTE';
      case DiffToolType.diffMerge:
        return '\$LOCAL \$REMOTE';
      case DiffToolType.xxdiff:
        return '\$LOCAL \$REMOTE';
      case DiffToolType.opendiff:
        return '\$LOCAL \$REMOTE';
      case DiffToolType.vimdiff:
        return '-d \$LOCAL \$REMOTE';
      case DiffToolType.custom:
        return '\$LOCAL \$REMOTE';
    }
  }

  /// Get standard merge arguments for this tool type
  /// Placeholders: $LOCAL, $REMOTE, $BASE, $MERGED
  String get standardMergeArgs {
    switch (this) {
      case DiffToolType.vscode:
      case DiffToolType.vscodium:
        return '--wait --merge \$REMOTE \$LOCAL \$BASE \$MERGED';
      case DiffToolType.intellijIdea:
        return 'merge \$LOCAL \$REMOTE \$BASE \$MERGED';
      case DiffToolType.beyondCompare:
        return '\$LOCAL \$REMOTE \$BASE \$MERGED';
      case DiffToolType.kdiff3:
        return '\$BASE \$LOCAL \$REMOTE -o \$MERGED';
      case DiffToolType.p4merge:
        return '\$BASE \$LOCAL \$REMOTE \$MERGED';
      case DiffToolType.meld:
        return '\$LOCAL \$BASE \$REMOTE --output=\$MERGED';
      case DiffToolType.winMerge:
        return '-e -u \$LOCAL \$REMOTE \$MERGED';
      case DiffToolType.tortoiseGitMerge:
        return '/base:\$BASE /mine:\$LOCAL /theirs:\$REMOTE /merged:\$MERGED';
      case DiffToolType.araxis:
        return '-wait -merge -3 -a1 \$BASE \$LOCAL \$REMOTE \$MERGED';
      case DiffToolType.diffMerge:
        return '-m -t1=\$LABEL -t2=\$LABEL -t3=\$LABEL \$LOCAL \$BASE \$REMOTE \$MERGED';
      case DiffToolType.xxdiff:
        return '-X -R \$MERGED -m -M \$LOCAL -O \$BASE -M \$REMOTE';
      case DiffToolType.opendiff:
        return '\$LOCAL \$REMOTE -ancestor \$BASE -merge \$MERGED';
      case DiffToolType.vimdiff:
        return '-d \$LOCAL \$BASE \$REMOTE \$MERGED';
      case DiffToolType.custom:
        return '\$BASE \$LOCAL \$REMOTE \$MERGED';
    }
  }
}

/// Represents an external diff/merge tool
@immutable
class DiffTool {
  final DiffToolType type;
  final String executablePath;
  final String diffArgs;
  final String mergeArgs;
  final bool isAvailable;
  final String? version;

  const DiffTool({
    required this.type,
    required this.executablePath,
    required this.diffArgs,
    required this.mergeArgs,
    this.isAvailable = false,
    this.version,
  });

  /// Display name of the tool
  String get displayName => type.displayName;

  /// Command to launch diff with two files
  List<String> diffCommand(String leftFile, String rightFile, {String? label}) {
    final args = diffArgs
        .replaceAll('\$LOCAL', leftFile)
        .replaceAll('\$REMOTE', rightFile)
        .replaceAll('\$BASE', leftFile)
        .replaceAll('\$MERGED', rightFile)
        .replaceAll('\$LABEL', label ?? '');

    return [executablePath, ...args.split(' ').where((a) => a.isNotEmpty)];
  }

  /// Command to launch 3-way merge
  List<String> mergeCommand(
    String base,
    String local,
    String remote,
    String merged,
  ) {
    final args = mergeArgs
        .replaceAll('\$BASE', base)
        .replaceAll('\$LOCAL', local)
        .replaceAll('\$REMOTE', remote)
        .replaceAll('\$MERGED', merged);

    return [executablePath, ...args.split(' ').where((a) => a.isNotEmpty)];
  }

  DiffTool copyWith({
    DiffToolType? type,
    String? executablePath,
    String? diffArgs,
    String? mergeArgs,
    bool? isAvailable,
    String? version,
  }) {
    return DiffTool(
      type: type ?? this.type,
      executablePath: executablePath ?? this.executablePath,
      diffArgs: diffArgs ?? this.diffArgs,
      mergeArgs: mergeArgs ?? this.mergeArgs,
      isAvailable: isAvailable ?? this.isAvailable,
      version: version ?? this.version,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiffTool &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          executablePath == other.executablePath;

  @override
  int get hashCode => type.hashCode ^ executablePath.hashCode;

  @override
  String toString() => '$displayName ($executablePath)';
}
