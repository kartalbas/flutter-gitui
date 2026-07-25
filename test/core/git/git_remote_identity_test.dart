// A workspace can span several hosting providers, and a card that only says
// "Sign-in required" is useless without saying which account is missing. The
// answer is read out of the remote URL, which git accepts in three unrelated
// shapes - so the parsing rules, and the host-to-provider mapping, are pinned
// here rather than left to a bare Uri.parse.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/git/models/git_remote_identity.dart';

void main() {
  group('parseRemoteIdentity', () {
    test('reads an https remote', () {
      final identity = parseRemoteIdentity(
        'https://github.com/digitaplatform/digita-controller.git',
      );
      expect(identity!.host, 'github.com');
      expect(identity.provider, GitHostingProvider.gitHub);
      expect(identity.user, isNull);
    });

    test('reads the scp-like form git accepts, which is not a URI', () {
      // git@host:path has no scheme; Uri.parse would read the whole thing as a
      // path and report no host at all.
      final identity = parseRemoteIdentity(
        'git@github.com:digitaplatform/digita-controller.git',
      );
      expect(identity!.host, 'github.com');
      expect(identity.provider, GitHostingProvider.gitHub);
      expect(identity.user, 'git');
    });

    test('reads an ssh:// remote with a port', () {
      final identity = parseRemoteIdentity(
        'ssh://git@git.company.internal:2222/team/service.git',
      );
      expect(identity!.host, 'git.company.internal');
      expect(identity.provider, GitHostingProvider.unknown);
      expect(identity.user, 'git');
    });

    test('reads the user out of an https remote', () {
      final identity = parseRemoteIdentity(
        'https://kartalbas@dev.azure.com/org/project/_git/repo',
      );
      expect(identity!.host, 'dev.azure.com');
      expect(identity.provider, GitHostingProvider.azureDevOps);
      expect(identity.accountHint, 'kartalbas');
    });

    test('a password in the URL is never mistaken for the account', () {
      final identity = parseRemoteIdentity(
        'https://user:secret@gitlab.com/a/b',
      );
      expect(identity!.user, 'user');
      expect(identity.accountHint, 'user');
    });

    test('the generic ssh user is not shown as an account', () {
      // Every SSH remote is "git@", which identifies nobody.
      final identity = parseRemoteIdentity('git@github.com:a/b.git');
      expect(identity!.user, 'git');
      expect(identity.accountHint, isNull);
    });

    test('a local path has no host and no account', () {
      for (final url in [
        r'C:\repos\local-only',
        '/home/me/repos/local-only',
        '../sibling-repo',
        '',
        null,
      ]) {
        expect(parseRemoteIdentity(url), isNull, reason: '$url');
      }
    });
  });

  group('providerForHost', () {
    test('recognises the hosted services', () {
      expect(providerForHost('github.com'), GitHostingProvider.gitHub);
      expect(providerForHost('gitlab.com'), GitHostingProvider.gitLab);
      expect(providerForHost('bitbucket.org'), GitHostingProvider.bitbucket);
      expect(providerForHost('dev.azure.com'), GitHostingProvider.azureDevOps);
      expect(
        providerForHost('ssh.dev.azure.com'),
        GitHostingProvider.azureDevOps,
      );
      expect(
        providerForHost('myorg.visualstudio.com'),
        GitHostingProvider.azureDevOps,
      );
      expect(providerForHost('codeberg.org'), GitHostingProvider.codeberg);
      expect(providerForHost('git.sr.ht'), GitHostingProvider.sourceHut);
    });

    test('recognises self-hosted instances of the known products', () {
      expect(providerForHost('github.company.com'), GitHostingProvider.gitHub);
      expect(providerForHost('gitlab.internal'), GitHostingProvider.gitLab);
      expect(providerForHost('gitea.example.org'), GitHostingProvider.gitea);
    });

    test('is case-insensitive', () {
      expect(providerForHost('GitHub.COM'), GitHostingProvider.gitHub);
    });

    test('an unrelated host stays unknown rather than being guessed', () {
      // "azure" alone must not claim a machine that merely runs on Azure.
      expect(
        providerForHost('git.azure-hosted.example.com'),
        GitHostingProvider.unknown,
      );
      expect(
        providerForHost('code.company.internal'),
        GitHostingProvider.unknown,
      );
    });
  });

  group('label', () {
    test('names the provider when known', () {
      final identity = parseRemoteIdentity('https://dev.azure.com/o/p/_git/r');
      expect(identity!.label, 'Azure DevOps');
    });

    test('falls back to the host, which beats guessing', () {
      final identity = parseRemoteIdentity('https://code.company.internal/a/b');
      expect(identity!.label, 'code.company.internal');
    });
  });
}
