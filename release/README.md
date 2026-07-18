# Flutter GitUI - Release Build System

This directory contains the complete build system for creating platform-specific Flutter GitUI releases for Windows, Linux, and macOS (future).

## Quick Start

### Windows Build
```powershell
cd release/windows
.\windows-release.ps1
```

### Linux Build (Docker-based)
```powershell
cd release/linux
.\linux-release.ps1
```

### macOS Build (Not Yet Implemented)
```bash
cd release/macos
./macos-release.sh  # Will show "not supported" message
```

## Directory Structure

```
release/
├── windows/                        # Windows-specific build
│   ├── windows-release.ps1         # Windows build orchestrator
│   └── build-windows.ps1           # Windows Flutter build module
├── linux/                          # Linux-specific build
│   ├── linux-release.ps1           # Linux build orchestrator
│   └── build-linux.ps1             # Linux Docker build module
├── macos/                          # macOS placeholder (future)
│   ├── macos-release.sh            # Placeholder script
│   └── README.md                   # macOS implementation guide
├── shared/                         # Cross-platform modules
│   ├── version-manager.ps1         # Version detection and bumping
│   ├── sync-icons.ps1              # Icon synchronization
│   ├── changelog-generator.ps1     # AI-powered changelog
│   ├── build-prep.ps1              # Build environment preparation
│   ├── generate-docs.ps1           # README/PDF generation
│   ├── create-archive.ps1          # ZIP and manifest creation
│   ├── upload-to-azure-rest.ps1    # Azure Blob Storage upload
│   ├── update-winget-manifest.ps1  # Winget package manifest generation
│   ├── build-summary.ps1           # Build validation
│   └── git-commit.ps1              # Git commit and push
├── docker/                         # Docker build configuration
│   ├── Dockerfile.linux-base       # Base image with Flutter SDK
│   └── Dockerfile.linux-build      # Build image for Linux binaries
├── updater/                        # Standalone updater application
│   ├── updater.dart                # Updater logic
│   └── pubspec.yaml                # Updater dependencies
├── artifacts/                      # Build outputs (git-ignored)
│   ├── windows/                    # Windows release artifacts
│   ├── linux/                      # Linux release artifacts
│   └── macos/                      # macOS release artifacts (future)
└── README.md                       # This file
```

## Build Process

### Windows Build Process (11 Steps)

1. **Version Management** - Gets version from git tags
2. **Icon Sync** - Syncs app icons from central location
3. **Changelog Generation** - Generates AI-powered changelog using Claude API
4. **Build Preparation** - Cleans previous builds, creates artifact folders
5. **Windows Build** - Builds Windows binaries with Flutter
6. **Documentation** - Generates README.md (and optional PDF)
7. **Create Archive** - Creates platform-specific ZIP and manifest
8. **Winget Manifest** - Updates winget package manifest with SHA256
9. **Azure Upload** - Uploads to Azure Blob Storage (optional)
10. **Build Summary** - Validates build and displays summary
11. **Git Commit** - Commits version changes to repository

### Linux Build Process (11 Steps)

1. **Version Management** - Gets version from git tags
2. **Icon Sync**
3. **Changelog Generation**
4. **Docker Check** - Verifies Docker and Dockerfiles exist
5. **Build Preparation**
6. **Linux Build** - Builds Linux binaries in Docker container
7. **Documentation**
8. **Create Archive**
9. **Azure Upload** (optional)
10. **Build Summary**
11. **Git Commit**

## Shared Modules

All shared modules are cross-platform PowerShell scripts that work on Windows, Linux (via PowerShell Core), and macOS (future).

### version-manager.ps1
Gets version from git tags. Tag format: `v{major}.{minor}.{patch}` (e.g., `v0.1.0`).
Version is used directly from the tag without build numbers.

**Parameters:**
- `PubspecPath` - Path to pubspec.yaml

**Returns:**
- NewVersion, BaseVersion, BuildNumber, Tag, CommitShort, Success

### sync-icons.ps1
Synchronizes application icons from the central location to all required platform locations (Windows runner, Linux, macOS).

**No parameters**

### changelog-generator.ps1
Generates changelog by analyzing git commits. Can use Claude API for AI-powered changelog generation or fall back to simple bullet list.

**Parameters:**
- `ProjectRoot` - Project root directory

**Returns:**
- ChangelogMarkdown, Success

**Configuration:**
- Set `ANTHROPIC_API_KEY` environment variable or in `.env` file for AI-powered changelogs

### build-prep.ps1
Prepares the build environment by cleaning previous builds, creating platform-specific artifact folders, and resolving Flutter dependencies.

**Parameters:**
- `ProjectRoot` - Project root directory
- `ReleaseDir` - Platform-specific artifacts directory
- `Platform` - Target platform (windows/linux/macos)

**Returns:**
- Success, Message

### generate-docs.ps1
Generates comprehensive README.md documentation for the release, including version info, changelog, and platform-specific instructions. Optionally generates PDF if pandoc is installed.

**Parameters:**
- `ReleaseDir` - Platform-specific artifacts directory
- `Version` - Release version
- `CommitShort` - Short commit hash
- `ChangelogContent` - Markdown changelog
- `BuildInfo` - Hashtable with build metrics
- `Platform` - Target platform

**Returns:**
- Success, ReadmePath, PdfPath (optional)

### create-archive.ps1
Creates platform-specific ZIP archive and JSON manifest for auto-update feature.

**Parameters:**
- `ReleaseDir` - Platform-specific artifacts directory
- `Version` - Release version
- `ChangelogContent` - Markdown changelog
- `Platform` - Target platform

**Returns:**
- Success, Archive (FileName, FilePath, SizeMB, SizeBytes), Manifest

**Output:**
- `release/artifacts/flutter-gitui-v{version}-{platform}.zip`
- `release/artifacts/latest-{platform}.json`

### upload-to-azure-rest.ps1
Uploads release archive and manifest to Azure Blob Storage using REST API.

**Parameters:**
- `FilePath` - File to upload (optional, auto-detects if not specified)

**Configuration:**
- Set `FLUTTERGITUIARTIFACTS_CONNECTION_STRING` in `.env` file

**Container:** `releases`

### update-winget-manifest.ps1
Updates winget package manifest files with correct SHA256 hash after archive creation.

**Parameters:**
- `ArchivePath` - Path to the release archive
- `Version` - Release version
- `WingetPkgsPath` - Optional path to winget-pkgs repo (auto-detects if not specified)
- `Platform` - Target platform (windows/linux/macos)
- `DownloadUrlBase` - Base URL for downloads (default: Azure blob storage)

**Output:**
- `manifests/f/FlutterGitUI/FlutterGitUI/{version}/FlutterGitUI.yaml`
- `manifests/f/FlutterGitUI/FlutterGitUI/{version}/FlutterGitUI.installer.yaml`
- `manifests/f/FlutterGitUI/FlutterGitUI/{version}/FlutterGitUI.locale.en-US.yaml`

**Returns:**
- Success, SHA256, ManifestDir

### build-summary.ps1
Validates the build by checking that all critical artifacts exist and displays a summary.

**Parameters:**
- `Version` - Release version
- `Commit` - Short commit hash
- `ArchiveInfo` - Archive metadata

**Returns:**
- Success

### git-commit.ps1
Commits version changes to the repository with a conventional commit message.

**Parameters:**
- `ProjectRoot` - Project root directory
- `Version` - Release version

**Returns:**
- Success, Message

## Platform-Specific Modules

### Windows: build-windows.ps1

Builds Windows binaries using Flutter and compiles the updater.

**Parameters:**
- `ProjectRoot` - Project root directory
- `ReleaseDir` - Windows artifacts directory
- `UpdaterDir` - Updater source directory
- `Version` - Release version
- `LogFile` - Build log file path

**Returns:**
- Success, BuildTime, SizeMB

### Linux: build-linux.ps1

Builds Linux binaries in a Docker container.

**Parameters:**
- `ProjectRoot` - Project root directory
- `ReleaseDir` - Linux artifacts directory
- `DockerDir` - Docker configuration directory
- `Version` - Release version
- `LogFile` - Build log file path
- `CheckOnly` - Only check prerequisites (switch)

**Returns:**
- Success, BuildTime, SizeMB, Ready (check mode)

## Configuration

### .env File

Create a `.env` file in the project root with the following optional variables:

```env
# Azure Blob Storage (for release uploads)
FLUTTERGITUIARTIFACTS_CONNECTION_STRING=DefaultEndpointsProtocol=https;AccountName=...;AccountKey=...

# Anthropic Claude API (for AI-powered changelogs)
ANTHROPIC_API_KEY=sk-ant-...
```

### Build Parameters

All platform-specific build scripts support:

**`-SkipAzureUpload`** - Skip uploading to Azure Blob Storage

Example:
```powershell
.\windows-release.ps1 -SkipAzureUpload
```

## Requirements

### Windows Build Requirements
- Windows 10/11
- Flutter SDK (configured for Windows desktop)
- Visual Studio 2019 or later with C++ tools
- PowerShell 5.1 or PowerShell Core 7+
- Git

**Optional (for PDF generation in releases):**
- Pandoc: `scoop install pandoc` or download from https://pandoc.org/
- LaTeX (MiKTeX): `scoop install latex` or download from https://miktex.org/
  - Alternative: `winget install -e --id MiKTeX.MiKTeX`

### Linux Build Requirements
- Windows 10/11 (with WSL2) or Linux
- Docker Desktop (Windows) or Docker (Linux)
- PowerShell Core 7+
- Git
- Flutter SDK (for development, not required for Docker build)

**Note:** PDF generation tools (pandoc, LaTeX) are pre-installed in the Docker build image.

### macOS Build Requirements (Future)
- macOS 10.15 or later
- Xcode Command Line Tools
- Flutter SDK (configured for macOS desktop)
- PowerShell Core 7+
- Git

**Optional (for PDF generation in releases):**
- Pandoc: `brew install pandoc`
- LaTeX (MacTeX): `brew install --cask mactex-no-gui`
  - Lightweight alternative: `brew install basictex`

## Troubleshooting

### Windows Build Issues

**"Visual Studio not found"**
- Install Visual Studio 2019 or later
- Install "Desktop development with C++" workload

**"Plugin symlinks error"**
- The build script automatically handles plugin symlink issues
- If problems persist, manually delete `windows/flutter/ephemeral/.plugin_symlinks`

**"Flutter build failed"**
- Check build log at `build_windows.log`
- Run `flutter doctor` to check Flutter installation
- Ensure all dependencies are installed: `flutter pub get`

### Linux Build Issues

**"Docker not found"**
- Install Docker Desktop (Windows) or Docker (Linux)
- Ensure Docker daemon is running
- Check Docker version: `docker --version`

**"Docker build failed"**
- Check Docker build context
- Ensure Dockerfiles exist in `release/docker/`
- Check available disk space
- Review build log at `build_linux.log`

**"Base image build takes too long"**
- Base image build is one-time (cached after first build)
- Usually takes 2-3 minutes on first run
- Subsequent builds use cached image

### General Issues

**"Version detection failed"**
- Ensure git repository is valid
- Check that `pubspec.yaml` exists and has valid version
- Verify git commits follow conventional commit format

**"Changelog generation failed"**
- Claude API key is optional (falls back to simple changelog)
- Check `.env` file for `ANTHROPIC_API_KEY` if using AI generation
- Verify internet connection if using Claude API

**"Azure upload failed"**
- Azure upload is optional (use `-SkipAzureUpload` to skip)
- Check connection string in `.env` file
- Verify network connectivity
- Check Azure storage account permissions

### PDF Generation Issues

**"PDF generation skipped - pandoc not installed"**

*Windows:*
```powershell
# Using Scoop (recommended)
scoop install pandoc

# Or using Winget
winget install -e --id JohnMacFarlane.Pandoc
```

*Linux:*
```bash
# Ubuntu/Debian
sudo apt-get install pandoc

# Fedora/RHEL
sudo dnf install pandoc

# Arch
sudo pacman -S pandoc
```

*macOS:*
```bash
brew install pandoc
```

**"PDF generation skipped - no PDF engine available"**

This means pandoc is installed but LaTeX is missing.

*Windows:*
```powershell
# Using Scoop (recommended - lightweight MiKTeX)
scoop install latex

# Or using Winget (full MiKTeX)
winget install -e --id MiKTeX.MiKTeX

# After installation, restart your terminal or refresh PATH
```

*Linux:*
```bash
# Ubuntu/Debian
sudo apt-get install texlive-latex-base texlive-xetex texlive-fonts-recommended

# Fedora/RHEL
sudo dnf install texlive-scheme-basic texlive-xetex

# Arch
sudo pacman -S texlive-core texlive-latexextra
```

*macOS:*
```bash
# Lightweight (recommended)
brew install basictex

# Full distribution
brew install --cask mactex-no-gui
```

**"xelatex not found" (Windows)**

LaTeX tools may not be in your PATH yet. Solutions:
1. Restart your terminal/PowerShell
2. The build script will auto-detect common installation paths
3. Or add to PATH manually:
   ```powershell
   # For Scoop installation
   $env:PATH += ";D:\bin\scoop\apps\latex\current\texmfs\install\miktex\bin\x64"

   # For standard MiKTeX installation
   $env:PATH += ";$env:LOCALAPPDATA\Programs\MiKTeX\miktex\bin\x64"
   ```

**Note:** PDF generation is optional. Builds will succeed without it, but the release ZIP will not include README.pdf.

## Migration from universal-build

If you're migrating from the old `universal-build/` structure:

1. The old `universal-build/` folder remains intact for reference
2. New builds use the `release/` structure
3. Key differences:
   - Platform-specific orchestrators instead of single universal script
   - Shared modules in `release/shared/` instead of `lib/`
   - Platform-specific artifacts in `release/artifacts/{platform}/`
   - Updater in `release/updater/`

## Development

### Adding a New Shared Module

1. Create PowerShell script in `release/shared/`
2. Add proper parameter validation
3. Return hashtable with Success flag
4. Handle errors gracefully
5. Add to build orchestrators where needed
6. Document in this README

### Modifying Build Process

1. Edit platform-specific orchestrator (`{platform}-release.ps1`)
2. Update step numbers if adding/removing steps
3. Test thoroughly on target platform
4. Update documentation

### Testing

Before committing changes:
- Test Windows build on Windows
- Test Linux build on Docker
- Verify all artifacts are created correctly
- Check that uploads work (if configured)
- Verify git commits are created properly

## License

Flutter GitUI is open source software. See the LICENSE file for details.

## Contact

For issues, questions, or contributions:
- GitHub: https://github.com/your-repo/flutter-gitui
- Email: kartalbas@gmail.com
