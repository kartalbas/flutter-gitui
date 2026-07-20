#!/bin/sh
# Registers this extracted archive with the desktop environment: application
# menu entry plus icon, both scoped to the current user.
#
# The entry cannot ship ready-made inside the archive. A .desktop file is only
# picked up by a menu once it lives in an XDG applications directory, and from
# there nothing in the file can point back at wherever the archive happens to
# have been unpacked - %k expands to the installed copy's own location, and the
# spec permits it to be empty. So the absolute path is resolved here, at install
# time, and baked into the entry that gets written.
set -eu

APP_ID="com.fluttergitui.flutter_gitui"
BINARY="flutter_gitui"
ICON_SOURCE="flutter-gitui.svg"

APP_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
BINARY_PATH="$APP_DIR/$BINARY"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
DESKTOP_DIR="$DATA_HOME/applications"
ICON_DIR="$DATA_HOME/icons/hicolor/scalable/apps"
DESKTOP_FILE="$DESKTOP_DIR/$APP_ID.desktop"
ICON_FILE="$ICON_DIR/$APP_ID.svg"

usage() {
  cat <<USAGE
Usage: $0 [--uninstall]

Installs a menu entry and icon for the copy of Flutter GitUI in
$APP_DIR
for the current user only. Nothing outside \$XDG_DATA_HOME is touched and no
elevated rights are needed.

  (no argument)  install or refresh the entry
  --uninstall    remove the entry and the icon again

Re-run without arguments after moving the application directory; the entry
records an absolute path and does not follow it.
USAGE
}

# Cache refreshes are best-effort: neither tool is guaranteed to exist, and
# without them the entry still resolves, it just may take a session restart to
# show up.
refresh_caches() {
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
  fi
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t "$DATA_HOME/icons/hicolor" >/dev/null 2>&1 || true
  fi
}

case "${1:-}" in
  --uninstall)
    for installed in "$DESKTOP_FILE" "$ICON_FILE"; do
      if [ -e "$installed" ]; then
        rm -f "$installed"
        echo "Removed $installed"
      else
        echo "Not installed: $installed"
      fi
    done
    refresh_caches
    echo "The application directory itself is untouched - delete $APP_DIR to finish."
    exit 0
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  "") ;;
  *)
    echo "$0: unknown argument '$1'" >&2
    usage >&2
    exit 2
    ;;
esac

if [ ! -f "$BINARY_PATH" ]; then
  echo "$0: '$BINARY' is not next to this script." >&2
  echo "Keep the script inside the extracted archive and run it from there." >&2
  exit 1
fi

# A '%' cannot be carried through an Exec value at all: left bare it starts a
# field code and the launcher strips it, and doubled to '%%' the loader rejects
# the whole entry, because it tests the program for existence before expanding
# anything. Either way the menu would end up with nothing, so refuse instead of
# writing an entry that cannot work. Control characters cannot survive the
# line-based file format either.
case $BINARY_PATH in
  *%*)
    echo "$0: the path to this directory contains '%', which a desktop entry" >&2
    echo "cannot express. Move the application somewhere without it and re-run." >&2
    echo "  $APP_DIR" >&2
    exit 1
    ;;
esac
if [ "$(printf '%s' "$BINARY_PATH" | tr -d '[:cntrl:]')" != "$BINARY_PATH" ]; then
  echo "$0: the path to this directory contains a control character, which a" >&2
  echo "desktop entry cannot express. Move the application and re-run." >&2
  exit 1
fi

# An Exec value is not a plain path: it is parsed with quoting rules. A path of
# unreserved characters only is passed through as is, which keeps the common
# case readable for anything that inspects the entry; anything else becomes one
# quoted argument, its reserved characters escaped twice over - once for that
# command-line parsing, once for the escape rules of the key-file value carrying
# it.
case $BINARY_PATH in
  *[!A-Za-z0-9._+,:@/=-]*)
    EXEC_VALUE='"'$(printf '%s' "$BINARY_PATH" | sed 's/\\/\\\\\\\\/g; s/["`$]/\\\\&/g')'"'
    ;;
  *)
    EXEC_VALUE=$BINARY_PATH
    ;;
esac

# Some graphical archive managers drop the executable bit on extraction, which
# would leave the entry pointing at something that cannot be exec'd - and an
# entry whose program does not resolve is dropped by the launcher outright, so
# the menu would simply stay empty.
chmod +x "$BINARY_PATH"
if [ -f "$APP_DIR/updater" ]; then
  chmod +x "$APP_DIR/updater"
fi

mkdir -p "$DESKTOP_DIR" "$ICON_DIR"

cat > "$DESKTOP_FILE" <<DESKTOP
[Desktop Entry]
Type=Application
Version=1.0
Name=Flutter GitUI
GenericName=Git Client
Comment=Modern Git GUI built with Flutter
Exec=$EXEC_VALUE %F
Icon=$APP_ID
Terminal=false
Categories=Development;RevisionControl;
Keywords=git;version control;vcs;
StartupNotify=true
StartupWMClass=$APP_ID
DESKTOP
chmod 644 "$DESKTOP_FILE"

if [ -f "$APP_DIR/$ICON_SOURCE" ]; then
  cp "$APP_DIR/$ICON_SOURCE" "$ICON_FILE"
  chmod 644 "$ICON_FILE"
else
  echo "warning: $ICON_SOURCE missing, the entry will use a generic icon" >&2
fi

if command -v desktop-file-validate >/dev/null 2>&1; then
  desktop-file-validate "$DESKTOP_FILE" || true
fi

refresh_caches

echo "Installed $DESKTOP_FILE"
echo "  -> $APP_DIR/$BINARY"
echo "Flutter GitUI should now appear in the application menu; some desktops"
echo "only pick it up after logging out and back in."
echo "Run '$0 --uninstall' to remove it again."
