# Flutter GitUI

> Modern, cross-platform Git GUI built with Flutter

![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.9.2+-0175C2?logo=dart)
![License](https://img.shields.io/badge/license-ELv2-blue)
![Status](https://img.shields.io/badge/status-In%20Development-yellow)

---

## ⚠️ Project Status

**This project is in active development.**

| Platform | Status |
|----------|--------|
| Windows  | Primary development platform. Core features working, but not feature-complete. |
| macOS    | Not tested yet. |
| Linux    | Not tested yet. |

---

## What Is This?

A modern, cross-platform Git GUI that:
- Runs on **Windows, macOS, and Linux**
- Uses **Material Design 3** for a beautiful, consistent UI
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

## Quick Start

### Prerequisites

1. **Flutter SDK** 3.24.0 or higher
2. **Git** 2.0 or higher
3. **Platform**: Windows 10+, macOS 10.15+, or Ubuntu 20.04+

### Installation

```bash
# Clone this repository
git clone https://github.com/kartalbas/flutter-gitui.git
cd flutter-gitui

# Get dependencies
flutter pub get

# Run on desktop
flutter run -d windows  # or macos, linux
```

### Build Release

```bash
# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux
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
4. Format code: `dart format .`
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
