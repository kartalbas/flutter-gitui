import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/config_providers.dart';
import '../git/git_credential.dart';
import '../git/models/git_remote_identity.dart';
import '../workspace/repository_status_provider.dart';
import 'hosted_repository.dart';
import 'repository_browser.dart';

/// One host the workspace already uses, with the provider running it.
///
/// The picker is scoped to these rather than to the whole internet: these are
/// the hosts the user has credentials for and repositories on, so they are the
/// ones worth offering - and it keeps the feature free of search rate limits.
class RepositorySource {
  const RepositorySource({required this.host, required this.provider});

  final String host;
  final GitHostingProvider provider;

  /// What the tab is called: the provider, or the host when self-hosted.
  String get label =>
      provider == GitHostingProvider.unknown ? host : provider.label;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepositorySource &&
          host == other.host &&
          provider == other.provider;

  @override
  int get hashCode => Object.hash(host, provider);
}

/// The distinct browsable hosts of the workspace's repositories.
///
/// Derived from the remotes rather than configured: a host is offered exactly
/// when the user already works with it. Hosts whose provider has no browser
/// yet are left out, because an always-empty tab is worse than no tab.
List<RepositorySource> sourcesFromRemoteUrls(Iterable<String?> remoteUrls) {
  final sources = <RepositorySource>[];
  final seen = <String>{};

  for (final url in remoteUrls) {
    final identity = parseRemoteIdentity(url);
    if (identity == null) continue;
    if (!canBrowse(identity.provider)) continue;

    final key = identity.host.toLowerCase();
    if (!seen.add(key)) continue;
    sources.add(
      RepositorySource(host: identity.host, provider: identity.provider),
    );
  }

  sources.sort(
    (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
  );
  return sources;
}

/// The hosts the workspace spans, as tabs for the repository picker.
final repositorySourcesProvider = Provider<List<RepositorySource>>((ref) {
  final statuses = ref.watch(workspaceRepositoryStatusProvider);
  return sourcesFromRemoteUrls(statuses.values.map((s) => s.remoteUrl));
});

/// Why a source cannot be listed, so the tab can say so instead of showing an
/// empty list the user cannot explain.
enum SourceFailure { credentialsMissing, authenticationRejected, requestFailed }

/// The repositories one source offers, or the reason it cannot say.
class SourceRepositories {
  const SourceRepositories.loaded(this.repositories)
    : failure = null,
      detail = null;
  const SourceRepositories.failed(this.failure, {this.detail})
    : repositories = const [];

  final List<HostedRepository> repositories;
  final SourceFailure? failure;
  final String? detail;

  bool get hasFailed => failure != null;
}

/// Fetches everything the account on [source] can see, once per source.
///
/// Loaded whole and filtered locally afterwards: a request per keystroke would
/// be slower, rate-limited, and would reorder results while the user is still
/// typing. Prompts stay off, so opening the picker cannot make a credential
/// helper throw a login window; a source without a credential reports that and
/// offers signing in as a deliberate action.
final sourceRepositoriesProvider = FutureProvider.autoDispose
    .family<SourceRepositories, RepositorySource>((ref, source) async {
      final gitExecutablePath = ref.watch(gitExecutablePathProvider);

      final credential = await readGitCredential(
        host: source.host,
        gitExecutablePath: gitExecutablePath,
      );
      if (credential == null) {
        return const SourceRepositories.failed(
          SourceFailure.credentialsMissing,
        );
      }

      final browser = browserFor(source.provider);
      if (browser == null) {
        return const SourceRepositories.failed(SourceFailure.requestFailed);
      }

      try {
        final repositories = await browser.listRepositories(
          host: source.host,
          credential: credential,
        );
        return SourceRepositories.loaded(repositories);
      } on RepositoryBrowserException catch (error) {
        return SourceRepositories.failed(
          error.isAuthenticationProblem
              ? SourceFailure.authenticationRejected
              : SourceFailure.requestFailed,
          detail: error.message,
        );
      } on Object catch (error) {
        return SourceRepositories.failed(
          SourceFailure.requestFailed,
          detail: error.toString(),
        );
      }
    });
