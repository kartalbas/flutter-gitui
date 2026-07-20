// A launch that cannot succeed has to reach the caller instead of being
// discarded, which is what made the log and config buttons look inert.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/services/editor_launcher_service.dart';
import 'package:flutter_gitui/core/utils/result.dart';

/// A path with a directory part that cannot exist on any supported platform.
///
/// The directory part matters: [EditorLauncherService.launch] hands a bare
/// command name to the OS PATH search instead of checking the file system.
String missingEditorPath() => [
  Directory.systemTemp.path,
  'flutter_gitui_absent_editor_dir',
  'flutter_gitui_absent_editor',
].join(Platform.pathSeparator);

void main() {
  group('EditorLauncherService.launch', () {
    test(
      'reports a missing editor as a failure instead of succeeding',
      () async {
        final result = await EditorLauncherService.launch(
          editorPath: missingEditorPath(),
          targetPath: Directory.systemTemp.path,
        );

        expect(result.isFailure, isTrue);
        expect(result.errorOrNull, contains('flutter_gitui_absent_editor'));
      },
    );

    test(
      'unwrapping that failure throws, so a caller catch can fire',
      () async {
        final result = await EditorLauncherService.launch(
          editorPath: missingEditorPath(),
          targetPath: Directory.systemTemp.path,
        );

        // The three settings buttons awaited launch() without unwrapping, which
        // left the enclosing try/catch unreachable and swallowed the click.
        var reachedCatch = false;
        try {
          result.unwrap();
        } catch (e) {
          reachedCatch = true;
        }

        expect(reachedCatch, isTrue);
      },
    );

    test('a multi-line path is never treated as launchable', () async {
      final result = await EditorLauncherService.launch(
        editorPath: '${missingEditorPath()}\r\n${missingEditorPath()}',
        targetPath: Directory.systemTemp.path,
      );

      expect(result, isA<Failure<void>>());
    });
  });
}
