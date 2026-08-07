// What a failed update check concludes, and what it tells the user.
//
// The two are deliberately separate questions since #393: the check produces a
// reason, and the sentence is rendered from that reason in whatever locale is
// active when it is shown. These tests hold both ends of that seam.

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_gitui/core/services/update_reasons.dart';
import 'package:flutter_gitui/core/services/update_service.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/core/utils/result.dart';

void main() {
  group('UpdateService.failureReason', () {
    test('recovers the reason a failed check raised', () {
      const reason = UpdateReleaseNotInstallable('v0.5.15-alpha');

      expect(
        UpdateService.failureReason(const UpdateCheckException(reason)),
        reason,
      );
    });

    test('classifies a host that cannot be reached', () {
      const error = SocketException(
        "Failed host lookup: 'api.github.com'",
        osError: OSError('No such host is known.', 11001),
      );

      expect(
        UpdateService.failureReason(error),
        const UpdateNetworkUnreachable(),
      );
    });

    test('classifies a TLS failure the same way', () {
      expect(
        UpdateService.failureReason(const HandshakeException('bad cert')),
        const UpdateNetworkUnreachable(),
      );
    });

    test('classifies a transport failure the same way', () {
      expect(
        UpdateService.failureReason(
          http.ClientException('Connection closed before full header'),
        ),
        const UpdateNetworkUnreachable(),
      );
    });

    test('reports a timeout as a timeout, naming the limit it hit', () {
      final reason = UpdateService.failureReason(
        TimeoutException('Future not completed', const Duration(seconds: 10)),
      );

      expect(reason, const UpdateCheckTimedOut(10));
    });

    test('reports an unreadable answer as one', () {
      expect(
        UpdateService.failureReason(const FormatException('not json')),
        const UpdateResponseUnreadable(),
      );
    });

    test('classifies an unrecognised failure without keeping its text', () {
      final reason = UpdateService.failureReason(
        StateError('bad state: internal detail'),
      );

      expect(reason, const UpdateCheckFailedUnexpectedly());
      expect(reason.toStored().toString(), isNot(contains('internal detail')));
    });
  });

  group('what reaches the configuration file', () {
    test('a reason stores a code and scalars, never a sentence', () {
      final stored = const UpdateManifestUnavailable(
        tag: 'v0.5.15-alpha',
        statusCode: 404,
      ).toStored();

      expect(stored, {
        'code': 'manifest_unavailable',
        'tag': 'v0.5.15-alpha',
        'status': 404,
      });
      for (final value in stored.values) {
        expect(value, anyOf(isA<String>(), isA<int>(), isA<bool>()));
      }
    });

    test('a rate limit stores the instant, not a phrase about waiting', () {
      final retryAt = DateTime.utc(2026, 8, 7, 12, 30);

      expect(UpdateRateLimited(retryAt).toStored(), {
        'code': 'rate_limited',
        'retry_at': '2026-08-07T12:30:00.000Z',
      });
    });

    test('every stored form is read back as the reason it came from', () {
      final reasons = <UpdateFailureReason>[
        const UpdateNoReleasePublished(),
        const UpdateReleaseListUnavailable(403),
        UpdateRateLimited(DateTime.utc(2026, 8, 7, 12, 30)),
        const UpdateRateLimited(null),
        const UpdateManifestUnavailable(tag: 'v1.0.0', statusCode: 500),
        const UpdateReleaseNotInstallable('v1.0.0'),
        const UpdateNetworkUnreachable(),
        const UpdateCheckTimedOut(10),
        const UpdateResponseUnreadable(),
        const UpdatePlatformUnsupported(),
        const UpdateCheckFailedUnexpectedly(),
      ];

      for (final reason in reasons) {
        expect(
          UpdateFailureReason.fromStored(reason.toStored()),
          reason,
          reason: 'stored form of $reason',
        );
      }
    });

    test('a code from a newer build degrades to no detail', () {
      expect(
        UpdateFailureReason.fromStored(const {'code': 'quantum_flux'}),
        isNull,
      );
      expect(UpdateFailureReason.fromStored(const {}), isNull);
      expect(UpdateFailureReason.fromStored(null), isNull);
    });
  });

  group('rate limit reset header', () {
    test('is kept as the instant the quota returns', () {
      final reset = DateTime.utc(2026, 8, 7, 12, 30);
      final header = (reset.millisecondsSinceEpoch ~/ 1000).toString();

      expect(UpdateService.rateLimitReset(header), reset);
    });

    test('degrades to nothing when the header is absent or unreadable', () {
      expect(UpdateService.rateLimitReset(null), isNull);
      expect(UpdateService.rateLimitReset('soon'), isNull);
    });
  });

  group('the sentence is produced at display time', () {
    final english = lookupAppLocalizations(const Locale('en'));
    final german = lookupAppLocalizations(const Locale('de'));

    test('a reason persisted under one locale renders under the other', () {
      // The exact case #393 is about: the failure happened while the
      // application was in German, and the user has since switched to English.
      const reason = UpdateNetworkUnreachable();
      final stored = reason.toStored();
      final restored = UpdateFailureReason.fromStored(stored)!;

      expect(restored.message(german), contains('Internetverbindung'));
      expect(restored.message(english), contains('internet connection'));
    });

    test('every reason renders in every supported locale', () {
      final reasons = <UpdateFailureReason>[
        const UpdateNoReleasePublished(),
        const UpdateReleaseListUnavailable(503),
        UpdateRateLimited(DateTime.now().add(const Duration(hours: 1))),
        const UpdateRateLimited(null),
        const UpdateManifestUnavailable(tag: 'v1.0.0', statusCode: 404),
        const UpdateReleaseNotInstallable('v1.0.0'),
        const UpdateNetworkUnreachable(),
        const UpdateCheckTimedOut(10),
        const UpdateResponseUnreadable(),
        const UpdatePlatformUnsupported(),
        const UpdateCheckFailedUnexpectedly(),
      ];

      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = lookupAppLocalizations(locale);
        for (final reason in reasons) {
          final message = reason.message(l10n);
          expect(
            message,
            isNotEmpty,
            reason: '$reason in ${locale.languageCode}',
          );
          expect(
            message,
            contains('github.com/kartalbas/flutter-gitui/releases'),
            reason: '$reason in ${locale.languageCode} must name the fallback',
          );
          // Exception syntax and internal detail never reach a surface.
          expect(message, isNot(contains('Exception')));
        }
      }
    });

    test('a rate limit names the time only while it is still in force', () {
      final now = DateTime.utc(2026, 8, 7, 12, 0);
      final later = UpdateRateLimited(now.add(const Duration(minutes: 40)));
      final elapsed = UpdateRateLimited(now.subtract(const Duration(days: 2)));

      // A wait that has passed -- which is what a persisted one usually is by
      // the time it is read again -- must not point at a clock time gone by.
      expect(elapsed.message(english, now: now), contains('Try again later'));
      expect(later.message(english, now: now), contains('Try again after'));
    });

    test('a manual install names the version and where to get it', () {
      final message = ManualInstallReason.unsignedMacosRelease.message(
        english,
        '0.5.15-alpha',
      );

      expect(message, contains('0.5.15-alpha'));
      expect(message, contains('github.com/kartalbas/flutter-gitui/releases'));
    });
  });

  group('Result carries the reason, not the sentence', () {
    test('a Failure message stays the diagnostic the log wants', () {
      // unwrap() rethrows a Failure as Exception(message), which is why the
      // message must never be the user's sentence.
      const failure = Failure<int>('SocketException: Failed host lookup');
      Object? caught;
      try {
        failure.unwrap();
      } catch (e) {
        caught = e;
      }

      expect(caught.toString(), startsWith('Exception: '));
      // Nothing about that reaches a surface: the surface asks for the reason.
      expect(
        UpdateService.failureReason(caught),
        const UpdateCheckFailedUnexpectedly(),
      );
    });
  });
}
