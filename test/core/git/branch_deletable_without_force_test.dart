// The rule behind the bulk delete's merged/unmerged pills and its promise
// about which branches an unforced deletion keeps.
//
// The dialog is the most destructive prompt in the app and it states, before
// the user presses anything, which selected branches it will keep. That is a
// promise git has to honour, so the rule cannot be an approximation: it is
// git's own (builtin/branch.c, `branch_merged`) - a branch whose configured
// upstream still resolves is compared against *that upstream*, and only a
// branch without one is compared against HEAD.
//
// The expectations below are not derived from the implementation. Each was
// measured against git 2.54.0.windows.1 in a throwaway repository with a real
// remote, by building the branch and then running `git branch -d` on it; the
// `for-each-ref` row each case names is what that repository printed for
// `%(refname:short)~%(upstream)~%(upstream:trackshort)`.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/git/git_service.dart';

bool _deletable({
  required String upstream,
  required String divergence,
  required bool mergedIntoHead,
}) => GitService.branchDeletableWithoutForce(
  upstream: upstream,
  divergence: divergence,
  mergedIntoHead: mergedIntoHead,
);

void main() {
  group('a branch without an upstream is compared against HEAD', () {
    test('merged into HEAD is deletable', () {
      // row: mergedin~~ , and `git branch -d mergedin` -> "Deleted branch".
      expect(
        _deletable(upstream: '', divergence: '', mergedIntoHead: true),
        isTrue,
      );
    });

    test('not merged into HEAD is not deletable', () {
      // row: localonly~~ , and `git branch -d localonly` -> refused.
      expect(
        _deletable(upstream: '', divergence: '', mergedIntoHead: false),
        isFalse,
      );
    });
  });

  group('a branch with an upstream is compared against the upstream', () {
    test('in sync with the upstream is deletable, HEAD notwithstanding', () {
      // row: pushed~refs/remotes/origin/pushed~= while `git branch --merged`
      // printed only master, and `git branch -d pushed` still deleted it:
      // "warning: deleting branch 'pushed' that has been merged to
      // 'refs/remotes/origin/pushed', but not yet merged to HEAD".
      //
      // This is the case that made the dialog lie: it showed the red
      // `unmerged` pill, said the branch would be kept, and git deleted it.
      expect(
        _deletable(
          upstream: 'refs/remotes/origin/pushed',
          divergence: '=',
          mergedIntoHead: false,
        ),
        isTrue,
      );
    });

    test('behind the upstream is deletable', () {
      expect(
        _deletable(
          upstream: 'refs/remotes/origin/behind',
          divergence: '<',
          mergedIntoHead: false,
        ),
        isTrue,
      );
    });

    test('ahead of the upstream is refused even when merged into HEAD', () {
      // row: mha~refs/remotes/origin/mha~> while `git branch --merged` did
      // list mha, and `git branch -d mha` refused it. The other direction of
      // the same defect: the dialog would have shown the green `merged` pill
      // for a branch git will not delete.
      expect(
        _deletable(
          upstream: 'refs/remotes/origin/mha',
          divergence: '>',
          mergedIntoHead: true,
        ),
        isFalse,
      );
    });

    test('diverged from the upstream is not deletable', () {
      expect(
        _deletable(
          upstream: 'refs/remotes/origin/diverged',
          divergence: '<>',
          mergedIntoHead: false,
        ),
        isFalse,
      );
    });
  });

  test('a gone upstream falls back to HEAD, as git does', () {
    // row: goneb~refs/remotes/origin/goneb~ - the upstream is still
    // configured but the remote-tracking ref is gone, so trackshort is empty.
    // Git cannot resolve it either and compares against HEAD instead, which
    // is why `git branch -d goneb` refused the branch below.
    expect(
      _deletable(
        upstream: 'refs/remotes/origin/goneb',
        divergence: '',
        mergedIntoHead: false,
      ),
      isFalse,
    );
    expect(
      _deletable(
        upstream: 'refs/remotes/origin/goneb',
        divergence: '',
        mergedIntoHead: true,
      ),
      isTrue,
    );
  });
}
