# Flutter GitUI

> Modern, cross-platform Git GUI built with Flutter

![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.44.4-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.9.2+-0175C2?logo=dart)
![License](https://img.shields.io/badge/license-ELv2-blue)
![Status](https://img.shields.io/badge/status-0.5.0--alpha-orange)

---

## Download

Get the latest build from the [releases page](https://github.com/kartalbas/flutter-gitui/releases).

| Platform | File | How to start |
|----------|------|--------------|
| Windows | `flutter-gitui-v<version>-windows.zip` | Extract, run `flutter_gitui.exe` |
| Linux | `flutter-gitui-v<version>-linux.tar.gz` | Extract, run `./flutter_gitui` (optionally `./install-desktop-entry.sh` first) |

Both archives are flat — their contents land directly in the target directory rather than in a wrapping folder. Each release also carries a `latest-<platform>.json` manifest holding the SHA-256 of the archive it names; the in-app update check verifies that digest before installing anything.

The Linux archive additionally carries `install-desktop-entry.sh`. Running it once — no root, nothing written outside your own `~/.local/share` — creates a desktop entry with the absolute path of the extracted directory baked into it and installs the application icon into the user icon theme, so Flutter GitUI appears in the application menu with its icon; `./install-desktop-entry.sh --uninstall` removes both again. That path is recorded absolutely, so re-run the script if you move the directory. Skipping the script costs nothing else: `./flutter_gitui` still starts the application, it simply stays absent from the menu and shows a generic icon in file managers.

### Requirements

- **A git executable.** This application drives the Git CLI and does not bundle one. On first start it opens Settings and names exactly which settings are missing, with one-click detection for git, diff tools and editors.
- **Linux:** glibc 2.35 or newer — Ubuntu 22.04+, Debian 12+, or anything more recent. The build is pinned to that floor and CI fails if a toolchain change raises it.
- **Windows:** nothing beyond the archive. The Microsoft C++ runtime ships inside it.

---

## Project Status

**This project is in active development.** The current release is an alpha.

| Platform | Status |
|----------|--------|
| Windows | Built and published. Primary development platform. |
| Linux | Built and published. |
| macOS | Builds on every commit, but not published: the app is signed ad-hoc without a hardened runtime, so Gatekeeper refuses to open it. Publishing waits on a Developer ID certificate and notarisation. |

Known limitations of the current alpha are listed in the release notes.

---

## What Is This?

A modern, cross-platform Git GUI that:
- Runs on **Windows and Linux** (macOS builds, but see the status table above)
- Uses **Material Design 3** for a consistent UI
- Features a **command palette** for quick access to all Git operations
- Integrates with **external diff/merge tools** (VS Code, Beyond Compare, etc.)

---

## Key Features

### Command Palette (Ctrl+K)
Universal search for all Git operations:

```
Press Ctrl+K, then type:

"commit"   → Commit Changes, Amend, Squash
"pull"     → Pull (Merge/Rebase/Fast-forward)
"branch"   → Create, Delete, Rename, Merge, Rebase
"bisect"   → Start, Mark Good/Bad, Skip, Stop
```

### Modern Navigation
- **Navigation Rail** - Quick context switching (Dashboard, Changes, History, Branches, Remotes)
- **Contextual Actions** - Right-click menus and hover actions
- **Quick Action Bar** - Most common operations always visible

### Complete Git Support
- All basic operations (commit, pull, push, fetch, merge, rebase)
- Advanced operations (bisect, reflog, cherry-pick, worktree, submodules)
- Works with any Git version (uses Git CLI)

### External Tool Integration
- **15+ diff/merge tools** (VS Code, Beyond Compare, KDiff3, WinMerge, Meld, etc.)
- Auto-detection of installed tools
- Launch with one click

---

## Building From Source

Only needed to develop the application — to use it, take an archive from the [releases page](https://github.com/kartalbas/flutter-gitui/releases).

### Prerequisites

1. **Flutter SDK** 3.44.4 (the version CI builds with; the Dart constraint is `^3.9.2`)
2. **Git** 2.0 or higher
3. **Windows:** Visual Studio with the "Desktop development with C++" workload
4. **Linux:** `clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev libnotify-dev`

### Build

```bash
git clone https://github.com/kartalbas/flutter-gitui.git
cd flutter-gitui
flutter pub get

# Run
flutter run -d windows   # or linux, macos

# Release build
flutter build windows --release
flutter build linux --release
```

---

## Architecture

```
┌─────────────────────────────────────────────┐
│           Flutter UI Layer                  │
│  (Material Design 3, Riverpod State Mgmt)   │
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────┴───────────────────────────┐
│         Git Service Layer                   │
│    (process_run wrapper for Git CLI)        │
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────┴───────────────────────────┐
│            Git CLI (system)                 │
│  (User's installed Git with all features)   │
└─────────────────────────────────────────────┘
```

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make changes and test: `flutter test`
4. Match the gates CI enforces, or the build fails:
   ```bash
   dart format lib test
   flutter analyze lib test
   flutter test
   ```
5. Commit with conventional commits: `git commit -m "feat: add feature"`
6. Push and create PR

---

## License

Elastic License 2.0 (ELv2) - Free for personal use. See [LICENSE](LICENSE) for details.

---

## Contact

- **GitHub:** [github.com/kartalbas/flutter-gitui](https://github.com/kartalbas/flutter-gitui)
- **Email:** kartalbas@gmail.com

---

**Built with Flutter**
