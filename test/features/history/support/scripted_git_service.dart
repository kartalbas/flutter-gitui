import 'package:flutter_gitui/core/git/git_cancellation.dart';
import 'package:flutter_gitui/core/git/git_service.dart';
import 'package:flutter_gitui/core/git/models/commit.dart';
import 'package:flutter_gitui/core/utils/result.dart';

/// A commit with just enough shape for window and search tests.
GitCommit commit(
  String hash, {
  String subject = 's',
  String author = 'a',
  DateTime? date,
  List<String> parents = const [],
}) {
  final when = date ?? DateTime.utc(2026);
  return GitCommit(
    hash: hash,
    shortHash: hash,
    author: author,
    authorEmail: '$author@example.com',
    authorDate: when,
    committer: author,
    committerEmail: '$author@example.com',
    committerDate: when,
    subject: subject,
    body: '',
    parents: parents,
    refs: const [],
  );
}

List<String> hashesOf(List<GitCommit> commits) => [
  for (final c in commits) c.hash,
];

typedef ScriptedGetLog =
    Future<Result<List<GitCommit>>> Function({
      int? limit,
      String? branch,
      String? filePath,
      List<String> startPoints,
    });

typedef ScriptedSearchLog =
    Future<Result<List<GitCommit>>> Function({String? query, bool pickaxe});

/// A [GitService] whose log calls are scripted, so no test ever shells out.
///
/// The interesting arguments - ordering, cursor start points, limits and the
/// cancellation tokens - are recorded rather than scripted, because they are
/// the contract the paging and deep-search designs make with git.
class ScriptedGitService extends GitService {
  ScriptedGitService(this.onGetLog, {this.onSearchLog}) : super('.');

  final ScriptedGetLog onGetLog;
  final ScriptedSearchLog? onSearchLog;

  bool? lastTopoOrder;
  List<String>? lastStartPoints;
  int? lastLimit;
  GitCancellationToken? lastGetLogToken;

  String? lastSearchQuery;
  bool? lastSearchPickaxe;
  int? lastSearchLimit;
  GitCancellationToken? lastSearchToken;

  @override
  Future<Result<List<GitCommit>>> getLog({
    int? limit,
    String? branch,
    String? filePath,
    String? grepMessage,
    String? author,
    String? since,
    String? until,
    bool allMatch = false,
    bool topoOrder = false,
    List<String> startPoints = const [],
    GitCancellationToken? cancellationToken,
  }) {
    lastTopoOrder = topoOrder;
    lastStartPoints = startPoints;
    lastLimit = limit;
    lastGetLogToken = cancellationToken;
    return onGetLog(
      limit: limit,
      branch: branch,
      filePath: filePath,
      startPoints: startPoints,
    );
  }

  @override
  Future<Result<List<GitCommit>>> searchLog({
    String? query,
    String? author,
    String? since,
    String? until,
    bool useRegex = false,
    bool caseSensitive = false,
    bool pickaxe = false,
    int limit = 1000,
    GitCancellationToken? cancellationToken,
  }) {
    lastSearchQuery = query;
    lastSearchPickaxe = pickaxe;
    lastSearchLimit = limit;
    lastSearchToken = cancellationToken;
    final handler = onSearchLog;
    if (handler == null) {
      return Future.value(const Success(<GitCommit>[]));
    }
    return handler(query: query, pickaxe: pickaxe);
  }
}
