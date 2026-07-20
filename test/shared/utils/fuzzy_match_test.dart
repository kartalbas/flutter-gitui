import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gitui/shared/utils/fuzzy_match.dart';

/// A commit subject from this repository's own history, long enough to exceed
/// the width of one bit-parallel word.
const longSubject =
    'fix(repositories): guard provider access across async gaps in repositories';

/// The same subject trimmed to the length it was actually committed at, kept
/// separate because the left-edge cases below pin scores that depend on it
/// being exactly 67 characters.
const subject67 =
    'fix(repositories): guard provider access across async gaps in repos';

const unrelatedMessage =
    'ci: pin Linux runners to ubuntu-22.04 and gate the glibc floor, then '
    'stamp the commit and build date into the release archives so a download '
    'can be traced back to the revision it was produced from';

void main() {
  group('edit budget', () {
    test('short queries get no budget at all', () {
      for (var m = 0; m < 6; m++) {
        expect(fuzzyEditBudget(m), 0, reason: 'length $m');
      }
    });

    test('budget steps with absolute length and stops growing', () {
      expect(fuzzyEditBudget(6), 1);
      expect(fuzzyEditBudget(11), 1);
      expect(fuzzyEditBudget(12), 2);
      expect(fuzzyEditBudget(23), 2);
      expect(fuzzyEditBudget(24), 3);
      expect(fuzzyEditBudget(200), 3);
    });
  });

  group('queries wider than one machine word', () {
    test('the fixture really is longer than the word the scan uses', () {
      expect(longSubject.length, greaterThan(63));
      expect(subject67.length, 67);
    });

    test('an exact hit scores 100', () {
      final message = 'chore: prepare release\n\n$longSubject\n\nRefs #260';
      expect(partialMatchScore(message, longSubject), 100);
    });

    test('a single typo is still found and scored just under 100', () {
      final typo = longSubject.replaceFirst('guard', 'guerd');
      final message = 'chore: prepare release\n\n$longSubject\n\nRefs #260';
      final score = partialMatchScore(message, typo);
      expect(score, greaterThan(90));
      expect(score, lessThan(100));
    });

    test('an unrelated message scores zero, not something near 75', () {
      expect(partialMatchScore(unrelatedMessage, longSubject), 0);
      expect(partialMatchScore(unrelatedMessage, longSubject, minScore: 60), 0);
      expect(partialMatchScore(unrelatedMessage, longSubject, minScore: 1), 0);
    });

    test('minScore is honoured on the long path too', () {
      final message = 'chore: prepare release\n\n$longSubject\n\nRefs #260';
      expect(partialMatchScore(message, longSubject, minScore: 100), 100);
      expect(partialMatchScore(message, longSubject, minScore: 101), 0);
      final typo = longSubject.replaceFirst('guard', 'guerd');
      expect(partialMatchScore(message, typo, minScore: 100), 0);
    });

    test('every unrelated message in a batch stays at zero', () {
      final corpus = <String>[
        for (var i = 0; i < 200; i++) 'commit $i: $unrelatedMessage',
      ];
      final admitted = corpus
          .where((m) => partialMatchScore(m, longSubject, minScore: 60) > 0)
          .length;
      expect(admitted, 0);
    });
  });

  // A commit message begins with its subject, so a subject pasted into the
  // history search matches at text offset zero. That alignment hangs off the
  // left edge of the text, and an earlier revision made every such alignment
  // unreachable, which cost the match outright. These pin the exact scores.
  group('a match at the very start of the text', () {
    // The subject stands where it really stands in a commit message: first.
    const message =
        '$subject67\n\nThe provider was read after an await, so a disposed '
        'container could be touched.\n\nFixes #260';

    test('the fixture puts the subject at offset zero', () {
      expect(message.indexOf(subject67), 0);
    });

    test('one leading insertion still scores 99', () {
      expect(partialMatchScore(message, 'q$subject67'), 99);
    });

    test('two leading insertions still score 97', () {
      expect(partialMatchScore(message, 'qq$subject67'), 97);
    });

    test('three leading insertions still score 96, not zero', () {
      expect(partialMatchScore(message, 'xyz$subject67'), 96);
      expect(
        approximateSubstringDistance(message, 'xyz$subject67', 3),
        3,
        reason: 'the budget is exactly 3, so an off-by-one loses the match',
      );
    });

    test('the whole subject alone scores 100 at offset zero', () {
      expect(partialMatchScore(message, subject67), 100);
    });

    test('the minimised repro of the left-edge defect', () {
      expect(
        approximateSubstringDistance(
          'bbbcdefebgbagccfcaedgcebdcgc',
          'abbbcdefebagbagccfcaedgcebdcgc',
          2,
        ),
        2,
      );
    });

    test('a leading insertion is found for every alphabet and budget', () {
      final rnd = Random(3260);
      for (final m in [42, 63, 64, 80, 130]) {
        for (var t = 0; t < 20; t++) {
          final core = _randomString(rnd, 'abcdefgh ', m);
          final text = '$core${_randomString(rnd, 'abcdefgh ', 40)}';
          for (var ins = 1; ins <= 3; ins++) {
            final query = '${'z' * ins}$core';
            expect(
              approximateSubstringDistance(text, query, 3),
              _unbandedSellersDistance(text, query),
              reason: 'length $m, $ins leading insertions',
            );
          }
        }
      }
    });

    // With leading insertions the surviving query piece is not the first one,
    // so the diagonal it pins sits to the left of the text's own start.
    test('an anchor diagonal with a negative origin is still measured', () {
      const core =
          'guard provider access across async gaps in the repository layer';
      final text = '$core and keep the notifier alive until the frame ends';
      final query = 'zzz$core';
      expect(text.indexOf(core), 0);
      expect(query.length, greaterThan(63));
      expect(
        approximateSubstringDistance(text, query, 3),
        _unbandedSellersDistance(text, query),
      );
      expect(partialMatchScore(text, query), greaterThan(90));
    });
  });

  group('short queries are plain substring matches', () {
    test('"reset" does not match a message about the rest of a list', () {
      const message =
          'fix(status): keep the rest of the file list visible while a '
          'refresh is in flight';
      expect(message.toLowerCase().contains('reset'), isFalse);
      expect(partialMatchScore(message.toLowerCase(), 'reset'), 0);
    });

    test('"clone" does not match a message about closing a dialog', () {
      const message =
          'fix(dialogs): close the branch switcher when the checkout fails';
      expect(partialMatchScore(message.toLowerCase(), 'clone'), 0);
    });

    test('"stash" does not match a message about a slash in a path', () {
      const message =
          'fix(paths): normalise a trailing slash before comparing worktrees';
      expect(partialMatchScore(message.toLowerCase(), 'stash'), 0);
    });

    test('the same short queries still match when really present', () {
      expect(
        partialMatchScore('fix(reset): keep the index intact', 'reset'),
        100,
      );
      expect(partialMatchScore('feat(clone): accept an ssh url', 'clone'), 100);
      expect(
        partialMatchScore('feat(stash): apply the newest entry', 'stash'),
        100,
      );
    });
  });

  group('recall', () {
    const subject = 'fix(rebase): keep the interactive todo list in sync';
    const other = 'refactor(history): extract the search service from the view';

    test('exact substring', () {
      expect(partialMatchScore(subject, 'rebase'), 100);
    });

    test('one-character typo on a six-character query', () {
      expect(partialMatchScore(subject, 'rebaze'), 83);
    });

    test('transposition', () {
      expect(partialMatchScore(subject, 'reabse'), 83);
    });

    test('a prefix of a word in the message', () {
      expect(partialMatchScore(other, 'refact'), 100);
    });

    test('two words that are adjacent in the message', () {
      expect(partialMatchScore(other, 'search service'), 100);
    });

    test('an exact hit outranks a typo and a transposition', () {
      final exact = partialMatchScore(subject, 'rebase');
      final typo = partialMatchScore(subject, 'rebaze');
      final swapped = partialMatchScore(subject, 'reabse');
      expect(exact, greaterThan(typo));
      expect(exact, greaterThan(swapped));
      expect(typo, greaterThan(0));
      expect(swapped, greaterThan(0));
    });

    test('a typo in a query below the budget minimum does not match', () {
      expect(partialMatchScore(other, 'histo'), 100);
      expect(partialMatchScore(other, 'hista'), 0);
    });
  });

  group('degenerate input', () {
    test('empty query and empty text score zero rather than throwing', () {
      expect(partialMatchScore('', ''), 0);
      expect(partialMatchScore('anything at all', ''), 0);
      expect(partialMatchScore('', 'anything at all'), 0);
      expect(similarityRatio('', ''), 0);
    });

    test('a query longer than the whole text is handled', () {
      expect(partialMatchScore('short', longSubject), 0);
      expect(
        approximateSubstringDistance('short', longSubject, 3),
        4,
        reason: 'nothing that close, so the cap comes back',
      );
    });
  });

  group('palette scale', () {
    // Pinned against the English strings the palette actually feeds in, so a
    // change of formula fails here rather than quietly reshaping the results.
    test('scores are pinned', () {
      expect(similarityRatio('rebase', 'rebase branch'), 63);
      expect(
        similarityRatio('rebase', 'rebase current branch onto another'),
        30,
      );
      expect(similarityRatio('rebase', 'merge branch'), 44);
      expect(similarityRatio('rebase', 'branches'), 43);
      expect(similarityRatio('rebas', 'rebase branch'), 56);
      expect(similarityRatio('clone', 'clone repository'), 48);
      expect(similarityRatio('clone', 'clone a repository from a url'), 29);
      expect(similarityRatio('stash', 'stash changes'), 56);
      expect(similarityRatio('stash', 'stashes'), 83);
      expect(similarityRatio('cherry', 'cherry-pick commit'), 50);
      expect(similarityRatio('xyzzy', 'rebase branch'), 0);
      expect(similarityRatio('xyzzy', 'clone repository'), 10);
      expect(similarityRatio('', ''), 0);
      expect(similarityRatio('rebase', ''), 0);
    });

    test(
      'the palette gate keeps admitting and rejecting the same commands',
      () {
        int best(String q, List<String> fields) => fields
            .map((f) => similarityRatio(q, f))
            .reduce((a, b) => a > b ? a : b);
        expect(
          best('rebase', [
            'rebase branch',
            'rebase current branch onto another',
            'branches',
          ]),
          greaterThan(40),
        );
        expect(
          best('xyzzy', [
            'rebase branch',
            'rebase current branch onto another',
            'branches',
          ]),
          lessThan(41),
        );
      },
    );
  });

  group('against independent references', () {
    test('brute force over every substring agrees, at every budget', () {
      final rnd = Random(2604);
      var cases = 0;
      for (final alphabet in ['ab', 'abcd', 'abcdefgh ']) {
        for (var t = 0; t < 400; t++) {
          final text = _randomString(rnd, alphabet, 1 + rnd.nextInt(18));
          final pattern = _randomString(rnd, alphabet, 1 + rnd.nextInt(9));
          final truth = _bruteForceSubstringDistance(text, pattern);
          for (var k = 0; k <= 4; k++) {
            final expected = truth > k ? k + 1 : truth;
            expect(
              approximateSubstringDistance(text, pattern, k),
              expected,
              reason: 'text "$text" pattern "$pattern" budget $k',
            );
            cases++;
          }
        }
      }
      expect(cases, greaterThan(5000));
    });

    test('an unbanded matrix agrees on long patterns', () {
      final rnd = Random(1215);
      for (final m in [40, 62, 63, 64, 65, 90, 130, 200]) {
        for (var t = 0; t < 25; t++) {
          final pattern = _randomString(rnd, 'abcde', m);
          final lead = _randomString(rnd, 'abcde', 40);
          final tail = _randomString(rnd, 'abcde', 40);
          final text = t.isEven
              ? '$lead${_damage(rnd, pattern, rnd.nextInt(5))}$tail'
              : _randomString(rnd, 'abcde', 150 + rnd.nextInt(150));
          final truth = _unbandedSellersDistance(text, pattern);
          for (var k = 0; k <= 4; k++) {
            expect(
              approximateSubstringDistance(text, pattern, k),
              truth > k ? k + 1 : truth,
              reason: 'pattern length $m budget $k',
            );
          }
        }
      }
    });

    // The lead in the fixture above is a fixed forty characters, so no case
    // there ever puts the match at offset zero. Here the offset is drawn from
    // a range that starts at zero, which is where the left-edge cells live.
    test('an unbanded matrix agrees when the match starts at offset zero', () {
      final rnd = Random(9260);
      var cases = 0;
      var atOffsetZero = 0;
      for (final alphabet in ['ab', 'abcde', 'abcdefgh ']) {
        for (var t = 0; t < 90; t++) {
          final m = 42 + rnd.nextInt(120);
          final pattern = _randomString(rnd, alphabet, m);
          final offset = rnd.nextInt(4);
          final lead = _randomString(rnd, alphabet, offset);
          final tail = _randomString(rnd, alphabet, rnd.nextInt(50));
          final text = '$lead${_damage(rnd, pattern, rnd.nextInt(4))}$tail';
          final truth = _unbandedSellersDistance(text, pattern);
          for (var k = 0; k <= 3; k++) {
            expect(
              approximateSubstringDistance(text, pattern, k),
              truth > k ? k + 1 : truth,
              reason: 'length $m offset $offset budget $k',
            );
            cases++;
            if (offset == 0) atOffsetZero++;
          }
        }
      }
      expect(cases, greaterThan(1000));
      expect(
        atOffsetZero,
        greaterThan(200),
        reason: 'the offset-zero cells must actually be exercised',
      );
    });

    test('leading insertions agree with an unbanded matrix', () {
      final rnd = Random(4260);
      var cases = 0;
      for (final alphabet in ['ab', 'abcde', 'abcdefgh ']) {
        for (var t = 0; t < 60; t++) {
          final m = 42 + rnd.nextInt(120);
          final core = _randomString(rnd, alphabet, m);
          final text = '$core${_randomString(rnd, alphabet, rnd.nextInt(60))}';
          for (var ins = 1; ins <= 3; ins++) {
            final query = '${_randomString(rnd, alphabet, ins)}$core';
            final truth = _unbandedSellersDistance(text, query);
            for (var k = 0; k <= 3; k++) {
              expect(
                approximateSubstringDistance(text, query, k),
                truth > k ? k + 1 : truth,
                reason: 'length $m insertions $ins budget $k',
              );
              cases++;
            }
          }
        }
      }
      expect(cases, greaterThan(1500));
    });

    test('the similarity scale agrees with a recursive definition', () {
      final rnd = Random(77);
      for (var t = 0; t < 2000; t++) {
        final a = _randomString(rnd, 'abcdef ', rnd.nextInt(14));
        final b = _randomString(rnd, 'abcdef ', rnd.nextInt(16));
        expect(similarityRatio(a, b), _referenceRatio(a, b));
      }
    });
  });
}

String _randomString(Random rnd, String alphabet, int length) {
  final buffer = StringBuffer();
  for (var i = 0; i < length; i++) {
    buffer.write(alphabet[rnd.nextInt(alphabet.length)]);
  }
  return buffer.toString();
}

String _damage(Random rnd, String s, int edits) {
  var out = s;
  for (var i = 0; i < edits && out.length > 2; i++) {
    final at = rnd.nextInt(out.length - 1);
    final head = out.substring(0, at);
    switch (rnd.nextInt(4)) {
      case 0:
        out = '${head}z${out.substring(at + 1)}';
        break;
      case 1:
        out = '$head${out.substring(at + 1)}';
        break;
      case 2:
        out = '${head}z${out.substring(at)}';
        break;
      default:
        out = '$head${out[at + 1]}${out[at]}${out.substring(at + 2)}';
        break;
    }
  }
  return out;
}

// The references below are written from the textbook definitions, in the most
// literal shape, so that nothing about the optimised implementation can be
// baked into what they expect.

int _alignmentDistance(String a, String b) {
  final n = a.length;
  final m = b.length;
  final d = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = 0; i <= n; i++) {
    d[i][0] = i;
  }
  for (var j = 0; j <= m; j++) {
    d[0][j] = j;
  }
  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      var v = d[i - 1][j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1);
      if (d[i - 1][j] + 1 < v) v = d[i - 1][j] + 1;
      if (d[i][j - 1] + 1 < v) v = d[i][j - 1] + 1;
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        if (d[i - 2][j - 2] + 1 < v) v = d[i - 2][j - 2] + 1;
      }
      d[i][j] = v;
    }
  }
  return d[n][m];
}

int _bruteForceSubstringDistance(String text, String pattern) {
  var best = pattern.length;
  for (var i = 0; i <= text.length; i++) {
    for (var j = i; j <= text.length; j++) {
      final d = _alignmentDistance(pattern, text.substring(i, j));
      if (d < best) best = d;
    }
  }
  return best;
}

int _unbandedSellersDistance(String text, String pattern) {
  final n = text.length;
  final m = pattern.length;
  final d = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
  for (var i = 0; i <= m; i++) {
    d[i][0] = i;
  }
  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      var v = d[i - 1][j - 1] + (pattern[i - 1] == text[j - 1] ? 0 : 1);
      if (d[i - 1][j] + 1 < v) v = d[i - 1][j] + 1;
      if (d[i][j - 1] + 1 < v) v = d[i][j - 1] + 1;
      if (i > 1 &&
          j > 1 &&
          pattern[i - 1] == text[j - 2] &&
          pattern[i - 2] == text[j - 1]) {
        if (d[i - 2][j - 2] + 1 < v) v = d[i - 2][j - 2] + 1;
      }
      d[i][j] = v;
    }
  }
  var best = m;
  for (var j = 0; j <= n; j++) {
    if (d[m][j] < best) best = d[m][j];
  }
  return best;
}

int _referenceRatio(String a, String b) {
  final total = a.length + b.length;
  if (total == 0) return 0;
  final memo = <int, int>{};
  int lcs(int i, int j) {
    if (i == a.length || j == b.length) return 0;
    final key = i * (b.length + 1) + j;
    final cached = memo[key];
    if (cached != null) return cached;
    int v;
    if (a[i] == b[j]) {
      v = 1 + lcs(i + 1, j + 1);
    } else {
      final x = lcs(i + 1, j);
      final y = lcs(i, j + 1);
      v = x > y ? x : y;
    }
    memo[key] = v;
    return v;
  }

  return (200 * lcs(0, 0) / total).round();
}
