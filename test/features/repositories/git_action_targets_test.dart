import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/features/repositories/git_action_targets.dart';

void main() {
  group('GitActionTargets.effectivePaths', () {
    test('uses the selection even when a current repository is set', () {
      const targets = GitActionTargets(
        selectedPaths: {'/repo/a', '/repo/b'},
        currentRepositoryPath: '/repo/current',
      );

      expect(targets.effectivePaths, unorderedEquals(['/repo/a', '/repo/b']));
    });

    test('falls back to the current repository without a selection', () {
      const targets = GitActionTargets(
        selectedPaths: {},
        currentRepositoryPath: '/repo/current',
      );

      expect(targets.effectivePaths, ['/repo/current']);
    });

    test('is empty with neither selection nor current repository', () {
      const targets = GitActionTargets(
        selectedPaths: {},
        currentRepositoryPath: null,
      );

      expect(targets.effectivePaths, isEmpty);
    });

    test('a single-repository selection stays a one-element set', () {
      const targets = GitActionTargets(
        selectedPaths: {'/repo/a'},
        currentRepositoryPath: '/repo/current',
      );

      expect(targets.effectivePaths, ['/repo/a']);
    });
  });

  group('GitActionTargets.batchActionBlock', () {
    test('allows any non-empty selection', () {
      const targets = GitActionTargets(
        selectedPaths: {'/repo/a', '/repo/b', '/repo/c'},
        currentRepositoryPath: null,
      );

      expect(targets.batchActionBlock, isNull);
    });

    test('allows the current repository without a selection', () {
      const targets = GitActionTargets(
        selectedPaths: {},
        currentRepositoryPath: '/repo/current',
      );

      expect(targets.batchActionBlock, isNull);
    });

    test('blocks with neither selection nor current repository', () {
      const targets = GitActionTargets(
        selectedPaths: {},
        currentRepositoryPath: null,
      );

      expect(targets.batchActionBlock, GitActionBlock.noRepository);
    });
  });

  group('GitActionTargets.createPrBlock', () {
    test('allows a single selected repository', () {
      const targets = GitActionTargets(
        selectedPaths: {'/repo/a'},
        currentRepositoryPath: null,
      );

      expect(targets.createPrBlock, isNull);
    });

    test('allows the current repository without a selection', () {
      const targets = GitActionTargets(
        selectedPaths: {},
        currentRepositoryPath: '/repo/current',
      );

      expect(targets.createPrBlock, isNull);
    });

    test('blocks a multi-repository selection', () {
      const targets = GitActionTargets(
        selectedPaths: {'/repo/a', '/repo/b'},
        currentRepositoryPath: '/repo/current',
      );

      expect(targets.createPrBlock, GitActionBlock.unsupportedSelection);
    });

    test('blocks with neither selection nor current repository', () {
      const targets = GitActionTargets(
        selectedPaths: {},
        currentRepositoryPath: null,
      );

      expect(targets.createPrBlock, GitActionBlock.noRepository);
    });
  });

  group('GitActionTargets.mergeBlock', () {
    test('allows the current repository without a selection', () {
      const targets = GitActionTargets(
        selectedPaths: {},
        currentRepositoryPath: '/repo/current',
      );

      expect(targets.mergeBlock, isNull);
    });

    test('allows a selection of exactly the current repository', () {
      const targets = GitActionTargets(
        selectedPaths: {'/repo/current'},
        currentRepositoryPath: '/repo/current',
      );

      expect(targets.mergeBlock, isNull);
    });

    test('blocks a selection of a different repository', () {
      const targets = GitActionTargets(
        selectedPaths: {'/repo/other'},
        currentRepositoryPath: '/repo/current',
      );

      expect(targets.mergeBlock, GitActionBlock.unsupportedSelection);
    });

    test(
      'blocks a multi-repository selection even including the current one',
      () {
        const targets = GitActionTargets(
          selectedPaths: {'/repo/current', '/repo/other'},
          currentRepositoryPath: '/repo/current',
        );

        expect(targets.mergeBlock, GitActionBlock.unsupportedSelection);
      },
    );

    test('blocks without a current repository even when one is selected', () {
      const targets = GitActionTargets(
        selectedPaths: {'/repo/a'},
        currentRepositoryPath: null,
      );

      expect(targets.mergeBlock, GitActionBlock.noRepository);
    });
  });
}
