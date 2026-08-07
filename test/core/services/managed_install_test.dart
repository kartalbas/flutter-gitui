// Whether the running application owns its own installation, and therefore
// whether it may update itself at all (#364).

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/services/managed_install.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';

/// A plain Linux desktop environment, so a test that stages a package manager
/// differs from a downloaded build in exactly the one variable it sets.
const Map<String, String> _plainLinuxEnvironment = {
  'HOME': '/home/mehmet',
  'PATH': '/usr/local/bin:/usr/bin:/bin',
  'LANG': 'en_US.UTF-8',
};

/// The same for Windows, where nothing but the install path identifies the
/// package manager that put the application there.
const Map<String, String> _plainWindowsEnvironment = {
  'USERPROFILE': r'C:\Users\mehmet',
  'LOCALAPPDATA': r'C:\Users\mehmet\AppData\Local',
};

void main() {
  group('ManagedInstallDetector.detect', () {
    test('recognises a snap from the environment snapd exports', () {
      final install = ManagedInstallDetector.detect(
        environment: {
          ..._plainLinuxEnvironment,
          'SNAP': '/snap/flutter-gitui/42',
          'SNAP_NAME': 'flutter-gitui',
          'SNAP_REVISION': '42',
        },
        executablePath: '/snap/flutter-gitui/42/bin/flutter_gitui',
      );

      expect(install, ManagedInstall.snap);
    });

    test('recognises a snap from its read-only mount point', () {
      // A relaunch through a wrapper can drop the snap variables; the mount
      // point the process runs from still says what this installation is.
      final install = ManagedInstallDetector.detect(
        environment: _plainLinuxEnvironment,
        executablePath: '/snap/flutter-gitui/current/bin/flutter_gitui',
      );

      expect(install, ManagedInstall.snap);
    });

    test('recognises a flatpak from either signal the sandbox exports', () {
      expect(
        ManagedInstallDetector.detect(
          environment: {
            ..._plainLinuxEnvironment,
            'FLATPAK_ID': 'io.github.kartalbas.FlutterGitUI',
          },
          executablePath: '/app/bin/flutter_gitui',
        ),
        ManagedInstall.flatpak,
      );
      expect(
        ManagedInstallDetector.detect(
          environment: {..._plainLinuxEnvironment, 'container': 'flatpak'},
          executablePath: '/app/bin/flutter_gitui',
        ),
        ManagedInstall.flatpak,
      );
    });

    test('recognises an AppImage from the variable its runtime exports', () {
      final install = ManagedInstallDetector.detect(
        environment: {
          ..._plainLinuxEnvironment,
          'APPIMAGE': '/home/mehmet/Downloads/FlutterGitUI.AppImage',
          'APPDIR': '/tmp/.mount_Flutte1a2b3c',
        },
        executablePath: '/tmp/.mount_Flutte1a2b3c/usr/bin/flutter_gitui',
      );

      expect(install, ManagedInstall.appImage);
    });

    test('recognises a winget package from the directory it installs into', () {
      // The project's winget manifest publishes a portable package, which
      // winget stages under %LOCALAPPDATA%\Microsoft\WinGet\Packages\<id>\.
      final install = ManagedInstallDetector.detect(
        environment: _plainWindowsEnvironment,
        executablePath:
            r'C:\Users\mehmet\AppData\Local\Microsoft\WinGet\Packages'
            r'\FlutterGitUI.FlutterGitUI_Microsoft.Winget.Source_8wekyb3d8bbwe'
            r'\flutter_gitui.exe',
      );

      expect(install, ManagedInstall.winget);
    });

    test('matches an install path whatever its casing', () {
      // Windows paths are case-insensitive, and winget has itself shipped both
      // "WinGet" and "Winget" in that directory name.
      final install = ManagedInstallDetector.detect(
        environment: _plainWindowsEnvironment,
        executablePath:
            r'c:\users\mehmet\appdata\local\microsoft\winget\packages'
            r'\fluttergitui.fluttergitui\flutter_gitui.exe',
      );

      expect(install, ManagedInstall.winget);
    });

    test('recognises a Microsoft Store package from WindowsApps', () {
      final install = ManagedInstallDetector.detect(
        environment: _plainWindowsEnvironment,
        executablePath:
            r'C:\Program Files\WindowsApps'
            r'\FlutterGitUI_0.5.18.0_x64__8wekyb3d8bbwe\flutter_gitui.exe',
      );

      expect(install, ManagedInstall.microsoftStore);
    });

    test('recognises a Homebrew cask from the Caskroom it is staged in', () {
      // Platform.resolvedExecutable resolves the /Applications symlink a cask
      // installs, so the Caskroom path is what the running process reports.
      final install = ManagedInstallDetector.detect(
        environment: const {'HOME': '/Users/mehmet'},
        executablePath:
            '/opt/homebrew/Caskroom/flutter-gitui/0.5.18/Flutter GitUI.app'
            '/Contents/MacOS/flutter_gitui',
      );

      expect(install, ManagedInstall.homebrewCask);
    });

    test('leaves a directly downloaded build to update itself', () {
      // The behaviour that must not change: a build from the releases page
      // owns its directory, so nothing is suppressed for it.
      expect(
        ManagedInstallDetector.detect(
          environment: _plainWindowsEnvironment,
          executablePath: r'C:\Program Files\FlutterGitUI\flutter_gitui.exe',
        ),
        isNull,
      );
      expect(
        ManagedInstallDetector.detect(
          environment: _plainLinuxEnvironment,
          executablePath: '/home/mehmet/apps/flutter-gitui/flutter_gitui',
        ),
        isNull,
      );
    });

    test('ignores a package manager variable that carries no value', () {
      // An exported but empty variable states nothing, and treating it as a
      // snap would suppress updates for a downloaded build for no reason.
      final install = ManagedInstallDetector.detect(
        environment: {
          ..._plainLinuxEnvironment,
          'SNAP': '',
          'SNAP_NAME': '   ',
          'FLATPAK_ID': '',
          'APPIMAGE': '',
        },
        executablePath: '/home/mehmet/apps/flutter-gitui/flutter_gitui',
      );

      expect(install, isNull);
    });

    test('treats an installation it cannot place as managed', () {
      // The fail-safe direction: a package manager wrongly assumed still
      // delivers the update, while a wrongly claimed installation is corrupted
      // by the very update this application would install into it.
      expect(
        ManagedInstallDetector.detect(
          environment: _plainLinuxEnvironment,
          executablePath: '',
        ),
        ManagedInstall.undetermined,
      );
      expect(
        ManagedInstallDetector.detect(
          environment: const {},
          executablePath: '   ',
        ),
        ManagedInstall.undetermined,
      );
    });
  });

  group('ManagedInstall', () {
    test('names a manager for every installation it can identify', () {
      // The name is a proper noun the enum spells once and no locale touches,
      // so it has to be there -- and only the value that identified nothing at
      // all may be without one.
      for (final install in ManagedInstall.values) {
        if (install == ManagedInstall.undetermined) {
          expect(install.manager, isNull, reason: install.name);
          continue;
        }
        expect(install.manager?.trim(), isNotEmpty, reason: install.name);
      }
    });
  });

  group('ManagedInstall messages', () {
    /// Every locale the application ships, so a value added without its
    /// translations fails here rather than showing an English sentence -- or
    /// nothing -- in the five other languages (#389).
    late Map<Locale, AppLocalizations> translations;

    setUpAll(() async {
      translations = {
        for (final locale in AppLocalizations.supportedLocales)
          locale: await AppLocalizations.delegate.load(locale),
      };
    });

    test('explains every managed installation in every locale', () {
      // Settings and the update dialog show this verbatim, so a value added
      // later without its copy would ship an empty explanation.
      for (final entry in translations.entries) {
        for (final install in ManagedInstall.values) {
          final where = '${install.name} in ${entry.key.languageCode}';
          final explanation = install.explanation(entry.value).trim();
          expect(explanation, isNotEmpty, reason: where);
          expect(
            explanation,
            endsWith('.'),
            reason: '$where is shown as a sentence',
          );
        }
      }
    });

    test('keeps the manager name untranslated in every locale', () {
      // The design decision this pins: the sentence around the name is prose
      // and belongs to the translations, the name itself is a proper noun and
      // has to come through every locale spelled exactly as the enum has it.
      for (final entry in translations.entries) {
        for (final install in ManagedInstall.values) {
          final where = '${install.name} in ${entry.key.languageCode}';
          final line = install.managedByLine(entry.value);
          expect(line.trim(), isNotEmpty, reason: where);

          final manager = install.manager;
          if (manager == null) {
            // Nothing was identified, so the line names no product at all.
            continue;
          }
          expect(line, contains(manager), reason: where);
        }
      }
    });

    test('names no manager it could not identify', () {
      // "Updates are managed by null" is the failure this forbids: the
      // undetermined case gets a sentence of its own rather than a hole where
      // a proper noun would be.
      for (final entry in translations.entries) {
        final line = ManagedInstall.undetermined.managedByLine(entry.value);
        expect(line, isNot(contains('null')), reason: entry.key.languageCode);
      }
    });
  });
}
