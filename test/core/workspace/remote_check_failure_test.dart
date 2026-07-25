// The background sweep runs without credential prompts, so a repository whose
// credentials are not cached fails. Reporting every failure the same way hid
// the reason and left the user nothing to act on, so the cause is classified
// and shown. The strings below are what git actually wrote when probed with
// prompts disabled, not what its documentation implies.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/workspace/models/remote_check_failure.dart';

void main() {
  group('classifyRemoteCheckFailure', () {
    test('recognises a declined credential helper as needing a sign-in', () {
      // Observed: a helper that may not go interactive declines, and git has
      // no other source for the password.
      expect(
        classifyRemoteCheckFailure('fatal: unable to get password from user'),
        RemoteCheckFailure.authenticationRequired,
      );
    });

    test('recognises the disabled-prompt wording', () {
      expect(
        classifyRemoteCheckFailure(
          "fatal: could not read Username for 'https://github.com': "
          'terminal prompts disabled',
        ),
        RemoteCheckFailure.authenticationRequired,
      );
    });

    test('recognises a rejected sign-in', () {
      for (final message in [
        'remote: Invalid username or password.\nfatal: Authentication failed',
        'fatal: Authentication failed for https://dev.azure.com/org/_git/repo',
        'remote: HTTP Basic: Access denied',
        'git@github.com: Permission denied (publickey).',
      ]) {
        expect(
          classifyRemoteCheckFailure(message),
          RemoteCheckFailure.authenticationRequired,
          reason: message,
        );
      }
    });

    test('recognises an unreachable remote', () {
      // Observed: the offline / bad-DNS case.
      expect(
        classifyRemoteCheckFailure(
          "fatal: unable to access 'https://example.invalid/a.git/': "
          'Could not resolve host: example.invalid',
        ),
        RemoteCheckFailure.unreachable,
      );
      expect(
        classifyRemoteCheckFailure('fatal: Could not connect to server'),
        RemoteCheckFailure.unreachable,
      );
      expect(
        classifyRemoteCheckFailure('ssh: connect to host: Connection refused'),
        RemoteCheckFailure.unreachable,
      );
    });

    test('an authentication problem wins over the generic access wording', () {
      // git prefixes many failures with "unable to access", including the ones
      // that are really about credentials; those must not read as offline,
      // because only a sign-in fixes them.
      expect(
        classifyRemoteCheckFailure(
          "fatal: unable to access 'https://github.com/x/y.git/': "
          'The requested URL returned error: 403 Forbidden',
        ),
        RemoteCheckFailure.authenticationRequired,
      );
    });

    test('an unrecognised error stays generic rather than guessing', () {
      expect(
        classifyRemoteCheckFailure('fatal: bad object HEAD'),
        RemoteCheckFailure.failed,
      );
    });

    test('an empty or missing message is a generic failure', () {
      expect(classifyRemoteCheckFailure(null), RemoteCheckFailure.failed);
      expect(classifyRemoteCheckFailure('   '), RemoteCheckFailure.failed);
    });
  });
}
