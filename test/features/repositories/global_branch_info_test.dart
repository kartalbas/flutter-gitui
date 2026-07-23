import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/features/repositories/providers/global_branch_provider.dart';

void main() {
  const branch = GlobalBranchInfo(
    branchName: 'develop',
    repositoryCount: 3,
    totalRepositories: 5,
    repositoryPaths: ['/repo/a', '/repo/b', '/repo/c'],
    repositoryNames: ['Alpha', 'Beta', 'Gamma'],
  );

  group('GlobalBranchInfo.restrictedTo', () {
    test('keeps only the selected repositories with their names aligned', () {
      final restricted = branch.restrictedTo({'/repo/a', '/repo/c'});

      expect(restricted, isNotNull);
      expect(restricted!.repositoryPaths, ['/repo/a', '/repo/c']);
      expect(restricted.repositoryNames, ['Alpha', 'Gamma']);
      expect(restricted.repositoryCount, 2);
    });

    test('reports the selection size as the new total', () {
      final restricted = branch.restrictedTo({'/repo/a', '/repo/b', '/repo/x'});

      expect(restricted, isNotNull);
      expect(restricted!.totalRepositories, 3);
      expect(restricted.repositoryCount, 2);
    });

    test('returns null when no selected repository can switch', () {
      expect(branch.restrictedTo({'/repo/x', '/repo/y'}), isNull);
    });

    test('keeps the branch name unchanged', () {
      expect(branch.restrictedTo({'/repo/b'})!.branchName, 'develop');
    });
  });
}
