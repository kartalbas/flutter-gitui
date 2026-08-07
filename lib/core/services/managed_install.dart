import 'dart:io';

/// Who owns an installation of this application, when that is not the
/// application itself.
///
/// A build downloaded from the releases page owns the directory it runs from
/// and may replace its own files. An installation that came from a package
/// manager may not, and the two ways of getting that wrong are not symmetric.
/// A snap runs from a read-only image, so an in-app install can only ever fail
/// -- once for every release, forever. The winget package directory, by
/// contrast, is user-writable, so the in-app install succeeds and quietly
/// replaces files winget still records as the old version, until the next
/// `winget upgrade` overwrites them again (#364).
enum ManagedInstall {
  /// snapd mounts the snap read-only at `$SNAP` and refreshes it on its own.
  snap(
    manager: 'Snap',
    explanation:
        'This copy was installed as a snap and runs from a read-only image, '
        'so it cannot replace its own files. snapd installs new versions in '
        'the background, or immediately with "snap refresh flutter-gitui".',
  ),

  /// A Flatpak runs from a read-only deployment that flatpak itself replaces.
  flatpak(
    manager: 'Flatpak',
    explanation:
        'This copy was installed with Flatpak and runs from a read-only '
        'deployment, so it cannot replace its own files. New versions arrive '
        'with "flatpak update".',
  ),

  /// An AppImage is a read-only image mounted only for the length of the run,
  /// so the files the updater would overwrite disappear again at exit.
  appImage(
    manager: 'AppImage',
    explanation:
        'This copy runs from a read-only AppImage, so it cannot replace its '
        'own files. Download a newer AppImage to update it.',
  ),

  /// winget keeps its own record of the installed version, and that record is
  /// what the next upgrade acts on -- not what is actually on disk.
  winget(
    manager: 'winget',
    explanation:
        'This copy was installed with winget, which records the installed '
        'version itself. Updating from inside the application would replace '
        'those files behind winget\'s back and be overwritten again by the '
        'next "winget upgrade", so new versions are taken from winget.',
  ),

  /// A packaged application is deployed read-only and signed under
  /// `Program Files\WindowsApps`, where nothing but the Store may write.
  microsoftStore(
    manager: 'the Microsoft Store',
    explanation:
        'This copy was installed from the Microsoft Store, which deploys it '
        'into a read-only, signed package directory. New versions arrive '
        'through the Store.',
  ),

  /// Homebrew stages a cask in its own Caskroom, links the bundle from there
  /// and keeps the version record next to it.
  homebrewCask(
    manager: 'Homebrew',
    explanation:
        'This copy was installed as a Homebrew cask, which records the '
        'installed version itself. New versions arrive with '
        '"brew upgrade --cask flutter-gitui".',
  ),

  /// Where this application runs from could not be established at all.
  ///
  /// Refusing here is the conservative side of the trade. A package manager
  /// that was wrongly detected still delivers its update, so a false
  /// suppression costs the user a delay; a false "this installation is ours"
  /// corrupts a managed installation and keeps corrupting it.
  undetermined(
    manager: 'the installer this copy came from',
    explanation:
        'Where this copy is installed could not be established, so it is '
        'treated as belonging to whoever installed it. Updating it from '
        'inside the application could overwrite files a package manager owns.',
  );

  const ManagedInstall({required this.manager, required this.explanation});

  /// Who delivers new versions, phrased to follow "managed by".
  final String manager;

  /// Why this application does not update itself here, in a sentence a
  /// settings screen can show as-is.
  final String explanation;
}

/// Whether the running process belongs to an installation a package manager
/// owns, and to which one.
///
/// The decision is deliberately a named seam of its own rather than a condition
/// inside the update check: both inputs it needs are passed in, so a test can
/// stage a snap or a winget install without either being real. Only
/// [detectCurrentProcess] reads [Platform], and it does nothing else.
class ManagedInstallDetector {
  /// The package manager owning an installation described by [environment] and
  /// [executablePath], or null when the application owns it and may update
  /// itself exactly as a directly downloaded build always has.
  ///
  /// Every signal used here is one a package manager sets itself; nothing is
  /// inferred from a version string or a guessed directory name, because a
  /// wrong guess in either direction is worse than the case it would cover.
  static ManagedInstall? detect({
    required Map<String, String> environment,
    required String executablePath,
  }) {
    // snapd exports SNAP as the mount point of the read-only image and
    // SNAP_NAME as the package name, for classic and confined snaps alike.
    if (_isSet(environment, 'SNAP') || _isSet(environment, 'SNAP_NAME')) {
      return ManagedInstall.snap;
    }

    // FLATPAK_ID is exported into every process inside the sandbox, and the
    // container variable carries the same fact under a portable name.
    if (_isSet(environment, 'FLATPAK_ID') ||
        environment['container']?.trim() == 'flatpak') {
      return ManagedInstall.flatpak;
    }

    // The AppImage runtime exports the path of the image it has mounted.
    if (_isSet(environment, 'APPIMAGE')) return ManagedInstall.appImage;

    final location = _normalise(executablePath);

    // Nothing to match against means the run cannot be placed at all, and an
    // installation that cannot be placed is not one this application may claim.
    if (location.isEmpty) return ManagedInstall.undetermined;

    // A snap whose environment did not survive -- a relaunch through a wrapper
    // script, say -- is still recognisable by the mount point it runs from.
    if (location.startsWith('/snap/')) return ManagedInstall.snap;

    // winget stages a portable package under
    // %LOCALAPPDATA%\Microsoft\WinGet\Packages\<PackageIdentifier>\, which is
    // the install type this project's winget manifest publishes.
    if (location.contains('/winget/packages/')) return ManagedInstall.winget;

    // An MSIX package is deployed read-only under Program Files\WindowsApps.
    if (location.contains('/windowsapps/')) {
      return ManagedInstall.microsoftStore;
    }

    // A cask stages the bundle in the Caskroom and links it into
    // /Applications; Platform.resolvedExecutable resolves that link, so the
    // Caskroom is what the running process reports.
    if (location.contains('/caskroom/')) return ManagedInstall.homebrewCask;

    // No package manager claimed this installation, so the application owns it
    // and the update path stays exactly what it is for a downloaded build.
    return null;
  }

  /// The same question asked about the process that is running now.
  static ManagedInstall? detectCurrentProcess() {
    try {
      return detect(
        environment: Platform.environment,
        executablePath: Platform.resolvedExecutable,
      );
    } catch (_) {
      // Neither read is expected to fail, but a platform that cannot answer
      // has told us nothing, and nothing is not permission to overwrite files.
      return ManagedInstall.undetermined;
    }
  }

  /// Whether an environment variable exists and carries an actual value; a
  /// manager that exports the name but leaves it empty has said nothing.
  static bool _isSet(Map<String, String> environment, String name) =>
      (environment[name] ?? '').trim().isNotEmpty;

  /// Lower-cased and with forward slashes throughout, so one set of markers
  /// matches on every platform and whatever the casing of the real path.
  static String _normalise(String executablePath) =>
      executablePath.trim().replaceAll('\\', '/').toLowerCase();
}
