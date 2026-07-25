// The dashboard's "Up to date" badge used to appear whenever the local
// ahead/behind counts were zero. Those counts come from the remote-tracking
// refs, which only move on a fetch, so a repository with incoming commits still
// counted as zero behind and the card claimed a clean state nobody had checked.
// isRemoteUnchecked is what now separates verified from merely unknown, so the
// exact conditions are pinned here.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/workspace/models/repository_status.dart';

void main() {
  final checkedAt = DateTime.utc(2026, 7, 25, 12);

  group('RepositoryStatus.isRemoteUnchecked', () {
    test('a tracked repository that was never fetched is unchecked', () {
      const status = RepositoryStatus(
        exists: true,
        isValidGit: true,
        hasRemote: true,
      );
      expect(status.isRemoteUnchecked, isTrue);
    });

    test('a fetched repository is no longer unchecked', () {
      final status = RepositoryStatus(
        exists: true,
        isValidGit: true,
        hasRemote: true,
        remoteCheckedAt: checkedAt,
      );
      expect(status.isRemoteUnchecked, isFalse);
    });

    test('a repository without a remote has nothing to verify', () {
      // Purely local work is genuinely in sync with everything it tracks.
      const status = RepositoryStatus(exists: true, isValidGit: true);
      expect(status.isRemoteUnchecked, isFalse);
    });

    test('a broken repository reports broken, not unchecked', () {
      const status = RepositoryStatus(
        exists: false,
        isValidGit: false,
        hasRemote: true,
      );
      expect(status.isRemoteUnchecked, isFalse);
      expect(status.isBroken, isTrue);
    });

    test('an unconfigured git reports that, not unchecked', () {
      expect(RepositoryStatus.gitNotConfigured.isRemoteUnchecked, isFalse);
    });

    test('counts stay authoritative once they are known', () {
      // Being unchecked concerns only the clean case: a repository already
      // known to be behind must keep reporting it.
      const status = RepositoryStatus(
        exists: true,
        isValidGit: true,
        hasRemote: true,
        commitsBehind: 3,
      );
      expect(status.hasIncoming, isTrue);
      expect(status.needsAttention, isTrue);
    });
  });
}
