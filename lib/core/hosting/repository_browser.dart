import 'dart:convert';

import 'package:http/http.dart' as http;

import '../git/git_credential.dart';
import '../git/models/git_remote_identity.dart';
import '../services/logger_service.dart';
import 'hosted_repository.dart';

/// Lists the repositories an account can see on one hosting provider.
///
/// One implementation per provider: their APIs share no shape, so the only
/// thing worth abstracting is this question.
abstract interface class RepositoryBrowser {
  Future<List<HostedRepository>> listRepositories({
    required String host,
    required GitCredential credential,
  });
}

/// Whether the workspace's repositories on [provider] can be browsed.
///
/// Only providers with an implementation qualify; a host we cannot query is
/// better left out of the picker than shown as a permanently empty list.
bool canBrowse(GitHostingProvider provider) =>
    provider == GitHostingProvider.gitHub;

/// The browser for [provider], or null when it has none yet.
RepositoryBrowser? browserFor(
  GitHostingProvider provider, {
  http.Client? client,
}) {
  if (provider == GitHostingProvider.gitHub) {
    return GitHubRepositoryBrowser(client: client);
  }
  return null;
}

/// Reads the repositories a GitHub account can see, including those it reaches
/// through an organisation.
class GitHubRepositoryBrowser implements RepositoryBrowser {
  GitHubRepositoryBrowser({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  /// GitHub caps a page at 100 and reports the next one in its Link header.
  static const int _pageSize = 100;

  /// A safety net rather than a real limit: without it a malformed Link chain
  /// would loop forever against the network.
  static const int _maxPages = 20;

  @override
  Future<List<HostedRepository>> listRepositories({
    required String host,
    required GitCredential credential,
  }) async {
    // github.com is served by api.github.com; an enterprise install answers
    // under /api/v3 on its own host.
    final base = host.toLowerCase() == 'github.com'
        ? 'https://api.github.com'
        : 'https://$host/api/v3';

    final repositories = <HostedRepository>[];
    var url = Uri.parse(
      '$base/user/repos'
      '?per_page=$_pageSize&sort=full_name'
      '&affiliation=owner,collaborator,organization_member',
    );

    for (var page = 0; page < _maxPages; page++) {
      final response = await _client.get(
        url,
        headers: {
          'Accept': 'application/vnd.github+json',
          'Authorization': 'Bearer ${credential.password}',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      );

      if (response.statusCode != 200) {
        throw RepositoryBrowserException(
          'GitHub returned ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) break;
      for (final entry in decoded) {
        if (entry is! Map<String, dynamic>) continue;
        final fullName = entry['full_name'] as String?;
        final cloneUrl = entry['clone_url'] as String?;
        if (fullName == null || cloneUrl == null) continue;
        repositories.add(
          HostedRepository(
            fullName: fullName,
            cloneUrl: cloneUrl,
            description: entry['description'] as String?,
            isPrivate: entry['private'] as bool? ?? false,
          ),
        );
      }

      final next = nextPageUrl(response.headers['link']);
      if (next == null) break;
      url = Uri.parse(next);
    }

    Logger.debug('Listed ${repositories.length} repositories from $host');
    return repositories;
  }
}

/// Extracts the `rel="next"` target from a GitHub Link header.
///
/// Paging has to follow the header rather than count pages: the last page is
/// only recognisable by the absence of this link, and guessing from the page
/// size either stops early or requests one page too many on every call.
String? nextPageUrl(String? linkHeader) {
  if (linkHeader == null || linkHeader.isEmpty) return null;

  for (final part in linkHeader.split(',')) {
    final segments = part.split(';');
    if (segments.length < 2) continue;
    final isNext = segments
        .skip(1)
        .any((segment) => segment.trim().replaceAll('"', '') == 'rel=next');
    if (!isNext) continue;

    final target = segments.first.trim();
    if (target.startsWith('<') && target.endsWith('>')) {
      return target.substring(1, target.length - 1);
    }
  }
  return null;
}

/// A provider refused or could not answer the listing request.
class RepositoryBrowserException implements Exception {
  const RepositoryBrowserException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  /// The credential was missing, wrong or lacks the scope to list repositories
  /// - the one failure signing in again can fix.
  bool get isAuthenticationProblem => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}
