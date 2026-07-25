// The picker is scoped to the hosts the workspace already uses, and its list is
// loaded once and filtered on every keystroke. The three pure pieces that
// decides - which hosts qualify, how a result ranks, and how paging finds the
// next page - are pinned here; the network calls around them are not testable
// without a provider to talk to.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/git/git_credential.dart';
import 'package:flutter_gitui/core/git/models/git_remote_identity.dart';
import 'package:flutter_gitui/core/hosting/hosted_repository.dart';
import 'package:flutter_gitui/core/hosting/hosting_providers.dart';
import 'package:flutter_gitui/core/hosting/repository_browser.dart';

HostedRepository repo(String fullName, {String? description}) =>
    HostedRepository(
      fullName: fullName,
      cloneUrl: 'https://github.com/$fullName.git',
      description: description,
    );

void main() {
  group('sourcesFromRemoteUrls', () {
    test('offers each host once, however many repositories use it', () {
      final sources = sourcesFromRemoteUrls([
        'https://github.com/digitaplatform/digita-apps.git',
        'https://github.com/digitaplatform/digita-auth.git',
        'git@github.com:other/thing.git',
      ]);
      expect(sources, hasLength(1));
      expect(sources.single.host, 'github.com');
      expect(sources.single.provider, GitHostingProvider.gitHub);
      expect(sources.single.label, 'GitHub');
    });

    test('leaves out hosts nothing can browse yet', () {
      // An always-empty tab is worse than no tab.
      final sources = sourcesFromRemoteUrls([
        'https://dev.azure.com/org/project/_git/repo',
        'https://code.company.internal/team/service.git',
      ]);
      expect(sources, isEmpty);
    });

    test('ignores local repositories, which have no host', () {
      expect(sourcesFromRemoteUrls([r'C:\repos\local', null, '']), isEmpty);
    });
  });

  group('filterRepositories', () {
    final repositories = [
      repo('digitaplatform/digita-auth'),
      repo('digitaplatform/digita-apps'),
      repo('other/legacy-digita'),
      repo('digitaplatform/unrelated', description: 'talks to digita-auth'),
      repo('digita-org/something'),
    ];

    test('an empty query lists everything alphabetically', () {
      final result = filterRepositories(repositories, '   ');
      expect(result, hasLength(repositories.length));
      expect(result.first.fullName, 'digita-org/something');
    });

    test('a name that starts with the query outranks one that contains it', () {
      // People type the beginning of the name they remember.
      final result = filterRepositories(repositories, 'digita-a');
      expect(result.first.name, 'digita-apps');
      expect(result[1].name, 'digita-auth');
      expect(
        result.map((r) => r.fullName),
        isNot(contains('other/legacy-digita')),
      );
    });

    test('the name outranks the owner, which outranks the description', () {
      final result = filterRepositories(repositories, 'digita');
      final names = result.map((r) => r.fullName).toList();
      // digita-* names first, then the owner match, then the prose mention.
      expect(
        names.indexOf('digitaplatform/digita-apps'),
        lessThan(names.indexOf('digita-org/something')),
      );
      expect(
        names.indexOf('digita-org/something'),
        lessThan(names.indexOf('digitaplatform/unrelated')),
      );
    });

    test('matching is case-insensitive and order is stable', () {
      final upper = filterRepositories(repositories, 'DIGITA-A');
      final lower = filterRepositories(repositories, 'digita-a');
      expect(
        upper.map((r) => r.fullName),
        orderedEquals(lower.map((r) => r.fullName)),
      );
    });

    test('a query nothing matches yields nothing', () {
      expect(filterRepositories(repositories, 'zzzz'), isEmpty);
    });
  });

  group('nextPageUrl', () {
    test('follows the next link rather than counting pages', () {
      // Only the absence of this link marks the last page.
      const header =
          '<https://api.github.com/user/repos?page=2>; rel="next", '
          '<https://api.github.com/user/repos?page=5>; rel="last"';
      expect(nextPageUrl(header), 'https://api.github.com/user/repos?page=2');
    });

    test('reports no next page on the last one', () {
      const header =
          '<https://api.github.com/user/repos?page=4>; rel="prev", '
          '<https://api.github.com/user/repos?page=1>; rel="first"';
      expect(nextPageUrl(header), isNull);
      expect(nextPageUrl(null), isNull);
      expect(nextPageUrl(''), isNull);
    });
  });

  group('parseGitCredentialOutput', () {
    test('reads the username and secret git reports', () {
      const output =
          'protocol=https\nhost=github.com\n'
          'username=kartalbas\npassword=ghp_secret\n';
      final credential = parseGitCredentialOutput(output);
      expect(credential!.username, 'kartalbas');
      expect(credential.password, 'ghp_secret');
    });

    test('keeps a secret that itself contains an equals sign', () {
      // Splitting on every '=' would truncate the token and produce a request
      // that fails authentication for no visible reason.
      final credential = parseGitCredentialOutput(
        'username=me\npassword=abc=def==\n',
      );
      expect(credential!.password, 'abc=def==');
    });

    test('reports nothing when no credential is stored', () {
      expect(parseGitCredentialOutput(''), isNull);
      expect(parseGitCredentialOutput('protocol=https\nhost=x\n'), isNull);
      expect(parseGitCredentialOutput('username=me\npassword=\n'), isNull);
    });
  });
}
