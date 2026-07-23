// The lane pass is the history graph's whole geometry: which column a commit
// occupies and which columns its edges touch. Asserting lanes and edges here,
// against hand-drawn histories, is what lets the painter stay a projection
// with nothing of its own to test.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/git/models/commit.dart';
import 'package:flutter_gitui/features/history/models/commit_graph.dart';

GitCommit commit(String hash, {List<String> parents = const []}) {
  final when = DateTime.utc(2026);
  return GitCommit(
    hash: hash,
    shortHash: hash,
    author: 'a',
    authorEmail: 'a@example.com',
    authorDate: when,
    committer: 'a',
    committerEmail: 'a@example.com',
    committerDate: when,
    subject: 's',
    body: '',
    parents: parents,
    refs: const [],
  );
}

List<int> lanesOf(List<GraphEdge> edges) => [for (final e in edges) e.lane];

void main() {
  group('lane assignment', () {
    test('a linear history stays in one lane', () {
      final graph = CommitGraph.fromCommits([
        commit('a', parents: ['b']),
        commit('b', parents: ['c']),
        commit('c'),
      ]);

      expect(graph.laneCount, 1);
      expect([for (final r in graph.rows) r.lane], [0, 0, 0]);

      final tip = graph.rows[0];
      expect(tip.incoming, isEmpty);
      expect(lanesOf(tip.outgoing), [0]);

      final middle = graph.rows[1];
      expect(lanesOf(middle.incoming), [0]);
      expect(lanesOf(middle.outgoing), [0]);

      final root = graph.rows[2];
      expect(lanesOf(root.incoming), [0]);
      expect(root.outgoing, isEmpty);
    });

    test('a branch and its merge occupy a second lane between the two', () {
      // m merges b back into the a-line; the fork point is c.
      final graph = CommitGraph.fromCommits([
        commit('m', parents: ['a', 'b']),
        commit('a', parents: ['c']),
        commit('b', parents: ['c']),
        commit('c'),
      ]);

      expect(graph.laneCount, 2);

      // The merge is readable as two departing edges: one continuing its own
      // lane, one reaching into the merged branch's lane.
      final merge = graph.rows[0];
      expect(merge.lane, 0);
      expect(merge.isMerge, isTrue);
      expect(lanesOf(merge.outgoing), [0, 1]);

      // While both branches exist, each one's rows show the other passing.
      expect(graph.rows[1].lane, 0);
      expect(lanesOf(graph.rows[1].passing), [1]);
      expect(graph.rows[2].lane, 1);
      expect(lanesOf(graph.rows[2].passing), [0]);

      // The branch lane keeps its own color from merge down to fork.
      expect(graph.rows[2].colorIndex, isNot(graph.rows[1].colorIndex));

      // The fork point is readable as both lanes converging on one dot.
      final fork = graph.rows[3];
      expect(fork.lane, 0);
      expect(lanesOf(fork.incoming), [0, 1]);
      expect(fork.outgoing, isEmpty);
    });

    test('two concurrent branches converge at their common ancestor', () {
      final graph = CommitGraph.fromCommits([
        commit('x', parents: ['c']),
        commit('y', parents: ['c']),
        commit('c'),
      ]);

      expect(graph.laneCount, 2);
      expect(graph.rows[0].lane, 0);

      // y is a tip of its own: nothing above points at it, so it opens a
      // second lane instead of joining x's.
      expect(graph.rows[1].lane, 1);
      expect(graph.rows[1].incoming, isEmpty);
      expect(lanesOf(graph.rows[1].passing), [0]);

      expect(lanesOf(graph.rows[2].incoming), [0, 1]);
    });

    test('an octopus merge departs into one lane per parent', () {
      final graph = CommitGraph.fromCommits([
        commit('o', parents: ['a', 'b', 'c']),
        commit('a', parents: ['r']),
        commit('b', parents: ['r']),
        commit('c', parents: ['r']),
        commit('r'),
      ]);

      expect(graph.laneCount, 3);

      final octopus = graph.rows[0];
      expect(octopus.isMerge, isTrue);
      expect(lanesOf(octopus.outgoing), [0, 1, 2]);

      expect(graph.rows[1].lane, 0);
      expect(graph.rows[2].lane, 1);
      expect(graph.rows[3].lane, 2);
      expect(lanesOf(graph.rows[4].incoming), [0, 1, 2]);
    });

    test('a root commit closes its lane', () {
      final graph = CommitGraph.fromCommits([commit('r')]);

      final root = graph.rows.single;
      expect(root.lane, 0);
      expect(root.incoming, isEmpty);
      expect(root.outgoing, isEmpty);
      expect(root.passing, isEmpty);
    });

    test('a merge into a branch already drawn joins that lane', () {
      // d is another child of b, drawn first, so a lane is already heading
      // for b when the merge m needs it.
      final graph = CommitGraph.fromCommits([
        commit('d', parents: ['b']),
        commit('m', parents: ['a', 'b']),
        commit('a', parents: ['c']),
        commit('b', parents: ['c']),
        commit('c'),
      ]);

      // The merge edge reaches into lane 0 instead of opening a duplicate
      // lane for the same parent; lane 0 itself keeps running through.
      final merge = graph.rows[1];
      expect(merge.lane, 1);
      expect(lanesOf(merge.outgoing), [1, 0]);
      expect(lanesOf(merge.passing), [0]);
      expect(graph.laneCount, 2);
    });

    test('a parent beyond the window leaves a stub and frees the lane', () {
      final graph = CommitGraph.fromCommits([
        commit('a', parents: ['missing']),
        commit('b'),
      ]);

      // The stub below the dot shows the history continuing outside the
      // window without keeping a lane open that could never resolve...
      expect(lanesOf(graph.rows[0].outgoing), [0]);

      // ...which is what lets the next tip reuse the column.
      expect(graph.rows[1].lane, 0);
      expect(graph.rows[1].passing, isEmpty);
      expect(graph.laneCount, 1);
    });

    test('rows are found by hash, in window order', () {
      final graph = CommitGraph.fromCommits([
        commit('a', parents: ['b']),
        commit('b'),
      ]);

      expect(graph.rowFor('a'), same(graph.rows[0]));
      expect(graph.rowFor('b'), same(graph.rows[1]));
      expect(graph.rowFor('missing'), isNull);
    });
  });
}
