import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/config_providers.dart';
import '../../../core/git/models/commit.dart';

/// A [CommitSelection] resolved against the commits the screen is showing.
///
/// Every consumer - the list highlight, the details panel, the action button
/// and each action itself - reads this instead of the raw hashes, so they can
/// never disagree about which commits are selected.
@immutable
class ResolvedCommitSelection {
  const ResolvedCommitSelection({required this.commits, this.primary});

  static const empty = ResolvedCommitSelection(commits: []);

  /// Selected commits in display order, newest first.
  final List<GitCommit> commits;

  /// The commit the details panel follows. Always an element of [commits], and
  /// null exactly when [commits] is empty.
  final GitCommit? primary;

  int get count => commits.length;

  bool get isEmpty => commits.isEmpty;

  bool get isNotEmpty => commits.isNotEmpty;

  /// The only selected commit, or null when the count is not exactly one.
  ///
  /// Reset, revert and tagging act on one commit; asking for [single] makes the
  /// "exactly one" precondition impossible to forget at a call site.
  GitCommit? get single => commits.length == 1 ? commits.first : null;

  Set<String> get hashes => {for (final commit in commits) commit.hash};

  /// Selected commits oldest first - the order git replays them in.
  List<GitCommit> get oldestFirst =>
      List<GitCommit>.unmodifiable(commits.reversed);
}

/// Which commits are selected in the history view.
///
/// Holds hashes rather than commit objects or list indices: a hash still names
/// the same commit after the list is refiltered or reloaded, while an index
/// silently comes to mean a different row. The transitions are pure so the
/// selection can be reasoned about - and tested - without a widget tree.
@immutable
class CommitSelection {
  const CommitSelection({
    this.hashes = const {},
    this.primaryHash,
    this.anchorHash,
  });

  /// A selection of [hash] alone.
  factory CommitSelection.single(String hash) =>
      CommitSelection(hashes: {hash}, primaryHash: hash, anchorHash: hash);

  static const empty = CommitSelection();

  final Set<String> hashes;

  /// The selected commit the details panel follows.
  final String? primaryHash;

  /// Origin of a shift range - the commit most recently clicked or stepped to.
  final String? anchorHash;

  int get count => hashes.length;

  bool get isEmpty => hashes.isEmpty;

  /// The one reconciliation rule: a selected hash counts only while the commit
  /// it names is in the displayed list.
  ///
  /// The list is the only evidence a hash exists in the open repository, so
  /// keeping unlisted hashes is what let a stale selection reach
  /// `git cherry-pick` in a repository that never contained it. It also keeps
  /// the action button honest - what it offers is exactly what the user can see
  /// selected - instead of acting on commits that are no longer on screen.
  ResolvedCommitSelection resolve(List<GitCommit> displayed) {
    if (hashes.isEmpty) return ResolvedCommitSelection.empty;

    final selected = [
      for (final commit in displayed)
        if (hashes.contains(commit.hash)) commit,
    ];
    if (selected.isEmpty) return ResolvedCommitSelection.empty;

    // A primary that dropped out of the list would leave the details panel and
    // the actions pointing at different commits, so promote a survivor.
    final primary = selected.firstWhere(
      (commit) => commit.hash == primaryHash,
      orElse: () => selected.first,
    );

    return ResolvedCommitSelection(
      commits: List<GitCommit>.unmodifiable(selected),
      primary: primary,
    );
  }

  /// [hash] added, or removed when it was already selected.
  CommitSelection toggled(String hash) {
    final next = {...hashes};

    if (!next.remove(hash)) {
      next.add(hash);
      return CommitSelection(hashes: next, primaryHash: hash, anchorHash: hash);
    }

    // Deselecting the primary hands the role to whatever is still selected,
    // otherwise the details panel would keep showing a deselected commit.
    final primary = primaryHash == hash
        ? (next.isEmpty ? null : next.last)
        : primaryHash;
    return CommitSelection(
      hashes: next,
      primaryHash: primary,
      anchorHash: primary,
    );
  }

  /// Everything between the anchor and [hash] inclusive.
  ///
  /// Falls back to a single selection when either end is not displayed, since
  /// a range needs two visible endpoints to mean anything.
  CommitSelection rangeTo(String hash, List<String> displayedHashes) {
    final anchor = anchorHash;
    final anchorIndex = anchor == null ? -1 : displayedHashes.indexOf(anchor);
    final targetIndex = displayedHashes.indexOf(hash);

    if (anchorIndex == -1 || targetIndex == -1) {
      return CommitSelection.single(hash);
    }

    final first = anchorIndex < targetIndex ? anchorIndex : targetIndex;
    final last = anchorIndex < targetIndex ? targetIndex : anchorIndex;

    return CommitSelection(
      hashes: {for (var i = first; i <= last; i++) displayedHashes[i]},
      primaryHash: hash,
      // Re-anchoring lets a second shift-click grow the range from where the
      // first one ended, which is how desktop lists behave.
      anchorHash: hash,
    );
  }

  /// The result of clicking [hash] with its platform-appropriate modifiers.
  CommitSelection clicked({
    required String hash,
    required List<String> displayedHashes,
    required bool isControlPressed,
    required bool isShiftPressed,
  }) {
    if (isShiftPressed && anchorHash != null) {
      return rangeTo(hash, displayedHashes);
    }
    if (isControlPressed) return toggled(hash);
    return CommitSelection.single(hash);
  }

  /// The selection [delta] rows further through [displayed].
  ///
  /// Keyboard and mouse produce the same value, which is what makes the action
  /// button appear for a selection made with the arrow keys.
  CommitSelection moved(List<GitCommit> displayed, int delta) {
    if (displayed.isEmpty) return this;

    // An unresolvable primary is no selection at all (see [resolve]), so start
    // from the newest commit rather than from a row nobody can see.
    final current = displayed.indexWhere(
      (commit) => commit.hash == primaryHash,
    );
    final next = current == -1
        ? 0
        : (current + delta).clamp(0, displayed.length - 1);

    return CommitSelection.single(displayed[next].hash);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommitSelection &&
          runtimeType == other.runtimeType &&
          primaryHash == other.primaryHash &&
          anchorHash == other.anchorHash &&
          setEquals(hashes, other.hashes);

  @override
  int get hashCode =>
      Object.hash(primaryHash, anchorHash, Object.hashAllUnordered(hashes));
}

/// The single owner of the history view's selection.
///
/// Scoped to the open repository: a hash names a commit in one repository only,
/// so a selection surviving a switch would let an action run against a
/// repository that never contained it.
class CommitSelectionNotifier extends Notifier<CommitSelection> {
  @override
  CommitSelection build() {
    ref.watch(currentRepositoryPathProvider);
    return CommitSelection.empty;
  }

  void selectSingle(String hash) => state = CommitSelection.single(hash);

  void handleClick({
    required String hash,
    required List<String> displayedHashes,
    required bool isControlPressed,
    required bool isShiftPressed,
  }) {
    state = state.clicked(
      hash: hash,
      displayedHashes: displayedHashes,
      isControlPressed: isControlPressed,
      isShiftPressed: isShiftPressed,
    );
  }

  void move(List<GitCommit> displayed, int delta) =>
      state = state.moved(displayed, delta);

  void clear() => state = CommitSelection.empty;

  /// Whether the platform's multi-select modifier is down (Cmd on macOS, Ctrl
  /// everywhere else).
  static bool isMultiSelectModifierPressed() {
    final keyboard = HardwareKeyboard.instance;
    return defaultTargetPlatform == TargetPlatform.macOS
        ? keyboard.isMetaPressed
        : keyboard.isControlPressed;
  }

  /// Whether the range-select modifier is down.
  static bool isRangeSelectModifierPressed() =>
      HardwareKeyboard.instance.isShiftPressed;
}

/// Provider for the history view's commit selection.
final commitSelectionProvider =
    NotifierProvider<CommitSelectionNotifier, CommitSelection>(
      CommitSelectionNotifier.new,
    );
