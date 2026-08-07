// Pins the two behaviours that justify DestructiveAction.forceRenameBranch
// (#373). A plain rename REFUSES to overwrite an existing branch, so the only
// way to reach `git branch -M` is the explicit `force: true` argument - the
// argument the require_confirm_destructive lint gates behind a
// confirmDestructive guard. And a forced rename leaves the overwritten tip
// reachable through the reflog, which is exactly the definition of the
// reflogRecoverable tier the action is catalogued under. This suite runs
// against a real repository because only git can attest that its refusal and
// its reflog behave this way.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/git/git_service.dart';

Future<void> runGit(String repoPath, List<String> args) async {
  final result = await Process.run('git', args, workingDirectory: repoPath);
  if (result.exitCode != 0) {
    fail('git ${args.join(' ')} failed: ${result.stderr}');
  }
}

Future<String> revParse(String repoPath, String ref) async {
  final result = await Process.run('git', [
    'rev-parse',
    ref,
  ], workingDirectory: repoPath);
  expect(result.exitCode, 0, reason: result.stderr.toString());
  return result.stdout.toString().trim();
}

Future<bool> branchExists(String repoPath, String name) async {
  final result = await Process.run('git', [
    'rev-parse',
    '--verify',
    '--quiet',
    'refs/heads/$name',
  ], workingDirectory: repoPath);
  return result.exitCode == 0;
}

void main() {
  late Directory repoDir;
  late String path;
  late GitService service;
  late String keepHash;
  late String victimHash;

  setUp(() async {
    repoDir = await Directory.systemTemp.createTemp('gitui_rename_force_');
    path = repoDir.path;

    await runGit(path, ['init']);
    await runGit(path, ['config', 'user.email', 'test@example.com']);
    await runGit(path, ['config', 'user.name', 'Test']);
    await runGit(path, ['checkout', '-b', 'keep']);

    File('$path/a.txt').writeAsStringSync('keep\n');
    await runGit(path, ['add', '.']);
    await runGit(path, ['commit', '-m', 'work on keep']);
    keepHash = await revParse(path, 'keep');

    // A second branch with its own commit: the tip a forced rename destroys.
    await runGit(path, ['checkout', '-b', 'victim']);
    File('$path/b.txt').writeAsStringSync('victim\n');
    await runGit(path, ['add', '.']);
    await runGit(path, ['commit', '-m', 'work on victim']);
    victimHash = await revParse(path, 'victim');

    // Renaming away from 'victim' keeps HEAD out of the rename's way.
    await runGit(path, ['checkout', 'keep']);

    service = GitService(path, gitExecutablePath: 'git');
  });

  tearDown(() async {
    try {
      await repoDir.delete(recursive: true);
    } on FileSystemException {
      // Git marks its object files read-only, which Windows refuses to
      // delete; leaking a temp directory beats failing the suite on cleanup.
    }
  });

  test(
    'a rename without force is refused when the target name exists',
    () async {
      final result = await service.renameBranch('victim', oldName: 'keep');

      // git refuses `-m` onto an existing name, so overwriting a branch can
      // only be reached through the explicit, lint-gated force flag.
      expect(result.isFailure, isTrue);
      expect(await revParse(path, 'keep'), keepHash);
      expect(await revParse(path, 'victim'), victimHash);
    },
  );

  test(
    'a forced rename overwrites, and the lost tip stays in the reflog',
    () async {
      final result = await service.renameBranch(
        'victim',
        oldName: 'keep',
        force: true,
      );

      expect(result.isSuccess, isTrue);
      expect(await revParse(path, 'victim'), keepHash);
      expect(await branchExists(path, 'keep'), isFalse);

      // The overwritten tip is no longer reachable from any branch...
      final branchTips = await Process.run('git', [
        'for-each-ref',
        '--format=%(objectname)',
        'refs/heads',
      ], workingDirectory: path);
      expect(branchTips.stdout.toString(), isNot(contains(victimHash)));

      // ...but the HEAD reflog still reaches it, which is what makes the
      // action reflogRecoverable rather than permanent.
      final reflog = await Process.run('git', [
        'log',
        '-g',
        '--format=%H',
        'HEAD',
      ], workingDirectory: path);
      expect(reflog.exitCode, 0, reason: reflog.stderr.toString());
      expect(reflog.stdout.toString(), contains(victimHash));
    },
  );
}
