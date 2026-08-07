// How a macOS update finds the bundle it must replace, decides whether it may
// replace it at all, and what the helper script it hands the swap to actually
// contains (#387).
//
// Every one of these is pure string work on purpose. This project has no Mac,
// so the only way a quoting or layout mistake gets caught before it reaches a
// user is here.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/services/macos_update.dart';
import 'package:flutter_gitui/core/services/update_service.dart';

void main() {
  group('the manifest each platform reads', () {
    test('names an asset the release workflow actually publishes', () {
      expect(
        UpdateService.manifestFileNameFor('windows'),
        'latest-windows.json',
      );
      expect(UpdateService.manifestFileNameFor('linux'), 'latest-linux.json');
      expect(UpdateService.manifestFileNameFor('macos'), 'latest-macos.json');
    });

    test('answers null rather than inventing a name nobody writes', () {
      // The old fallback was 'latest.json', an asset no release has ever
      // carried, so macOS reported a release with a missing manifest instead
      // of an unsupported platform.
      expect(UpdateService.manifestFileNameFor('android'), isNull);
      expect(UpdateService.manifestFileNameFor('fuchsia'), isNull);
    });
  });

  group('macosBundlePath', () {
    test('finds the bundle an installed executable runs from', () {
      expect(
        macosBundlePath(
          '/Applications/Flutter GitUI.app/Contents/MacOS/flutter_gitui',
        ),
        '/Applications/Flutter GitUI.app',
      );
    });

    test('finds it under a home directory just as well', () {
      expect(
        macosBundlePath(
          '/Users/mehmet/Applications/flutter_gitui.app/Contents/MacOS/x',
        ),
        '/Users/mehmet/Applications/flutter_gitui.app',
      );
    });

    test('refuses anything that is not the canonical bundle layout', () {
      // A development build run straight out of the build directory, and a
      // binary that merely lives under a directory ending in .app: replacing
      // "two levels up" in either case would move something nobody asked for.
      expect(
        macosBundlePath('/home/user/flutter-gitui/build/flutter_gitui'),
        isNull,
      );
      expect(
        macosBundlePath('/Applications/Some.app/Contents/flutter_gitui'),
        isNull,
      );
      expect(macosBundlePath('/Applications/Some.app/helper/bin/x'), isNull);
      expect(macosBundlePath(''), isNull);
    });
  });

  group('whether a published macOS archive may be installed in place', () {
    test('only when the release job signed and notarised it', () {
      expect(macosArchiveIsSelfInstallable({'signed': true}), isTrue);
    });

    test('never when it says otherwise, and never when it says nothing', () {
      // Fail closed: guessing "signed" costs the user an application that no
      // longer opens, guessing "unsigned" costs them one manual download.
      expect(macosArchiveIsSelfInstallable({'signed': false}), isFalse);
      expect(macosArchiveIsSelfInstallable({'fileName': 'x.zip'}), isFalse);
      expect(macosArchiveIsSelfInstallable({'signed': 'true'}), isFalse);
      expect(macosArchiveIsSelfInstallable(null), isFalse);
    });
  });

  group('the helper script', () {
    String scriptFor({
      String bundlePath = '/Applications/Flutter GitUI.app',
      String archivePath = '/tmp/flutter-gitui-v1.zip',
      String stagePath = '/Applications/.flutter-gitui-update-42',
      String backupPath = '/Applications/Flutter GitUI.app.previous-42',
      String logPath = '/Users/m/.flutter-gitui/app.log',
      int appPid = 42,
    }) => macosUpdateScript(
      bundlePath: bundlePath,
      archivePath: archivePath,
      stagePath: stagePath,
      backupPath: backupPath,
      logPath: logPath,
      appPid: appPid,
    );

    test('waits for the application before touching the bundle', () {
      final script = scriptFor();

      expect(script, contains('APP_PID=\'42\''));
      expect(script, contains('kill -0 "\$APP_PID"'));
      // The wait has to come before the move, or the swap races a process
      // that still has files inside the bundle open.
      expect(
        script.indexOf('kill -0'),
        lessThan(script.indexOf('mv "\$APP" "\$BACKUP"')),
      );
    });

    test('unpacks with ditto, which preserves what a signature is checked '
        'against', () {
      final script = scriptFor();

      expect(script, contains('ditto -x -k "\$ARCHIVE" "\$STAGE"'));
      // unzip drops the bundle metadata and flattens the framework symlinks,
      // which is exactly what invalidates a signature. It may be named in a
      // comment; it must never be the command that runs.
      expect(
        script.split('\n').where((line) => line.startsWith('unzip ')),
        isEmpty,
      );
    });

    test('keeps the installed version until the new one is in place', () {
      final script = scriptFor();

      // Aside, then in, then restore on failure: at no point is the bundle
      // simply deleted.
      expect(
        script.indexOf('mv "\$APP" "\$BACKUP"'),
        lessThan(script.indexOf('mv "\$NEW" "\$APP"')),
      );
      expect(script, contains('mv "\$BACKUP" "\$APP"'));
      expect(script, isNot(contains('rm -rf "\$APP"')));
    });

    test('relaunches through LaunchServices and removes itself', () {
      final script = scriptFor();

      expect(script, contains('open "\$APP"'));
      expect(script, contains('rm -f "\$0"'));
    });

    test('quotes a path with spaces as one word', () {
      final script = scriptFor(bundlePath: '/Applications/Flutter GitUI.app');

      expect(script, contains("APP='/Applications/Flutter GitUI.app'"));
    });

    test('survives an apostrophe in the path', () {
      // Legal in every macOS path, and the one character single quoting has to
      // handle: close, escape, reopen.
      final script = scriptFor(bundlePath: "/Users/o'brien/App.app");

      expect(script, contains(r"APP='/Users/o'\''brien/App.app'"));
      // Nothing after it may leak out of the quotes.
      expect(script, isNot(contains("APP='/Users/o'brien")));
    });

    test('leaves no placeholder unsubstituted', () {
      final script = scriptFor();

      expect(RegExp(r'__[A-Z_]+__').hasMatch(script), isFalse);
    });

    test('substitutes each placeholder exactly once', () {
      // A path that happens to contain another placeholder's text must be
      // taken literally rather than substituted a second time.
      final script = scriptFor(bundlePath: '/Applications/__STAGE__.app');

      expect(script, contains("APP='/Applications/__STAGE__.app'"));
      expect(
        script,
        contains("STAGE='/Applications/.flutter-gitui-update-42'"),
      );
    });
  });
}
