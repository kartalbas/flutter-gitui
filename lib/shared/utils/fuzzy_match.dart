/// Approximate string matching for the command palette and the commit history
/// search.
///
/// This is implemented in-tree rather than taken from an off-the-shelf package
/// because the mature options are published under a copyleft licence whose
/// obligations are incompatible with the licence this application ships under,
/// and linking one into the binary would extend those obligations to every
/// published build. The algorithms used here are long published and owned by
/// nobody: the longest common subsequence for the palette, and for the history
/// search Sellers' approximate substring distance under optimal string
/// alignment, narrowed first by Myers' bit-parallel scan and, for queries
/// wider than a machine word, by pattern partitioning.
library;

import 'dart:typed_data';

/// Widest query, in characters, that fits one bit-parallel machine word.
///
/// Sixty-three rather than sixty-four leaves the sign bit clear, so the carry
/// of the addition step cannot turn an intermediate value negative.
const int _wordBits = 63;

/// Shortest query that is allowed any edit at all.
const int _minLengthForEdits = 6;

/// Edit budget granted to a query of [queryLength] characters.
///
/// The budget is a step function of the absolute query length, not a fraction
/// of it. A fraction hands short queries an edit they cannot afford: developer
/// prose is dense with everyday words one edit away from a five-letter git
/// verb, so "reset" starts matching "rest" and "clone" starts matching "close"
/// at every threshold that still tolerates a real typo, and no threshold
/// separates the two. Below [_minLengthForEdits] the query is therefore
/// matched as a plain substring, which is what someone typing a short command
/// name means. The budget stops growing for long queries because those are
/// normally pasted text, where tolerating many edits would drag in unrelated
/// messages without serving anything a user asked for.
int fuzzyEditBudget(int queryLength) {
  if (queryLength < _minLengthForEdits) return 0;
  if (queryLength < 12) return 1;
  if (queryLength < 24) return 2;
  return 3;
}

/// Similarity of [a] and [b] on a 0-100 scale.
///
/// Twice the length of the longest common subsequence over the combined
/// length. The command palette gates on an absolute number on this scale, so
/// the measure and that gate only mean anything together.
int similarityRatio(String a, String b) {
  final total = a.length + b.length;
  if (total == 0) return 0;
  return (200 * _longestCommonSubsequence(a, b) / total).round();
}

/// How well [query] matches the closest-fitting stretch of [text], on a 0-100
/// scale, or 0 when that match is worse than [minScore].
///
/// Scoring against the closest substring rather than the whole text is what
/// lets a query buried in a long commit message score as well as one standing
/// alone.
int partialMatchScore(String text, String query, {int minScore = 0}) {
  final m = query.length;
  if (m == 0 || text.isEmpty) return 0;
  final maxEdits = fuzzyEditBudget(m);
  final distance = approximateSubstringDistance(text, query, maxEdits);
  // Every result leaves through this one expression. A revision that grew a
  // second exit skipped the floor on it, and a long query then scored against
  // every message in the list.
  final score = distance > maxEdits ? 0 : (100 * (m - distance) / m).round();
  return score >= minScore ? score : 0;
}

/// Fewest edits under optimal string alignment turning [pattern] into some
/// substring of [text], or `maxEdits + 1` when nothing is that close.
///
/// Public so the scan can be held against a plain reference matrix at edit
/// budgets the shipped scoring never reaches.
int approximateSubstringDistance(String text, String pattern, int maxEdits) {
  if (text.contains(pattern)) return 0;
  if (maxEdits == 0) return 1;
  final m = pattern.length;
  final pieces = 2 * maxEdits + 1;
  final seedLength = _seedLengthFor(m, pieces);
  if (seedLength >= _minSeedLength) {
    return _seededDistance(text, pattern, maxEdits, pieces, seedLength);
  }
  if (m <= _wordBits) {
    return _scanAndVerify(text, pattern, maxEdits);
  }
  return _windowedAlignmentDistance(text, 0, text.length, pattern, maxEdits);
}

/// Locates plausible matches with a bit-parallel scan, then measures the few
/// survivors exactly.
///
/// The scan counts substitutions and gaps only, so it cannot score a
/// transposition as the single edit that alignment calls it. Rewriting one
/// transposition as two substitutions bounds the gap: a stretch within
/// `maxEdits` under alignment is always within `2 * maxEdits` for the scan, so
/// scanning at twice the budget can drop text but never a real match.
int _scanAndVerify(String text, String pattern, int maxEdits) {
  final m = pattern.length;
  final reach = 2 * maxEdits;
  final ends = _candidateEnds(text, pattern, reach);
  if (ends == null) return maxEdits + 1;

  int best = maxEdits + 1;
  int windowStart = _atLeastZero(ends[0] - m - reach);
  int windowEnd = ends[0];
  for (int i = 1; i <= ends.length; i++) {
    if (i < ends.length) {
      final start = _atLeastZero(ends[i] - m - reach);
      if (start <= windowEnd) {
        if (ends[i] > windowEnd) windowEnd = ends[i];
        continue;
      }
    }
    final d = _windowedAlignmentDistance(
      text,
      windowStart,
      windowEnd,
      pattern,
      maxEdits,
    );
    if (d < best) {
      best = d;
      if (best == 0) return 0;
    }
    if (i < ends.length) {
      windowStart = _atLeastZero(ends[i] - m - reach);
      windowEnd = ends[i];
    }
  }
  return best;
}

int _atLeastZero(int v) => v < 0 ? 0 : v;

/// End offsets, exclusive and ascending, of the stretches of [text] that come
/// within [reach] substitutions and gaps of [pattern]. Null when there are
/// none, which is the common answer and costs no allocation.
List<int>? _candidateEnds(String text, String pattern, int reach) {
  final m = pattern.length;
  final full = (1 << m) - 1;
  final highBit = 1 << (m - 1);

  final low = Int64List(256);
  Map<int, int>? high;
  for (int i = 0; i < m; i++) {
    final c = pattern.codeUnitAt(i);
    if (c < 256) {
      low[c] |= 1 << i;
    } else {
      high ??= <int, int>{};
      high[c] = (high[c] ?? 0) | (1 << i);
    }
  }

  int vp = full;
  int vn = 0;
  int score = m;
  List<int>? ends;
  final n = text.length;
  for (int j = 0; j < n; j++) {
    final c = text.codeUnitAt(j);
    final eq = c < 256 ? low[c] : (high == null ? 0 : (high[c] ?? 0));
    int x = eq | vn;
    final d0 = ((((x & vp) + vp) ^ vp) | x) & full;
    final hn = vp & d0;
    final hp = (vn | ~(vp | d0)) & full;
    x = (hp << 1) & full;
    vn = x & d0;
    vp = ((hn << 1) | ~(x | d0)) & full;
    if ((hp & highBit) != 0) {
      score++;
    } else if ((hn & highBit) != 0) {
      score--;
    }
    if (score <= reach) {
      (ends ??= <int>[]).add(j + 1);
    }
  }
  return ends;
}

/// Seed taken from the front of each query piece, or a length below
/// [_minSeedLength] when the pieces are too short for a seed to rule anything
/// out.
int _seedLengthFor(int patternLength, int pieces) {
  final shortestPiece = patternLength ~/ pieces;
  final affordable = _wordBits ~/ pieces;
  return shortestPiece < affordable ? shortestPiece : affordable;
}

/// Shortest seed that still leaves an exact hit rare in prose.
const int _minSeedLength = 6;

/// Approximate substring distance found by seeding.
///
/// A stretch within `maxEdits` edits leaves at least one of `2 * maxEdits + 1`
/// disjoint query pieces untouched, because an edit spoils at most two of them
/// and only a transposition can reach across a boundary at all. The front of
/// that surviving piece therefore appears verbatim, and all the seeds together
/// fit in one machine word, so a single exact-match pass over the text finds
/// every place worth measuring and, on prose, usually finds none.
int _seededDistance(
  String text,
  String pattern,
  int maxEdits,
  int pieces,
  int seedLength,
) {
  final m = pattern.length;
  final n = text.length;

  final low = Int64List(256);
  Map<int, int>? high;
  int startBits = 0;
  int endBits = 0;
  for (int p = 0; p < pieces; p++) {
    final from = (m * p) ~/ pieces;
    final base = p * seedLength;
    startBits |= 1 << base;
    endBits |= 1 << (base + seedLength - 1);
    for (int i = 0; i < seedLength; i++) {
      final c = pattern.codeUnitAt(from + i);
      final bit = 1 << (base + i);
      if (c < 256) {
        low[c] |= bit;
      } else {
        high ??= <int, int>{};
        high[c] = (high[c] ?? 0) | bit;
      }
    }
  }
  final full = (1 << (pieces * seedLength)) - 1;

  final origins = <int>[];
  int state = 0;
  for (int j = 0; j < n; j++) {
    final c = text.codeUnitAt(j);
    final eq = c < 256 ? low[c] : (high == null ? 0 : (high[c] ?? 0));
    state = ((state << 1) | startBits) & eq & full;
    final finished = state & endBits;
    if (finished == 0) continue;
    for (int p = 0; p < pieces; p++) {
      if ((finished & (1 << (p * seedLength + seedLength - 1))) == 0) continue;
      final from = (m * p) ~/ pieces;
      final to = (m * (p + 1)) ~/ pieces;
      final at = j - seedLength + 1;
      // The guarantee is about a whole untouched piece, so the rest of it has
      // to be there too; checking that here is far cheaper than aligning.
      if (at + to - from > n) continue;
      bool whole = true;
      for (int i = seedLength; i < to - from; i++) {
        if (pattern.codeUnitAt(from + i) != text.codeUnitAt(at + i)) {
          whole = false;
          break;
        }
      }
      if (whole) origins.add(at - from);
    }
  }
  if (origins.isEmpty) return maxEdits + 1;
  origins.sort();

  int best = maxEdits + 1;
  int last = origins[0] - 1;
  for (final origin in origins) {
    if (origin == last) continue;
    last = origin;
    final d = _diagonalAlignmentDistance(text, origin, pattern, maxEdits);
    if (d < best) {
      best = d;
      if (best == 0) return 0;
    }
  }
  return best;
}

/// Alignment distance between [pattern] and the stretch of [text] anchored on
/// the diagonal through [origin], searching only the band [maxEdits] wide
/// around it.
///
/// A piece that survived unedited pins the alignment to that diagonal, and a
/// budget of [maxEdits] edits can carry the rest of it only that far off, so
/// everything outside the band is unreachable.
int _diagonalAlignmentDistance(
  String text,
  int origin,
  String pattern,
  int maxEdits,
) {
  final n = text.length;
  final m = pattern.length;
  final cap = maxEdits + 1;
  final width = 2 * maxEdits + 1;
  var twoBack = Int32List(width);
  var previous = Int32List(width);
  var current = Int32List(width);
  for (int o = 0; o < width; o++) {
    final t = origin + o - maxEdits;
    previous[o] = (t < 0 || t > n) ? cap : 0;
    twoBack[o] = cap;
  }

  for (int i = 1; i <= m; i++) {
    final pc = pattern.codeUnitAt(i - 1);
    for (int o = 0; o < width; o++) {
      final t = origin + i + o - maxEdits;
      if (t < 0 || t > n) {
        current[o] = cap;
        continue;
      }
      // Consuming no text at all is a reachable state, not an out-of-range
      // one: it is where an alignment sits after deleting pattern characters
      // ahead of the first text character. Its only in-band predecessor is
      // that deletion, so it is filled here rather than by the loop below,
      // which would read a text character that does not exist. Capping it
      // instead would put every match at the very start of the text - a
      // pasted commit subject, which is what this path is for - out of reach.
      if (t == 0) {
        final up = (o + 1 < width) ? previous[o + 1] + 1 : cap;
        current[o] = up > cap ? cap : up;
        continue;
      }
      final c = text.codeUnitAt(t - 1);
      int v = previous[o] + (pc == c ? 0 : 1);
      if (o + 1 < width) {
        final drop = previous[o + 1] + 1;
        if (drop < v) v = drop;
      }
      if (o > 0) {
        final skip = current[o - 1] + 1;
        if (skip < v) v = skip;
      }
      if (i >= 2 &&
          t >= 2 &&
          pc == text.codeUnitAt(t - 2) &&
          pattern.codeUnitAt(i - 2) == c) {
        final swap = twoBack[o] + 1;
        if (swap < v) v = swap;
      }
      current[o] = v > cap ? cap : v;
    }
    final recycled = twoBack;
    twoBack = previous;
    previous = current;
    current = recycled;
  }

  int best = cap;
  for (int o = 0; o < width; o++) {
    final t = origin + m + o - maxEdits;
    if (t < 0 || t > n) continue;
    if (previous[o] < best) best = previous[o];
  }
  return best;
}

/// Optimal string alignment distance between [pattern] and the closest
/// substring of `text[from, to)`, capped at `maxEdits + 1`.
int _windowedAlignmentDistance(
  String text,
  int from,
  int to,
  String pattern,
  int maxEdits,
) {
  final m = pattern.length;
  final cap = maxEdits + 1;
  var twoBack = Int32List(m + 1);
  var previous = Int32List(m + 1);
  var current = Int32List(m + 1);
  for (int i = 0; i <= m; i++) {
    twoBack[i] = cap;
    current[i] = cap;
    previous[i] = i < cap ? i : cap;
  }
  // Rows past these indices are known to hold the cap, which is what lets the
  // scan below skip them and still read a safe value.
  int twoBackFilled = m;
  int previousFilled = m;
  int currentFilled = m;
  int lastActive = cap < m ? cap : m;

  int best = cap;
  int previousChar = -1;
  for (int j = from; j < to; j++) {
    final c = text.codeUnitAt(j);
    current[0] = 0;
    final transposable = j > from;
    final reached = lastActive;
    for (int i = 1; i <= reached; i++) {
      final pc = pattern.codeUnitAt(i - 1);
      int v = previous[i - 1] + (pc == c ? 0 : 1);
      final insert = previous[i] + 1;
      if (insert < v) v = insert;
      final delete = current[i - 1] + 1;
      if (delete < v) v = delete;
      if (transposable &&
          i >= 2 &&
          pc == previousChar &&
          pattern.codeUnitAt(i - 2) == c) {
        final swap = twoBack[i - 2] + 1;
        if (swap < v) v = swap;
      }
      current[i] = v > cap ? cap : v;
    }
    for (int i = reached + 1; i <= currentFilled; i++) {
      current[i] = cap;
    }
    currentFilled = reached;
    if (current[m] < best) {
      best = current[m];
      if (best == 0) return 0;
    }
    // Values never fall along a diagonal, so once a row is past the budget
    // nothing below it can come back under it in this column.
    while (lastActive > 0 && current[lastActive] >= cap) {
      lastActive--;
    }
    if (lastActive < m) lastActive++;

    final recycled = twoBack;
    twoBack = previous;
    previous = current;
    current = recycled;
    final recycledFilled = twoBackFilled;
    twoBackFilled = previousFilled;
    previousFilled = currentFilled;
    currentFilled = recycledFilled;
    previousChar = c;
  }
  return best;
}

/// Length of the longest common subsequence of [a] and [b].
int _longestCommonSubsequence(String a, String b) {
  final n = a.length;
  final m = b.length;
  if (n == 0 || m == 0) return 0;
  var previous = Int32List(m + 1);
  var current = Int32List(m + 1);
  for (int i = 1; i <= n; i++) {
    final ai = a.codeUnitAt(i - 1);
    for (int j = 1; j <= m; j++) {
      if (ai == b.codeUnitAt(j - 1)) {
        current[j] = previous[j - 1] + 1;
      } else {
        final up = previous[j];
        final left = current[j - 1];
        current[j] = up > left ? up : left;
      }
    }
    final recycled = previous;
    previous = current;
    current = recycled;
  }
  return previous[m];
}
