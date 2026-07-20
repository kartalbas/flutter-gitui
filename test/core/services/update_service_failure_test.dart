// What a failed update check tells the user.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_gitui/core/services/update_service.dart';
import 'package:flutter_gitui/core/utils/result.dart';

void main() {
  group('UpdateService.describeCheckFailure', () {
    test('unwraps the message a failed check phrased for the user', () {
      // The path a call site actually takes: Failure -> unwrap() -> catch.
      const failure = Failure<int>('No release has been published yet.');
      Object? caught;
      try {
        failure.unwrap();
      } catch (e) {
        caught = e;
      }

      expect(caught, isNotNull);
      expect(caught.toString(), startsWith('Exception: '));
      expect(
        UpdateService.describeCheckFailure(caught!),
        'No release has been published yet.',
      );
    });

    test('names the connection when the host cannot be reached', () {
      const error = SocketException(
        "Failed host lookup: 'api.github.com'",
        osError: OSError('No such host is known.', 11001),
      );
      final message = UpdateService.describeCheckFailure(error);

      expect(message, contains('internet connection'));
      expect(message, contains('github.com/kartalbas/flutter-gitui/releases'));
      // The internal detail belongs in the log, not in a SnackBar.
      expect(message, isNot(contains('SocketException')));
      expect(message, isNot(contains('errno')));
      expect(message, isNot(contains('11001')));
    });

    test('reports a timeout as a timeout', () {
      final message = UpdateService.describeCheckFailure(
        TimeoutException('Future not completed', const Duration(seconds: 10)),
      );

      expect(message, contains('did not answer'));
      expect(message, isNot(contains('TimeoutException')));
    });

    test('reports a transport failure without exception syntax', () {
      final message = UpdateService.describeCheckFailure(
        http.ClientException('Connection closed before full header'),
      );

      expect(message, contains('GitHub could not be reached'));
      expect(message, isNot(contains('ClientException')));
    });

    test('never surfaces a raw error for an unclassified failure', () {
      final message = UpdateService.describeCheckFailure(
        StateError('bad state: internal detail'),
      );

      expect(message, isNot(contains('internal detail')));
      expect(message, contains('application log'));
    });
  });
}
