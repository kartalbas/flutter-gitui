// A background job must never make a credential helper open a login window.
// The environment blocks git's own terminal prompt and SSH, but Git Credential
// Manager is a separate program with its own GUI that those never reach, so the
// background sweep pops a Microsoft sign-in dialog over the user's work unless
// the command itself forbids going interactive. The flag lands on the command
// line, so it is observable through the command log.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/git/git_service.dart';
import 'package:flutter_gitui/core/git/models/git_command_log.dart';

void main() {
  late Directory repoDir;

  setUpAll(() async {
    repoDir = await Directory.systemTemp.createTemp('gitui_credentials_');
    final result = await Process.run('git', [
      'init',
    ], workingDirectory: repoDir.path);
    expect(result.exitCode, 0, reason: result.stderr.toString());
  });

  tearDownAll(() async {
    try {
      await repoDir.delete(recursive: true);
    } on FileSystemException {
      // A leftover temp directory must not fail the suite.
    }
  });

  Future<String> runAndCaptureCommand({
    required bool allowCredentialPrompts,
  }) async {
    final logs = <GitCommandLog>[];
    final service = GitService(
      repoDir.path,
      gitExecutablePath: 'git',
      onCommandExecuted: logs.add,
      allowCredentialPrompts: allowCredentialPrompts,
    );
    await service.getCurrentBranch();
    expect(logs, isNotEmpty, reason: 'the command should have been logged');
    return logs.first.command;
  }

  group('credential prompts', () {
    test(
      'background commands forbid the helper from going interactive',
      () async {
        final command = await runAndCaptureCommand(
          allowCredentialPrompts: false,
        );
        expect(command, contains('-c credential.interactive=false'));
        // Config options are only honoured before the subcommand.
        expect(
          command.indexOf('-c credential.interactive=false'),
          lessThan(command.indexOf('branch')),
        );
      },
    );

    test('user-started commands keep their prompts', () async {
      // Clicking Pull and being asked to sign in is expected; only unrequested
      // work has to stay silent.
      final command = await runAndCaptureCommand(allowCredentialPrompts: true);
      expect(command, isNot(contains('credential.interactive')));
    });
  });
}
