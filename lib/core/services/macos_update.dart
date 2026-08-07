/// The mechanics of replacing a running `.app` bundle on macOS.
///
/// Everything here is pure string work on purpose: the two things that decide
/// whether a macOS update succeeds -- which directory is the bundle, and what
/// exactly the helper script runs -- are then provable on any machine, which
/// matters more than usual because this project has no Mac to try them on.
///
/// The shape follows the Windows updater rather than inventing a second
/// mechanism: wait for the application's process to exit, unpack, put the new
/// files where the old ones were, relaunch, exit (`release/updater/`). What
/// differs is the helper itself. On Windows and Linux the archive ships a
/// compiled `updater` binary next to the executable; on macOS it cannot, for
/// two reasons that both point the same way. A loose executable inside the
/// release zip is not covered by the notarisation of the `.app`, so Gatekeeper
/// would block the very helper meant to rescue the update; and an installation
/// that is already on a user's disk has no helper in it either, so the first
/// macOS update can never depend on one being there. A short script handed to
/// `/bin/sh` -- Apple's own, always present, always trusted -- needs nothing
/// added to the bundle and works for the installations that exist today. It is
/// the same fallback shape `_installWindowsUpdate` and `_installLinuxUpdate`
/// already use when their binary is missing.
library;

import 'package:path/path.dart' as path;

/// The `.app` bundle the executable at [executablePath] belongs to, or null
/// when it does not run from one.
///
/// `Platform.resolvedExecutable` inside a bundle is
/// `…/Something.app/Contents/MacOS/flutter_gitui`, and the directory to
/// replace is `…/Something.app`. The layout is checked rather than assumed:
/// a build run straight out of `build/macos/…` or from a symlinked binary
/// outside any bundle must answer "not a bundle" instead of handing a
/// recursive delete the wrong directory.
String? macosBundlePath(String executablePath) {
  final normalised = executablePath.trim().replaceAll('\\', '/');
  if (normalised.isEmpty) return null;

  // posix explicitly: this parses a macOS path, and a test for it must not
  // change meaning because it happens to run on Windows.
  final segments = path.posix.split(normalised);
  for (var i = segments.length - 1; i >= 0; i--) {
    if (!segments[i].toLowerCase().endsWith('.app')) continue;
    // Only the canonical bundle layout counts; anything else is a directory
    // that merely ends in '.app'.
    if (i + 2 >= segments.length) return null;
    if (segments[i + 1] != 'Contents' || segments[i + 2] != 'MacOS') {
      return null;
    }
    return path.posix.joinAll(segments.sublist(0, i + 1));
  }
  return null;
}

/// Whether the macOS archive a manifest describes may be installed by the
/// application itself.
///
/// The release job writes `signed: true` only for the artifact it signed with
/// a Developer ID certificate, notarised and stapled; the ad-hoc-signed
/// fallback it publishes when no signing secrets are configured is flagged
/// `signed: false`.
///
/// Read from the manifest rather than baked into the build, because the
/// property that decides the outcome belongs to the bundle about to be
/// installed, not to the one already running -- and because a client that is
/// already on a user's disk cannot be changed, so the day signing is
/// configured, self-update has to switch itself on with no new release needed
/// on the client side.
///
/// A manifest without the field is treated as unsigned. Every macOS manifest
/// ever written carries it, so an absent field means something unexpected, and
/// the failure mode of guessing "signed" is an application the user can no
/// longer open.
bool macosArchiveIsSelfInstallable(Map<String, dynamic>? platformData) =>
    platformData?['signed'] == true;

/// The helper script that performs the swap, fully quoted and ready to run.
///
/// A separate, pure function so a test can read it: a quoting mistake here is
/// not a compile error and not something this project can discover by running
/// it, but it is exactly the kind of thing that destroys an installation.
/// macOS paths routinely contain spaces ("/Applications/Flutter GitUI.app"),
/// and an apostrophe is legal in every one of them.
String macosUpdateScript({
  required String bundlePath,
  required String archivePath,
  required String stagePath,
  required String backupPath,
  required String logPath,
  required int appPid,
}) {
  final values = <String, String>{
    '__APP__': _shellQuote(bundlePath),
    '__ARCHIVE__': _shellQuote(archivePath),
    '__STAGE__': _shellQuote(stagePath),
    '__BACKUP__': _shellQuote(backupPath),
    '__LOG__': _shellQuote(logPath),
    '__PID__': _shellQuote('$appPid'),
  };
  // One pass over the template, so a path that happens to contain another
  // token's text cannot be substituted a second time.
  return _macosUpdateTemplate.replaceAllMapped(
    RegExp(r'__[A-Z_]+__'),
    (match) => values[match[0]] ?? match[0]!,
  );
}

/// [value] as a single shell word, whatever it contains.
///
/// Single quotes suspend every expansion the shell performs, so the only
/// character needing care is the quote itself: close, escape it, reopen.
String _shellQuote(String value) => "'${value.replaceAll("'", r"'\''")}'";

/// The swap, in the order that keeps a working application on disk at every
/// step. Placeholders are substituted by [macosUpdateScript]; nothing else in
/// here is interpolated, so the shell reads exactly what is written.
const String _macosUpdateTemplate = r'''
#!/bin/sh
# Flutter GitUI update helper.
#
# Written by the application it updates, started detached just before that
# application quits, and deleted by its own last line. It exists because a
# bundle cannot replace itself while it is running.
set -u

APP=__APP__
ARCHIVE=__ARCHIVE__
STAGE=__STAGE__
BACKUP=__BACKUP__
LOG=__LOG__
APP_PID=__PID__

note() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [FlutterGitUI] [UPDATER] $1" >>"$LOG" 2>/dev/null
}

give_up() {
  note "$1"
  rm -rf "$STAGE"
  exit 1
}

# Nothing may touch the bundle while the application still has files inside it
# open. Poll the process instead of sleeping a fixed time: a slow quit would
# otherwise race the swap, and a fast one would cost the user a needless wait.
waited=0
while kill -0 "$APP_PID" 2>/dev/null; do
  if [ "$waited" -ge 60 ]; then
    give_up "the application did not exit within 60 seconds, so the update was not applied"
  fi
  sleep 1
  waited=$((waited + 1))
done

rm -rf "$STAGE" "$BACKUP"
mkdir -p "$STAGE" || give_up "could not create the staging directory"

# ditto, not unzip: it is Apple's own archiver and the only one that restores
# the bundle metadata and the framework symlinks that a code signature and a
# stapled notarisation ticket are validated against.
ditto -x -k "$ARCHIVE" "$STAGE" || give_up "could not unpack the downloaded archive"

# The signed archive carries the bundle at its root, the unsigned one carries
# it beside a README, so the bundle sits at depth one or two.
NEW=$(find "$STAGE" -maxdepth 2 -name '*.app' -print | head -1)
[ -n "$NEW" ] || give_up "the downloaded archive contains no .app bundle"

# Move the old bundle aside rather than deleting it: while the new one is not
# yet in place, this copy is all that stands between the user and having no
# application at all.
mv "$APP" "$BACKUP" || give_up "could not move the installed application aside"
if ! mv "$NEW" "$APP"; then
  if mv "$BACKUP" "$APP"; then
    give_up "could not put the new version in place; the previous one was restored"
  fi
  give_up "could not put the new version in place, and the previous one is left at $BACKUP"
fi

rm -rf "$BACKUP" "$STAGE"
rm -f "$ARCHIVE"
note "updated the application at $APP"

# open, not the executable: LaunchServices starts the bundle the way the user's
# session expects it to be started, and detached from this script.
open "$APP" || note "the update was applied but the application could not be relaunched"

rm -f "$0"
''';
