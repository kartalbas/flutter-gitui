# macOS Release Build (Future Support)

## Status: Not Yet Implemented

This directory contains placeholder infrastructure for future macOS build support. Currently, the project is developed and tested on Windows and Linux platforms only.

## Why Not Implemented?

- **Hardware Access**: Requires macOS hardware for testing
- **App Signing**: Requires Apple Developer account for code signing
- **Testing**: Need to verify Flutter build process on macOS
- **Distribution**: Need to package as .app bundle or DMG

## Planned Implementation

When macOS support is added, this directory will contain:

### Files to be Created

- `macos-release.sh` - Main build orchestration script (bash)
- `build-macos.sh` - macOS-specific Flutter build script
- `../docker/macos/` - Cross-compilation Docker setup (optional)

### Build Process

The macOS build script will follow the same pattern as Windows and Linux:

1. **Version Management** (shared)
2. **Icon Sync** (shared)
3. **Changelog Generation** (shared)
4. **Build Preparation** (shared with platform=macos)
5. **macOS Build** (platform-specific)
   - Run `flutter build macos --release`
   - Create .app bundle structure
6. **Generate Documentation** (shared with platform=macos)
7. **Create Archive** (shared with platform=macos)
   - Package as DMG or zip
   - Include README and changelog
8. **Azure Upload** (shared, optional)
9. **Build Summary** (shared)
10. **Git Commit** (shared)

### Technical Requirements

#### Code Signing

macOS builds require code signing for distribution:
```bash
codesign --force --deep --sign "Developer ID Application: Name" FlutterGitUI.app
```

#### Notarization

For distribution outside the App Store:
```bash
xcrun altool --notarize-app --file FlutterGitUI.dmg \
  --primary-bundle-id com.flutter.gitui \
  --username "email" --password "@keychain:AC_PASSWORD"
```

### Shared Modules Compatibility

All shared modules are designed to work cross-platform:
- ✅ `version-manager.ps1` - Works on PowerShell Core (macOS)
- ✅ `sync-icons.ps1` - Path handling compatible
- ✅ `changelog-generator.ps1` - Cross-platform
- ✅ `build-prep.ps1` - Platform parameter supports macOS
- ✅ `generate-docs.ps1` - Platform parameter supports macOS
- ✅ `create-archive.ps1` - Platform parameter supports macOS
- ✅ `upload-to-azure-rest.ps1` - Cross-platform REST API
- ✅ `build-summary.ps1` - Cross-platform
- ✅ `git-commit.ps1` - Cross-platform

### How to Add macOS Support

1. **Install Prerequisites**
   ```bash
   # Install Flutter for macOS
   flutter doctor

   # Install PowerShell Core
   brew install powershell/tap/powershell

   # Install Xcode Command Line Tools
   xcode-select --install
   ```

2. **Test Flutter Build**
   ```bash
   cd /path/to/flutter-gitui
   flutter build macos --release
   # Verify build output in build/macos/Build/Products/Release/
   ```

3. **Adapt Build Script**
   - Copy `macos-release.sh` structure from Linux version
   - Update paths for macOS conventions
   - Test each build step individually

5. **Test Complete Process**
   ```bash
   cd release/macos
   ./macos-release.sh
   ```

6. **Update Documentation**
   - Update main `release/README.md`
   - Add macOS-specific instructions
   - Document any macOS-specific quirks

## Contact

If you have access to macOS and want to contribute:
- Open an issue on GitHub
- Discuss implementation details
- Submit pull request with macOS support

## References

- [Flutter Desktop: macOS](https://docs.flutter.dev/platform-integration/macos/building)
- [Apple Code Signing](https://developer.apple.com/support/code-signing/)
- [Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
