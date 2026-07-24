# Flutter GitUI

> A modern, cross-platform desktop Git client built with Flutter.

![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.44.4-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.9.2+-0175C2?logo=dart)
![License](https://img.shields.io/badge/license-ELv2-blue)
[![Latest release](https://img.shields.io/github/v/release/kartalbas/flutter-gitui?include_prereleases&label=release)](https://github.com/kartalbas/flutter-gitui/releases)

Flutter GitUI is a graphical front-end for the Git command line. It drives your
own installed `git` — every operation is a real git command you could have typed
yourself — and wraps it in a fast, keyboard-friendly Material Design 3 interface
that manages many repositories at once. It is aimed at people who work across a
fleet of repositories (a GitOps layout, a monorepo split into services) and want
one window to see and act on all of them.

---

## Table of contents

- [Features](#features)
- [Download and install](#download-and-install)
- [Requirements](#requirements)
- [Project status](#project-status)
- [Updating](#updating)
- [Languages](#languages)
- [Building from source](#building-from-source)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

---

## Features

**Many repositories at once.** Group repositories into workspaces and see them
on one dashboard, each card showing its branch and whether it is ahead, behind,
dirty or broken. Add repositories by opening, cloning or initialising them, or by
dragging a folder onto the window. Toolbar git actions operate on one *to many*
repositories at a time.

**Staging and committing.** Review the working tree, stage and unstage by file or
all at once, discard changes, delete untracked files, and commit — with an amend
option and an inline diff of what you are about to record.

**History and the commit graph.** Browse the log with a rendered branch-topology
graph, inspect any commit's diff, and compare two commits side by side. From a
commit you can revert it, cherry-pick it, reset the branch to it (soft, mixed or
hard), squash a range, or start a new branch or tag. A structured search filters
the log by author, message, date and more.

**Branches, tags and stashes.** Create, rename, checkout, merge, rebase and delete
branches (force-delete included); create lightweight or annotated tags and push or
delete them locally and on the remote; create, apply, pop, drop and clear stashes,
or turn a stash into a branch.

**Remotes and syncing.** Fetch, pull (merge, rebase or fast-forward), push and
force-push; add, edit, rename and remove remotes; prune stale remote-tracking
branches.

**Merge and conflict resolution.** A dedicated screen to resolve conflicts by
choosing ours, theirs or the base per file, or to abort the merge.

**Advanced git.** Interactive-friendly rebase, `git bisect` (start, mark good/bad,
skip, reset), the reflog, and per-line blame.

**File browser and viewers.** Walk the repository tree, preview files as text,
Markdown, CSV tables or images, and view a file's own history and blame.

**Command palette (Ctrl+K).** One search box for every operation — type
`commit`, `pull`, `branch`, `bisect`, `stash`, `tag` and jump straight to it.

**Command log.** A live panel showing the exact git command run for each action,
with its success or failure, so nothing the app does is hidden from you.

**Confirmation model that scales with danger.** Destructive actions are confirmed
in proportion to how much they can hurt: a revert (a new commit) asks lightly; a
`reset --hard`, `clean` or stash drop (unrecoverable local loss) always asks with
a red warning; force-pushing or deleting a remote branch (which can destroy other
people's work) confirms hardest of all. A single "confirm destructive actions"
setting governs the recoverable tiers.

**External diff and merge tools.** Auto-detects installed tools (VS Code, Beyond
Compare, KDiff3, WinMerge, Meld and more) and launches them for a diff or a merge
with one click.

**User-controlled updates.** The app can check for new releases automatically, but
installing an update — which closes the app — is never automatic; you decide when.
Downloads are verified against a SHA-256 published with the release before anything
is replaced. An in-app release history shows what changed in each version.

**Made to look right.** Material Design 3 with selectable colour schemes,
light/dark themes and font choices, and a full six-language interface.

---

## Download and install

Get the latest build from the [releases page](https://github.com/kartalbas/flutter-gitui/releases).

| Platform | File | How to start |
|----------|------|--------------|
| Windows | `flutter-gitui-v<version>-windows.zip` | Extract, run `flutter_gitui.exe` |
| Linux | `flutter-gitui-v<version>-linux.tar.gz` | Extract, run `./flutter_gitui` (optionally `./install-desktop-entry.sh` first) |

Both archives are flat — their contents land directly in the target directory
rather than in a wrapping folder. Each release also carries a
`latest-<platform>.json` manifest holding the SHA-256 of the archive it names; the
in-app update check verifies that digest before installing anything.

The Linux archive additionally carries `install-desktop-entry.sh`. Running it once
— no root, nothing written outside your own `~/.local/share` — creates a desktop
entry with the absolute path of the extracted directory baked into it and installs
the application icon into the user icon theme, so Flutter GitUI appears in the
application menu with its icon; `./install-desktop-entry.sh --uninstall` removes
both again. Because that path is recorded absolutely, re-run the script if you move
the directory. Skipping the script costs nothing else: `./flutter_gitui` still
starts the application, it simply stays absent from the menu and shows a generic
icon in file managers.

---

## Requirements

- **A git executable.** The application drives the Git CLI and does not bundle one.
  On first start it opens Settings and names exactly which settings are missing,
  with one-click detection for git, diff tools and editors.
- **Linux:** glibc 2.35 or newer — Ubuntu 22.04+, Debian 12+, or anything more
  recent. The build is pinned to that floor and CI fails if a toolchain change
  raises it.
- **Windows:** nothing beyond the archive. The Microsoft C++ runtime ships inside
  it.

---

## Project status

**This project is in active development. The current release is an alpha.**

| Platform | Status |
|----------|--------|
| Windows | Built and published. Primary development platform. |
| Linux | Built and published. |
| macOS | Builds on every commit, but not published: the app is signed ad-hoc without a hardened runtime, so Gatekeeper refuses to open it. Publishing waits on a Developer ID certificate and notarisation. |

Known limitations of the current alpha are listed in the release notes.

---

## Updating

Updates are entirely under your control:

- **Checking** can be automatic (configurable in Settings) or on demand.
- **Installing is never automatic**, because applying an update closes the running
  app. You are shown what the new version changes and choose when to install.
- **Every download is verified** against the SHA-256 in the release's
  `latest-<platform>.json` manifest before it replaces anything.

The **Release History** dialog inside the app shows the changelog for every
version; it is generated from the same source as the GitHub release notes, so the
two always match.

---

## Languages

The interface ships in six languages, kept in lockstep:

English · Deutsch · Español · Français · Italiano · Türkçe

---

## Building from source

Only needed to develop the application — to use it, take an archive from the
[releases page](https://github.com/kartalbas/flutter-gitui/releases).

### Prerequisites

1. **Flutter SDK** 3.44.4 (the version CI builds with; the Dart constraint is
   `^3.9.2`)
2. **Git** 2.0 or newer
3. **Windows:** Visual Studio with the "Desktop development with C++" workload
4. **Linux:** `clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev libnotify-dev`

### Build

```bash
git clone https://github.com/kartalbas/flutter-gitui.git
cd flutter-gitui
flutter pub get

# Run
flutter run -d windows   # or: linux, macos

# Release build
flutter build windows --release
flutter build linux --release
```

---

## Development

### Architecture

```
┌───────────────────────────────────────────────┐
│                 Flutter UI                     │
│   Material 3 · Base* component layer · go_router
└───────────────────────┬────────────────────────┘
                        │
┌───────────────────────┴────────────────────────┐
│                 State (Riverpod)                │
│   providers for repositories, status, history…  │
└───────────────────────┬────────────────────────┘
                        │
┌───────────────────────┴────────────────────────┐
│              Git service layer                  │
│      runs the Git CLI as a subprocess           │
└───────────────────────┬────────────────────────┘
                        │
┌───────────────────────┴────────────────────────┐
│              Git CLI (your install)             │
└─────────────────────────────────────────────────┘
```

Notable conventions:

- **State** is [Riverpod](https://riverpod.dev); the UI reads providers and never
  touches git directly.
- **UI** is built from an in-house `Base*` component layer (buttons, dialogs,
  labels, …) on top of Material 3, so styling and behaviour stay consistent. A
  bundled **custom_lint** plugin enforces that layer — raw Material widgets,
  hardcoded colours and hardcoded spacing fail analysis.
- **Localization** uses Flutter's ARB pipeline. All six locales are kept in
  lockstep; new strings must be added to every `lib/l10n/app_*.arb` and the
  generated code refreshed with `flutter gen-l10n`.
- **Only the active repository is watched live** for file-system changes, so a
  workspace with many repositories does not run a watcher per repository.

### CI gates

Every push must pass the same checks CI runs, or the build fails:

```bash
dart format lib test          # formatting
flutter analyze lib test      # static analysis
flutter test                  # unit/widget tests
dart run custom_lint          # the project's own lint rules
```

### Releases

Versioning is tag-based (`v<major>.<minor>.<patch>`). Pushing a `v*.*.*` tag runs
the release workflow, which builds the Windows and Linux archives, generates the
changelog from the git history, attaches the update manifests, and creates the
GitHub release.

---

## Contributing

1. Fork the repository.
2. Make your change with a clear, focused commit using
   [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`,
   `docs:`, …).
3. Make sure the CI gates above all pass locally.
4. Open a pull request describing the change and why.

Bugs and ideas are tracked as [GitHub issues](https://github.com/kartalbas/flutter-gitui/issues).

---

## License

Elastic License 2.0 (ELv2) — free for personal use. See [LICENSE](LICENSE) for the
full terms.

---

## Contact

- **GitHub:** [github.com/kartalbas/flutter-gitui](https://github.com/kartalbas/flutter-gitui)
- **Issues:** [github.com/kartalbas/flutter-gitui/issues](https://github.com/kartalbas/flutter-gitui/issues)

---

Built with Flutter.
