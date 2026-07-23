// Pins the measured shape of `git show` on merge commits. Under git's default
// dense combined format a clean merge prints NO --name-status lines while
// --numstat does print first-parent numbers, and getCommitChangedFiles drives
// its join off the status lines - which is exactly why merges listed no files.
// Both queries are therefore pinned to the first parent, and this suite runs
// against a real repository because no scripted fake can attest what git
// actually emits.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/git/git_service.dart';
import 'package:flutter_gitui/core/git/models/file_change.dart';

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

void main() {
  late Directory repoDir;
  late GitService service;
  late String mergeHash;
  late String trunkWorkHash;

  setUpAll(() async {
    repoDir = await Directory.systemTemp.createTemp('gitui_merge_files_');
    final path = repoDir.path;

    await runGit(path, ['init']);
    await runGit(path, ['config', 'user.email', 'test@example.com']);
    await runGit(path, ['config', 'user.name', 'Test']);
    // Deterministic line counts on every platform.
    await runGit(path, ['config', 'core.autocrlf', 'false']);
    await runGit(path, ['checkout', '-b', 'trunk']);

    File('$path/shared.txt').writeAsStringSync('base\n');
    File('$path/trunk.txt').writeAsStringSync('base\n');
    await runGit(path, ['add', '.']);
    await runGit(path, ['commit', '-m', 'base']);

    await runGit(path, ['checkout', '-b', 'topic']);
    File('$path/shared.txt').writeAsStringSync('topic\n');
    File('$path/added.txt').writeAsStringSync('new\n');
    await runGit(path, ['add', '.']);
    await runGit(path, ['commit', '-m', 'topic work']);

    // Disjoint files on trunk keep the merge clean - the dense combined
    // format is empty precisely for clean merges, which is the reported case.
    await runGit(path, ['checkout', 'trunk']);
    File('$path/trunk.txt').writeAsStringSync('trunk\n');
    await runGit(path, ['add', '.']);
    await runGit(path, ['commit', '-m', 'trunk work']);
    trunkWorkHash = await revParse(path, 'HEAD');

    await runGit(path, ['merge', '--no-ff', '--no-edit', 'topic']);
    mergeHash = await revParse(path, 'HEAD');

    service = GitService(path, gitExecutablePath: 'git');
  });

  tearDownAll(() async {
    try {
      await repoDir.delete(recursive: true);
    } on FileSystemException {
      // Git marks its object files read-only, which Windows refuses to
      // delete; leaking a temp directory beats failing the suite on cleanup.
    }
  });

  test('a merge commit lists the files it brought to its branch', () async {
    final files = await service.getCommitChangedFiles(mergeHash);

    final byPath = {for (final file in files) file.path: file};
    expect(byPath.keys, containsAll(['shared.txt', 'added.txt']));

    // First parent only: trunk.txt is the first parent's own work, so a
    // merge that merely contains it must not claim to have changed it.
    expect(byPath.containsKey('trunk.txt'), isFalse);

    expect(byPath['shared.txt']!.type, FileChangeType.modified);
    expect(byPath['added.txt']!.type, FileChangeType.added);

    // The counts come from --numstat; zeros here would mean the two queries
    // disagreed about the parent they diffed against.
    expect(byPath['shared.txt']!.additions, 1);
    expect(byPath['shared.txt']!.deletions, 1);
    expect(byPath['added.txt']!.additions, 1);
  });

  test('a merge commit has a per-file diff for the viewer', () async {
    final diff = (await service.getDiffForCommit(
      mergeHash,
      'shared.txt',
    )).unwrap();

    expect(diff, contains('-base'));
    expect(diff, contains('+topic'));
  });

  test('a regular commit is unaffected by the first-parent pinning', () async {
    final files = await service.getCommitChangedFiles(trunkWorkHash);

    expect([for (final file in files) file.path], ['trunk.txt']);
    expect(files.single.type, FileChangeType.modified);
    expect(files.single.additions, 1);
    expect(files.single.deletions, 1);
  });
}
