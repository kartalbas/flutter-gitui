// Git prints raw file bytes whenever it emits content, so a repository holding
// a legacy-encoded file (Windows-1252 from Word or Excel, Latin-1 from an older
// editor) makes git emit bytes that are not valid UTF-8. Decoding that output
// strictly throws FormatException and, because it is raised inside the process
// output stream rather than the awaited call, it escapes as an unhandled error
// and surfaces as a "Platform Error" popup with no diff shown.
//
// These run against a real repository because no scripted fake can attest what
// git actually writes to stdout.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/git/git_service.dart';

/// Windows-1252 bytes for `Grüße “quoted”` — 0xFC/0xDF are Latin-1 letters and
/// 0x93/0x94 are the smart quotes Word writes. None are valid UTF-8; the lone
/// continuation bytes are exactly what "Unexpected extension byte" reports.
final _legacyBytes = <int>[
  0x47, 0x72, 0xFC, 0xDF, 0x65, // Grüße
  0x20, 0x93, 0x71, 0x75, 0x6F, 0x74, 0x65, 0x64, 0x94, // “quoted”
  0x0A,
];

Future<void> runGit(String repoPath, List<String> args) async {
  final result = await Process.run('git', args, workingDirectory: repoPath);
  if (result.exitCode != 0) {
    fail('git ${args.join(' ')} failed: ${result.stderr}');
  }
}

void main() {
  late Directory repoDir;
  late GitService service;
  late String commitHash;

  setUpAll(() async {
    repoDir = await Directory.systemTemp.createTemp('gitui_encoding_');
    final path = repoDir.path;

    await runGit(path, ['init']);
    await runGit(path, ['config', 'user.email', 'test@example.com']);
    await runGit(path, ['config', 'user.name', 'Test']);
    await runGit(path, ['config', 'core.autocrlf', 'false']);

    // A committed baseline so the later change produces a real diff hunk.
    File('$path/legacy.txt').writeAsStringSync('base\n');
    await runGit(path, ['add', '.']);
    await runGit(path, ['commit', '-m', 'base']);

    // The legacy-encoded content: this is what git will echo verbatim.
    File('$path/legacy.txt').writeAsBytesSync(_legacyBytes);
    await runGit(path, ['add', '.']);
    await runGit(path, ['commit', '-m', 'legacy encoded content']);

    final rev = await Process.run('git', [
      'rev-parse',
      'HEAD',
    ], workingDirectory: path);
    commitHash = rev.stdout.toString().trim();

    service = GitService(path, gitExecutablePath: 'git');
  });

  tearDownAll(() async {
    try {
      await repoDir.delete(recursive: true);
    } on FileSystemException {
      // A leftover temp directory must not fail the suite.
    }
  });

  group('git output that is not valid UTF-8', () {
    test('a commit diff decodes instead of throwing', () async {
      // The path a click on a file in the history tree takes.
      final result = await service.getDiffForCommit(commitHash, 'legacy.txt');

      final diff = result.when(
        success: (value) => value,
        failure: (message, error, stackTrace) =>
            fail('getDiffForCommit failed: $message'),
      );

      // The undecodable bytes must come back as the replacement character
      // rather than taking the whole view down.
      expect(diff, contains('�'));
      // The surrounding ASCII still has to be intact.
      expect(diff, contains('quoted'));
    });

    test('the working-tree file content decodes instead of vanishing', () async {
      // readAsString decoded strictly and the throw was swallowed, so the file
      // looked empty. It must come back with its readable text intact.
      final content = await service.getFileContent('legacy.txt');

      expect(content, isNotNull);
      expect(content, contains('quoted'));
      expect(content, contains('�'));
    });

    test('a working-tree diff decodes instead of throwing', () async {
      File(
        '${repoDir.path}/legacy.txt',
      ).writeAsBytesSync([..._legacyBytes, ..._legacyBytes]);

      final result = await service.getDiff('legacy.txt');

      final diff = result.when(
        success: (value) => value,
        failure: (message, error, stackTrace) =>
            fail('getDiff failed: $message'),
      );

      expect(diff, contains('�'));
    });
  });
}
