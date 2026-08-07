// Saving settings has to survive a scanner briefly holding the temporary file
// (#407). On Windows a file that has just been written is opened for scanning
// without FILE_SHARE_DELETE, and a rename during that window fails with
// "access is denied" -- which is exactly what was seen in the field, with the
// user's newest settings left stranded in config.yaml.tmp while the app kept
// reading the older config.yaml.
//
// Every test here works in a temporary directory and drives the two helpers
// through their @visibleForTesting entry points, so nothing ever touches the
// real ~/.flutter-gitui.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/config/config_service.dart';

/// A rename that refuses [failures] times and then behaves normally, standing
/// in for a scanner that releases its handle after a moment.
Future<void> Function(File, String) _refusingRename(int failures) {
  var attempts = 0;
  return (File temp, String targetPath) async {
    attempts++;
    if (attempts <= failures) {
      throw const FileSystemException(
        'Cannot rename file',
        'config.yaml.tmp',
        OSError('Access is denied.', 5),
      );
    }
    await temp.rename(targetPath);
  };
}

void main() {
  late Directory dir;
  late String configPath;
  late File temp;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('gitui_config_test');
    configPath = '${dir.path}${Platform.pathSeparator}config.yaml';
    temp = File('$configPath.tmp');
  });

  tearDown(() async {
    ConfigService.debugRenameOverride = null;
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  group('replacing the config', () {
    test('a rename refused twice still lands the settings', () async {
      await File(configPath).writeAsString('old: true\n');
      await temp.writeAsString('new: true\n');
      ConfigService.debugRenameOverride = _refusingRename(2);

      await ConfigService.replaceAtomically(temp, configPath);

      expect(await File(configPath).readAsString(), 'new: true\n');
      expect(
        await temp.exists(),
        isFalse,
        reason: 'a successful rename consumes the temporary file',
      );
    });

    test('a rename that never succeeds still saves the settings', () async {
      // The trade this makes on purpose: atomicity for one write, rather than
      // the user's change. The atomic path guards against a crash halfway
      // through a write, and a crash is far rarer than a scanner.
      await File(configPath).writeAsString('old: true\n');
      await temp.writeAsString('new: true\n');
      ConfigService.debugRenameOverride = _refusingRename(999);

      await ConfigService.replaceAtomically(temp, configPath);

      expect(await File(configPath).readAsString(), 'new: true\n');
      expect(await temp.exists(), isFalse);
    });

    test('the settings stay on disk when the target itself is held', () async {
      // Nothing can be written anywhere, so the temporary file must survive:
      // it is the only copy of what the user chose, and the next launch adopts
      // it.
      await temp.writeAsString('new: true\n');
      ConfigService.debugRenameOverride = _refusingRename(999);
      final blockedTarget =
          '${dir.path}${Platform.pathSeparator}missing'
          '${Platform.pathSeparator}config.yaml';

      await expectLater(
        ConfigService.replaceAtomically(temp, blockedTarget),
        throwsA(isA<ConfigWriteException>()),
      );
      expect(await temp.exists(), isTrue);
    });

    test('the failure explains itself without naming an errno', () async {
      await temp.writeAsString('new: true\n');
      ConfigService.debugRenameOverride = _refusingRename(999);
      final blockedTarget =
          '${dir.path}${Platform.pathSeparator}missing'
          '${Platform.pathSeparator}config.yaml';

      try {
        await ConfigService.replaceAtomically(temp, blockedTarget);
        fail('expected the write to fail');
      } on ConfigWriteException catch (error) {
        final String message = error.toString();
        expect(message, contains('settings could not be saved'));
        expect(message, contains(blockedTarget));
        expect(
          message,
          contains('antivirus'),
          reason: 'the message must name a cause the user can act on',
        );
      }
    });
  });

  group('recovering a stranded save', () {
    test('a newer temporary file is adopted', () async {
      // The field case: the write succeeded, the rename did not, and the app
      // kept reading the older file.
      await File(configPath).writeAsString('old: true\n');
      await temp.writeAsString('new: true\n');

      await ConfigService.recoverStrandedSave(configPath);

      expect(await File(configPath).readAsString(), 'new: true\n');
      expect(await temp.exists(), isFalse);
    });

    test('an unreadable temporary file is discarded, not adopted', () async {
      // Debris from a write interrupted partway through. Adopting it would
      // replace good settings with half of them; keeping it would make every
      // later launch try again.
      await File(configPath).writeAsString('old: true\n');
      await temp.writeAsString('key: [unterminated\n');

      await ConfigService.recoverStrandedSave(configPath);

      expect(await File(configPath).readAsString(), 'old: true\n');
      expect(await temp.exists(), isFalse);
    });

    test('a surviving temporary file is adopted however old it looks', () async {
      // Age cannot decide this. Measured on Windows, File.lastModified resolves
      // to whole seconds, so a temporary file written 60 ms before the config
      // carries an identical stamp and any ordering read from it is a guess.
      // Existence is the sound signal instead: a save that lands consumes its
      // temporary file, so a surviving one always belongs to a save that did
      // not.
      await temp.writeAsString('stranded: true\n');
      await File(configPath).writeAsString('current: true\n');

      await ConfigService.recoverStrandedSave(configPath);

      expect(await File(configPath).readAsString(), 'stranded: true\n');
      expect(await temp.exists(), isFalse);
    });

    test('a temporary file with no config beside it is adopted', () async {
      // The first save of a fresh installation, which failed at its last step.
      await temp.writeAsString('new: true\n');

      await ConfigService.recoverStrandedSave(configPath);

      expect(await File(configPath).readAsString(), 'new: true\n');
      expect(await temp.exists(), isFalse);
    });

    test('no temporary file is not an error', () async {
      await File(configPath).writeAsString('current: true\n');

      await ConfigService.recoverStrandedSave(configPath);

      expect(await File(configPath).readAsString(), 'current: true\n');
    });
  });
}
