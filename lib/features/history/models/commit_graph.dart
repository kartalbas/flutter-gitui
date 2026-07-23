import '../../../core/git/models/commit.dart';

/// One vertical connection through a row of the commit graph.
///
/// [lane] names the column where the edge meets the row boundary; the other
/// endpoint is implied by which list of [CommitGraphRow] carries the edge.
/// [colorIndex] is a running per-branch counter rather than a resolved color,
/// so the model stays free of rendering concerns and a branch keeps one color
/// from the row that opened its lane to the row that closes it.
class GraphEdge {
  const GraphEdge(this.lane, this.colorIndex);

  final int lane;
  final int colorIndex;
}

/// The graph geometry of a single commit row.
class CommitGraphRow {
  const CommitGraphRow({
    required this.lane,
    required this.colorIndex,
    required this.isMerge,
    required this.incoming,
    required this.outgoing,
    required this.passing,
  });

  /// Column of the commit's dot.
  final int lane;

  /// Color counter of the dot and of the lane segment it continues.
  final int colorIndex;

  /// Whether the commit joins several parents, so the renderer can mark it.
  final bool isMerge;

  /// Edges from the top row boundary into the dot, one per child lane the
  /// commit resolves.
  final List<GraphEdge> incoming;

  /// Edges from the dot to the bottom row boundary, one per parent shown or
  /// stubbed below.
  final List<GraphEdge> outgoing;

  /// Lanes running straight through the row without touching the dot.
  final List<GraphEdge> passing;
}

/// Lane assignment for a window of commits in topological order.
///
/// Built once per loaded window and looked up per row, so scrolling and
/// rebuilds never re-run the pass. Pure Dart on purpose: the geometry is
/// testable without a widget tree, and the painter stays a dumb projection
/// of it.
class CommitGraph {
  CommitGraph._(this.rows, this.laneCount, this._rowIndexByHash);

  /// One row per commit, in the same order as the window it was built from.
  final List<CommitGraphRow> rows;

  /// Columns needed at the window's widest point, for sizing the column.
  final int laneCount;

  final Map<String, int> _rowIndexByHash;

  CommitGraphRow? rowFor(String hash) {
    final index = _rowIndexByHash[hash];
    return index == null ? null : rows[index];
  }

  /// Walks the window once, top to bottom, turning parent links into columns.
  ///
  /// Assumes children sort above their parents (git's `--topo-order`). A row
  /// violating that merely leaves its lane running to the window's end; the
  /// pass never fails on it.
  factory CommitGraph.fromCommits(List<GitCommit> commits) {
    // Doubles as the membership test: a parent beyond the window must not
    // keep a lane open for the remainder of the list.
    final rowIndexByHash = <String, int>{
      for (var i = 0; i < commits.length; i++) commits[i].hash: i,
    };

    final lanes = <_Lane?>[];
    var nextColorIndex = 0;
    final rows = <CommitGraphRow>[];

    // Reusing the leftmost freed slot keeps the graph as narrow as the
    // history allows instead of drifting rightwards with every branch.
    int allocate(_Lane laneState) {
      final free = lanes.indexOf(null);
      if (free >= 0) {
        lanes[free] = laneState;
        return free;
      }
      lanes.add(laneState);
      return lanes.length - 1;
    }

    for (final commit in commits) {
      final wasActive = [for (final laneState in lanes) laneState != null];

      // Every lane whose expected commit this row resolves: each one is a
      // child drawn above, and they all converge on this dot.
      final waiting = <int>[
        for (var j = 0; j < lanes.length; j++)
          if (lanes[j]?.expectedHash == commit.hash) j,
      ];

      final incoming = <GraphEdge>[
        for (final j in waiting) GraphEdge(j, lanes[j]!.colorIndex),
      ];

      int lane;
      int colorIndex;
      if (waiting.isEmpty) {
        // A tip: nothing drawn above references it, so it opens a fresh lane
        // with a fresh color.
        colorIndex = nextColorIndex++;
        lane = allocate(_Lane('', colorIndex));
      } else {
        lane = waiting.first;
        colorIndex = lanes[lane]!.colorIndex;
        // The other children's lanes end at this dot; freeing their slots is
        // what lets a later branch reuse the columns.
        for (final j in waiting.skip(1)) {
          lanes[j] = null;
        }
      }

      final outgoing = <GraphEdge>[];
      final parents = commit.parents;
      if (parents.isEmpty) {
        // A root: the lane closes with the dot.
        lanes[lane] = null;
      } else if (rowIndexByHash.containsKey(parents.first)) {
        // The first parent continues the branch in the commit's own column.
        lanes[lane] = _Lane(parents.first, colorIndex);
        outgoing.add(GraphEdge(lane, colorIndex));
      } else {
        // The first parent lies beyond the window. A stub below the dot shows
        // the history continuing, but the lane must free: kept open it would
        // never resolve, and in a path-scoped window - where almost no
        // commit's parent is shown - one dead column per row would pile up.
        outgoing.add(GraphEdge(lane, colorIndex));
        lanes[lane] = null;
      }

      for (final parent in parents.skip(1)) {
        if (!rowIndexByHash.containsKey(parent)) {
          // The ring-shaped merge dot alone marks this merge; a stub would
          // claim a column for a lane that is never drawn.
          continue;
        }
        // When a drawn branch already heads for this parent, the merge edge
        // joins that lane - that junction is precisely where the branch was
        // merged back. Only otherwise does the merged branch open a lane.
        var target = -1;
        for (var j = 0; j < lanes.length; j++) {
          if (j != lane && lanes[j]?.expectedHash == parent) {
            target = j;
            break;
          }
        }
        if (target >= 0) {
          outgoing.add(GraphEdge(target, lanes[target]!.colorIndex));
        } else {
          final mergeColorIndex = nextColorIndex++;
          outgoing.add(
            GraphEdge(
              allocate(_Lane(parent, mergeColorIndex)),
              mergeColorIndex,
            ),
          );
        }
      }

      // Lanes active before the row and untouched by it draw straight
      // through. Slots the dot consumed or reopened this row are excluded,
      // or a closed-and-reused column would paint a line it no longer has.
      final passing = <GraphEdge>[
        for (var j = 0; j < wasActive.length; j++)
          if (wasActive[j] && j != lane && !waiting.contains(j))
            GraphEdge(j, lanes[j]!.colorIndex),
      ];

      rows.add(
        CommitGraphRow(
          lane: lane,
          colorIndex: colorIndex,
          isMerge: parents.length > 1,
          incoming: List.unmodifiable(incoming),
          outgoing: List.unmodifiable(outgoing),
          passing: List.unmodifiable(passing),
        ),
      );
    }

    return CommitGraph._(List.unmodifiable(rows), lanes.length, rowIndexByHash);
  }
}

/// A column that is waiting for [expectedHash] to appear further down.
class _Lane {
  _Lane(this.expectedHash, this.colorIndex);

  final String expectedHash;
  final int colorIndex;
}
