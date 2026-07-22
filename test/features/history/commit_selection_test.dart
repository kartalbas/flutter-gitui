// The one rule that resolves a stored selection against the commits the
// history view is showing, and the click and keyboard transitions that produce
// it. Every destructive action reads the resolved value, so a mistake here
// lands a reset or a revert on a commit the user was not looking at.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/legacy.dart';

import 'package:flutter_gitui/core/config/config_providers.dart';
import 'package:flutter_gitui/core/git/models/commit.dart';
import 'package:flutter_gitui/features/history/providers/commit_selection_provider.dart';

GitCommit commit(String hash) {
  final date = DateTime.utc(2026);
  return GitCommit(
    hash: hash,
    shortHash: hash,
    author: 'a',
    authorEmail: 'a@example.com',
    authorDate: date,
    committer: 'a',
    committerEmail: 'a@example.com',
    committerDate: date,
    subject: 's',
    body: '',
    parents: const [],
    refs: const [],
  );
}

final commitA = commit('aaa');
final commitB = commit('bbb');
final commitC = commit('ccc');
final commitD = commit('ddd');

/// Newest first, the order the history list renders.
final displayed = [commitA, commitB, commitC, commitD];

List<String> hashesOf(List<GitCommit> commits) => [
  for (final c in commits) c.hash,
];

final displayedHashes = hashesOf(displayed);

extension on CommitSelection {
  CommitSelection click(
    String hash, {
    bool control = false,
    bool shift = false,
  }) => clicked(
    hash: hash,
    displayedHashes: displayedHashes,
    isControlPressed: control,
    isShiftPressed: shift,
  );
}

void main() {
  group('resolve', () {
    test('keeps only commits present in the displayed list', () {
      const selection = CommitSelection(
        hashes: {'aaa', 'zzz', 'ccc'},
        primaryHash: 'ccc',
      );

      final resolved = selection.resolve(displayed);

      expect(hashesOf(resolved.commits), ['aaa', 'ccc']);
      expect(resolved.primary, commitC);
    });

    test('returns display order, not selection order', () {
      const selection = CommitSelection(
        hashes: {'ddd', 'aaa', 'ccc'},
        primaryHash: 'ddd',
      );

      expect(hashesOf(selection.resolve(displayed).commits), [
        'aaa',
        'ccc',
        'ddd',
      ]);
    });

    test('a selection with nothing displayed resolves to empty', () {
      const selection = CommitSelection(
        hashes: {'zzz', 'yyy'},
        primaryHash: 'zzz',
      );

      final resolved = selection.resolve(displayed);

      expect(resolved.isEmpty, isTrue);
      expect(resolved.primary, isNull);
      expect(resolved.single, isNull);
    });

    test('a hash from another repository can never reach an action', () {
      // Nothing survives, so no action button is offered and every action's
      // own precondition fails as well.
      const foreign = CommitSelection(
        hashes: {'foreign-hash'},
        primaryHash: 'foreign-hash',
      );

      final resolved = foreign.resolve(displayed);

      expect(resolved.count, 0);
      expect(resolved.hashes, isEmpty);
      expect(resolved.oldestFirst, isEmpty);
      expect(resolved.single, isNull);
    });

    test('promotes a survivor when the primary is filtered out', () {
      const selection = CommitSelection(
        hashes: {'bbb', 'ddd', 'zzz'},
        primaryHash: 'zzz',
      );

      final resolved = selection.resolve(displayed);

      expect(resolved.primary, commitB);
      expect(resolved.commits, contains(commitD));
    });

    test('the primary is always one of the resolved commits', () {
      const selection = CommitSelection(
        hashes: {'ccc', 'ddd'},
        primaryHash: 'ddd',
      );

      final resolved = selection.resolve(displayed);

      expect(resolved.commits, contains(resolved.primary));
    });

    test('an empty selection resolves to empty', () {
      expect(CommitSelection.empty.resolve(displayed).isEmpty, isTrue);
      expect(CommitSelection.empty.resolve(const []).isEmpty, isTrue);
    });

    test('single is null unless exactly one commit survives', () {
      const one = CommitSelection(hashes: {'aaa', 'zzz'}, primaryHash: 'aaa');
      const two = CommitSelection(hashes: {'aaa', 'bbb'}, primaryHash: 'aaa');

      expect(one.resolve(displayed).single, commitA);
      expect(two.resolve(displayed).single, isNull);
    });

    test('oldestFirst reverses display order for replaying', () {
      const selection = CommitSelection(
        hashes: {'aaa', 'ccc', 'ddd'},
        primaryHash: 'aaa',
      );

      expect(hashesOf(selection.resolve(displayed).oldestFirst), [
        'ddd',
        'ccc',
        'aaa',
      ]);
    });
  });

  group('click handling', () {
    test('a plain click replaces the selection', () {
      final selection = CommitSelection.empty.click('aaa').click('ccc');

      expect(selection.hashes, {'ccc'});
      expect(selection.primaryHash, 'ccc');
    });

    test('ctrl-click adds and removes', () {
      final added = CommitSelection.empty
          .click('aaa')
          .click('ccc', control: true);
      expect(added.hashes, {'aaa', 'ccc'});

      final removed = added.click('ccc', control: true);
      expect(removed.hashes, {'aaa'});
      expect(removed.primaryHash, 'aaa');
    });

    test('deselecting the primary hands the role to a survivor', () {
      final selection = CommitSelection.empty
          .click('aaa')
          .click('ccc', control: true)
          .click('ccc', control: true);

      expect(selection.primaryHash, 'aaa');
      expect(selection.resolve(displayed).primary, commitA);
    });

    test('ctrl-clicking away the last commit leaves no primary', () {
      final selection = CommitSelection.empty
          .click('aaa')
          .click('aaa', control: true);

      expect(selection.isEmpty, isTrue);
      expect(selection.primaryHash, isNull);
      expect(selection.resolve(displayed).primary, isNull);
    });

    test('shift-click selects the range in both directions', () {
      final upwards = CommitSelection.empty
          .click('ccc')
          .click('aaa', shift: true);
      expect(upwards.hashes, {'aaa', 'bbb', 'ccc'});

      final downwards = CommitSelection.empty
          .click('bbb')
          .click('ddd', shift: true);
      expect(downwards.hashes, {'bbb', 'ccc', 'ddd'});
    });

    test(
      'shift-click re-anchors so the next one grows from where it ended',
      () {
        final selection = CommitSelection.empty
            .click('bbb')
            .click('ccc', shift: true)
            .click('ddd', shift: true);

        expect(selection.hashes, {'ccc', 'ddd'});
        expect(selection.primaryHash, 'ddd');
      },
    );

    test('a range with an undisplayed endpoint collapses to a single', () {
      // A refilter that dropped the anchor leaves it unresolvable.
      final selection = CommitSelection.empty.click('aaa').rangeTo(
        'ccc',
        const ['ccc', 'ddd'],
      );

      expect(selection.hashes, {'ccc'});
      expect(selection.primaryHash, 'ccc');
    });

    test('shift without an anchor behaves like a plain click', () {
      final selection = CommitSelection.empty.click('bbb', shift: true);

      expect(selection.hashes, {'bbb'});
      expect(selection.primaryHash, 'bbb');
    });
  });

  group('keyboard movement', () {
    test('writes the same value a click does, so actions see it', () {
      final moved = CommitSelection.empty.moved(displayed, 1);

      expect(moved, CommitSelection.empty.click('aaa'));
      expect(moved.resolve(displayed).single, commitA);
    });

    test('steps through the list and stops at both ends', () {
      final second = CommitSelection.empty
          .moved(displayed, 1)
          .moved(displayed, 1);
      expect(second.primaryHash, 'bbb');

      final back = second.moved(displayed, -1).moved(displayed, -1);
      expect(back.primaryHash, 'aaa');

      var end = back;
      for (var i = 0; i < 10; i++) {
        end = end.moved(displayed, 1);
      }
      expect(end.primaryHash, 'ddd');
    });

    test('movement steps from the promoted survivor, not the raw primary', () {
      // A refilter dropped the primary zzz; resolve() promotes ccc and the
      // highlight follows it, so the arrow keys must step from that row
      // instead of jumping back to the top of the list.
      const selection = CommitSelection(
        hashes: {'ccc', 'zzz'},
        primaryHash: 'zzz',
      );

      expect(selection.moved(displayed, 1).primaryHash, 'ddd');
      expect(selection.moved(displayed, -1).primaryHash, 'bbb');
    });

    test('movement collapses a multi-selection to the target commit', () {
      const selection = CommitSelection(
        hashes: {'aaa', 'bbb', 'ccc'},
        primaryHash: 'bbb',
      );

      final moved = selection.moved(displayed, 1);

      expect(moved.hashes, {'ccc'});
      expect(moved.primaryHash, 'ccc');
    });

    test('a selection with no survivor at all restarts at the newest', () {
      final moved = CommitSelection.single('zzz').moved(displayed, 1);

      expect(moved.primaryHash, 'aaa');
    });

    test('an empty list leaves the selection untouched', () {
      final selection = CommitSelection.single('aaa');

      expect(selection.moved(const [], 1), selection);
    });
  });

  group('repository scope', () {
    test('switching repositories resets the selection', () {
      final repositoryPath = StateProvider<String?>((ref) => r'C:\repo-a');
      final container = ProviderContainer(
        overrides: [
          currentRepositoryPathProvider.overrideWith(
            (ref) => ref.watch(repositoryPath),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(commitSelectionProvider.notifier).selectSingle('aaa');
      expect(container.read(commitSelectionProvider).hashes, {'aaa'});

      // A hash names a commit in one repository only; a selection surviving
      // the switch would let an action run against a repository that never
      // contained it.
      container.read(repositoryPath.notifier).state = r'C:\repo-b';

      expect(container.read(commitSelectionProvider), CommitSelection.empty);
    });
  });

  group('equality', () {
    test('same hashes and primary compare equal regardless of order', () {
      const one = CommitSelection(
        hashes: {'aaa', 'bbb'},
        primaryHash: 'aaa',
        anchorHash: 'aaa',
      );
      const other = CommitSelection(
        hashes: {'bbb', 'aaa'},
        primaryHash: 'aaa',
        anchorHash: 'aaa',
      );

      expect(one, other);
      expect(one.hashCode, other.hashCode);
    });

    test('a different primary is a different selection', () {
      const one = CommitSelection(hashes: {'aaa', 'bbb'}, primaryHash: 'aaa');
      const other = CommitSelection(hashes: {'aaa', 'bbb'}, primaryHash: 'bbb');

      expect(one, isNot(other));
    });
  });
}
