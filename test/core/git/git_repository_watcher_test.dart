// The watcher's ignore filter is the line that keeps `.git/objects` churn from
// spawning a status refresh (and the CPU storm that motivated #312). It must
// behave identically whatever separator the platform's watcher emits, so both
// POSIX ('/') and Windows ('\\') paths are pinned here, together with the git
// paths that MUST get through (a branch switch, a commit, a staging change).

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/git/git_repository_watcher.dart';

void main() {
  group('GitRepositoryWatcher.shouldIgnorePath', () {
    test('ignores .git/objects churn with either separator', () {
      expect(
        GitRepositoryWatcher.shouldIgnorePath(
          '/home/me/repo/.git/objects/ab/cdef',
        ),
        isTrue,
      );
      expect(
        GitRepositoryWatcher.shouldIgnorePath(
          r'C:\Users\me\repo\.git\objects\pack\pack-1.pack',
        ),
        isTrue,
      );
    });

    test('ignores the other noisy .git subdirectories on both platforms', () {
      for (final path in [
        '/repo/.git/logs/HEAD',
        r'C:\repo\.git\logs\HEAD',
        '/repo/.git/hooks/pre-commit',
        r'C:\repo\.git\info\exclude',
        '/repo/.git/refs/remotes/origin/main',
        r'C:\repo\.git\refs\remotes\origin\main',
      ]) {
        expect(
          GitRepositoryWatcher.shouldIgnorePath(path),
          isTrue,
          reason: path,
        );
      }
    });

    test('ignores git lock files on both platforms', () {
      for (final path in [
        '/repo/.git/index.lock',
        r'C:\repo\.git\index.lock',
        '/repo/.git/HEAD.lock',
        r'C:\repo\.git\packed-refs.lock',
      ]) {
        expect(
          GitRepositoryWatcher.shouldIgnorePath(path),
          isTrue,
          reason: path,
        );
      }
    });

    test('lets working-tree changes through so the status refreshes', () {
      for (final path in [
        '/repo/lib/main.dart',
        r'C:\repo\lib\main.dart',
        '/repo/README.md',
      ]) {
        expect(
          GitRepositoryWatcher.shouldIgnorePath(path),
          isFalse,
          reason: path,
        );
      }
    });

    test('lets branch, commit and staging changes through', () {
      // HEAD (branch switch), refs/heads (new commit / branch), index (staging)
      // are exactly the .git changes the UI must react to, on both platforms.
      for (final path in [
        '/repo/.git/HEAD',
        r'C:\repo\.git\HEAD',
        '/repo/.git/refs/heads/main',
        r'C:\repo\.git\refs\heads\main',
        '/repo/.git/index',
        r'C:\repo\.git\index',
        '/repo/.git/MERGE_HEAD',
      ]) {
        expect(
          GitRepositoryWatcher.shouldIgnorePath(path),
          isFalse,
          reason: path,
        );
      }
    });
  });
}
