import '../../generated/app_localizations.dart';

/// Where a release can always be fetched by hand when the application cannot
/// install it itself.
///
/// It lives next to the sentences rather than inside the update service
/// because every one of them ends by naming it, and a URL is never a
/// translator's to own: it is substituted into the translated sentence as a
/// placeholder, the same way a package manager's name is (#389).
const String releasesPageUrl =
    'https://github.com/kartalbas/flutter-gitui/releases';

/// Why an update check produced no answer.
///
/// A value of this type is data, never prose. It is persisted into the
/// configuration as a stable [code] plus its [data] and turned into a sentence
/// by [UpdateFailureMessages.message] in whatever locale is active at the
/// moment it is shown.
///
/// That indirection is the point. The previous design stored the finished
/// English sentence in `UpdatesConfig.lastCheckDetail`, so the language of a
/// failure was frozen at the moment it happened: a user who switched locale
/// afterwards kept reading the old one until the next check overwrote it, and
/// a German user who switched to English kept German. Persisting rendered
/// prose was the defect; the missing translation was only its symptom (#393).
///
/// Two reasons are equal exactly when they persist identically, which is what
/// a round-trip test needs to assert and all any caller can meaningfully ask.
sealed class UpdateFailureReason {
  const UpdateFailureReason();

  /// Stable identifier written to the configuration file.
  ///
  /// Never rename one: a value already on a user's disk is read back by the
  /// next version of the application, and a renamed code silently degrades to
  /// "no detail" there.
  String get code;

  /// The structured parts of the sentence, as scalars a YAML round-trip
  /// preserves exactly. Empty for a reason that needs no data of its own.
  Map<String, Object> get data => const <String, Object>{};

  /// The reason stored under `code` in [stored], or null when nothing usable
  /// is there.
  ///
  /// A code this version does not know -- a configuration written by a newer
  /// build -- and data that does not parse both degrade to null rather than
  /// throwing. The outcome itself ("the check failed") is stored separately
  /// and still shown; inventing a sentence for a reason that cannot be
  /// reconstructed would say more than is known.
  static UpdateFailureReason? fromStored(Map<dynamic, dynamic>? stored) {
    if (stored == null) return null;
    final code = stored['code'];
    if (code is! String) return null;

    int? intOf(String key) {
      final value = stored[key];
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    String? stringOf(String key) {
      final value = stored[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    switch (code) {
      case UpdateNoReleasePublished.storedCode:
        return const UpdateNoReleasePublished();
      case UpdateReleaseListUnavailable.storedCode:
        final status = intOf('status');
        return status == null ? null : UpdateReleaseListUnavailable(status);
      case UpdateRateLimited.storedCode:
        // The only reason whose data may go missing without taking the reason
        // with it: "try again later" is a form the sentence already has, so a
        // rate limit without a readable instant still says something true.
        final retryAt = stringOf('retry_at');
        return UpdateRateLimited(
          retryAt == null ? null : DateTime.tryParse(retryAt),
        );
      case UpdateManifestUnavailable.storedCode:
        final tag = stringOf('tag');
        final status = intOf('status');
        if (tag == null || status == null) return null;
        return UpdateManifestUnavailable(tag: tag, statusCode: status);
      case UpdateReleaseNotInstallable.storedCode:
        final tag = stringOf('tag');
        return tag == null ? null : UpdateReleaseNotInstallable(tag);
      case UpdateNetworkUnreachable.storedCode:
        return const UpdateNetworkUnreachable();
      case UpdateCheckTimedOut.storedCode:
        final seconds = intOf('seconds');
        return seconds == null ? null : UpdateCheckTimedOut(seconds);
      case UpdateResponseUnreadable.storedCode:
        return const UpdateResponseUnreadable();
      case UpdatePlatformUnsupported.storedCode:
        return const UpdatePlatformUnsupported();
      case UpdateCheckFailedUnexpectedly.storedCode:
        return const UpdateCheckFailedUnexpectedly();
      default:
        return null;
    }
  }

  /// The configuration entry this reason is stored as: the code and its data
  /// in one flat map, so a reader needs nothing but [fromStored] to invert it.
  Map<String, Object> toStored() => <String, Object>{'code': code, ...data};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdateFailureReason &&
          other.code == code &&
          other._dataKey == _dataKey;

  @override
  int get hashCode => Object.hash(code, _dataKey);

  @override
  String toString() => _dataKey.isEmpty ? code : '$code($_dataKey)';

  /// The data in one canonical, order-independent string, so equality and
  /// hashing agree with "these two persist identically".
  String get _dataKey {
    final entries = data.entries.map((e) => '${e.key}=${e.value}').toList()
      ..sort();
    return entries.join(',');
  }
}

/// The channel this build follows has no published release at all.
///
/// Not the same as being up to date: a channel that publishes nothing is a
/// broken update channel, and reporting it as "current" would hide that for as
/// long as it lasts.
final class UpdateNoReleasePublished extends UpdateFailureReason {
  static const String storedCode = 'no_release_published';

  const UpdateNoReleasePublished();

  @override
  String get code => storedCode;
}

/// GitHub refused to list the releases, with an HTTP status that is not a
/// rate limit.
final class UpdateReleaseListUnavailable extends UpdateFailureReason {
  static const String storedCode = 'release_list_unavailable';

  final int statusCode;

  const UpdateReleaseListUnavailable(this.statusCode);

  @override
  String get code => storedCode;

  @override
  Map<String, Object> get data => <String, Object>{'status': statusCode};
}

/// The unauthenticated request quota for this network is exhausted.
///
/// [retryAt] is the instant the quota resets, taken from GitHub's
/// `x-ratelimit-reset` header, and null when the header was absent or
/// unreadable. Storing the instant rather than "in about 40 minutes" is what
/// keeps the sentence true when it is shown again on a later launch: a wait
/// that has since elapsed renders as the plain "try again later" form instead
/// of counting down from a moment that has passed.
final class UpdateRateLimited extends UpdateFailureReason {
  static const String storedCode = 'rate_limited';

  final DateTime? retryAt;

  const UpdateRateLimited(this.retryAt);

  @override
  String get code => storedCode;

  @override
  Map<String, Object> get data => retryAt == null
      ? const <String, Object>{}
      : <String, Object>{'retry_at': retryAt!.toUtc().toIso8601String()};
}

/// The release's own update manifest could not be downloaded.
final class UpdateManifestUnavailable extends UpdateFailureReason {
  static const String storedCode = 'manifest_unavailable';

  final String tag;
  final int statusCode;

  const UpdateManifestUnavailable({
    required this.tag,
    required this.statusCode,
  });

  @override
  String get code => storedCode;

  @override
  Map<String, Object> get data => <String, Object>{
    'tag': tag,
    'status': statusCode,
  };
}

/// The release exists but publishes nothing this platform can install.
///
/// One reason for three findings -- no manifest asset, no archive asset, or an
/// archive name the updater refuses as unsafe -- because the user's move is
/// the same in all three and only the log can act on the difference. The log
/// records which of them it was.
final class UpdateReleaseNotInstallable extends UpdateFailureReason {
  static const String storedCode = 'release_not_installable';

  final String tag;

  const UpdateReleaseNotInstallable(this.tag);

  @override
  String get code => storedCode;

  @override
  Map<String, Object> get data => <String, Object>{'tag': tag};
}

/// Offline, blocked by a proxy, or unable to resolve the host.
///
/// All of these arrive as a socket, TLS or HTTP client failure and all mean
/// the same thing to the user.
final class UpdateNetworkUnreachable extends UpdateFailureReason {
  static const String storedCode = 'network_unreachable';

  const UpdateNetworkUnreachable();

  @override
  String get code => storedCode;
}

/// GitHub did not answer within the request timeout.
final class UpdateCheckTimedOut extends UpdateFailureReason {
  static const String storedCode = 'timed_out';

  final int seconds;

  const UpdateCheckTimedOut(this.seconds);

  @override
  String get code => storedCode;

  @override
  Map<String, Object> get data => <String, Object>{'seconds': seconds};
}

/// The answer arrived but this version cannot read it.
final class UpdateResponseUnreadable extends UpdateFailureReason {
  static const String storedCode = 'response_unreadable';

  const UpdateResponseUnreadable();

  @override
  String get code => storedCode;
}

/// No release archive is published for the platform this build runs on.
final class UpdatePlatformUnsupported extends UpdateFailureReason {
  static const String storedCode = 'platform_unsupported';

  const UpdatePlatformUnsupported();

  @override
  String get code => storedCode;
}

/// Something else went wrong; the log is the only place that can name it.
final class UpdateCheckFailedUnexpectedly extends UpdateFailureReason {
  static const String storedCode = 'unknown';

  const UpdateCheckFailedUnexpectedly();

  @override
  String get code => storedCode;
}

/// The sentence a failure reason turns into, in the locale that is active now.
///
/// A translation rather than a field, so adding a locale is an `.arb` entry
/// and nothing else, and so a reason persisted under one language renders
/// under whichever one is in force when it is read back (#393).
extension UpdateFailureMessages on UpdateFailureReason {
  /// What to tell the user about this failure, and what they can do about it.
  ///
  /// [now] exists so the rate-limit wording is provable in a test; it defaults
  /// to the wall clock, which is what every caller wants.
  String message(AppLocalizations l10n, {DateTime? now}) => switch (this) {
    UpdateNoReleasePublished() => l10n.updateFailureNoRelease(releasesPageUrl),
    UpdateReleaseListUnavailable(:final statusCode) =>
      l10n.updateFailureReleaseList(statusCode, releasesPageUrl),
    UpdateRateLimited(:final retryAt) => _rateLimitMessage(
      l10n,
      retryAt,
      now ?? DateTime.now(),
    ),
    UpdateManifestUnavailable(:final tag, :final statusCode) =>
      l10n.updateFailureManifestUnavailable(tag, statusCode, releasesPageUrl),
    UpdateReleaseNotInstallable(:final tag) =>
      l10n.updateFailureReleaseNotInstallable(tag, releasesPageUrl),
    UpdateNetworkUnreachable() => l10n.updateFailureNetworkUnreachable(
      releasesPageUrl,
    ),
    UpdateCheckTimedOut(:final seconds) => l10n.updateFailureTimedOut(
      seconds,
      releasesPageUrl,
    ),
    UpdateResponseUnreadable() => l10n.updateFailureResponseUnreadable(
      releasesPageUrl,
    ),
    UpdatePlatformUnsupported() => l10n.updateFailurePlatformUnsupported(
      releasesPageUrl,
    ),
    UpdateCheckFailedUnexpectedly() => l10n.updateFailureUnknown(
      releasesPageUrl,
    ),
  };

  /// A rate limit that resets in the future names the time it lifts; one that
  /// has already lifted -- which is what a persisted reason usually is by the
  /// time it is read again -- says only "try again later", because naming a
  /// clock time in the past would read as an instruction to wait for
  /// yesterday.
  String _rateLimitMessage(
    AppLocalizations l10n,
    DateTime? retryAt,
    DateTime now,
  ) {
    if (retryAt == null || !retryAt.isAfter(now)) {
      return l10n.updateFailureRateLimited(releasesPageUrl);
    }
    final local = retryAt.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return l10n.updateFailureRateLimitedUntil(
      '${two(local.hour)}:${two(local.minute)}',
      releasesPageUrl,
    );
  }
}

/// Why a release that was found cannot be installed from inside the
/// application, even though the check itself succeeded.
///
/// Distinct from every [UpdateFailureReason]: nothing failed, and the user is
/// not being told to try again. There is a new version, it is named, and the
/// one thing missing is this application's permission to replace itself with
/// it.
enum ManualInstallReason {
  /// The published macOS archive carries no Developer ID signature and no
  /// notarisation ticket, so the release job flagged it `signed: false`.
  ///
  /// Swapping a bundle the user once allowed through Gatekeeper for one macOS
  /// cannot verify risks leaving them with an application that will not open
  /// at all, and this project has no Mac on which that could be tried. Until
  /// signing is configured, the honest move is to name the version and point
  /// at the download (#387).
  unsignedMacosRelease,
}

/// The sentence a manual-install reason turns into, in the active locale.
extension ManualInstallMessages on ManualInstallReason {
  /// What to tell the user about the release found in [version].
  String message(AppLocalizations l10n, String version) => switch (this) {
    ManualInstallReason.unsignedMacosRelease =>
      l10n.updateManualInstallUnsigned(version, releasesPageUrl),
  };
}
