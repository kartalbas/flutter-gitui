# Flutter GitUI Updater

A dedicated standalone executable for safely updating Flutter GitUI while the main application is running.

## Why a Separate Updater?

Windows and other operating systems prevent overwriting executables that are currently running. The updater solves this by:

1. Running as a separate process
2. Waiting for the main app to fully exit
3. Extracting the update and overwriting old files
4. Restarting the application

## How It Works

### Workflow

```
Main App → Download Update → Launch Updater → Exit Main App
                                    ↓
                            Wait for Exit
                                    ↓
                            Extract Update
                                    ↓
                            Overwrite Files
                                    ↓
                            Restart App
```

### Command Line Usage

```bash
updater.exe <zip_path> <app_exe_path> <pid>
```

**Arguments:**
- `zip_path` - Path to the downloaded update zip file
- `app_exe_path` - Path to the application executable to restart
- `pid` - Process ID of the main app (to wait for it to exit)

**Example:**
```bash
updater.exe "C:\Temp\flutter-gitui-v0.72.0+1.zip" "D:\bin\flutter-gitui\flutter_gitui.exe" 12345
```

### Update Process Steps

1. **Verify Files** - Checks that the zip and app executable exist
2. **Wait for App Exit** - Monitors the process ID until the main app closes (30s timeout)
3. **Extract Update** - Unzips the new version to the installation directory
4. **Clean Up** - Removes the temporary zip file
5. **Restart App** - Launches the updated application

## Building the Updater

### Windows

```powershell
cd tools/updater
dart pub get
dart compile exe updater.dart -o updater.exe
```

### Linux

```bash
cd tools/updater
dart pub get
dart compile exe updater.dart -o updater
chmod +x updater
```

## Integration with Build Script

The updater is automatically compiled during the release build process:

### Windows (build-release-universal.ps1)

```powershell
# Compile updater executable
Push-Location "tools/updater"
dart pub get
dart compile exe updater.dart -o updater.exe
Pop-Location

# Copy to release
Copy-Item "tools/updater/updater.exe" "release/universal/windows/" -Force
```

The compiled `updater.exe` is included in the release zip alongside the main executable.

## Fallback Mechanism

If `updater.exe` is not found, the update service falls back to a batch script approach:

**Windows:** Creates `_update.bat` with:
- 3-second wait
- PowerShell Expand-Archive
- File cleanup
- App restart

**Linux:** Creates `_update.sh` with:
- 3-second wait
- unzip extraction
- Permission fixes
- File cleanup
- App restart

## Error Handling

The updater includes comprehensive error handling:

- **Missing Files:** Exits with error if zip or exe not found
- **Process Timeout:** Fails if app doesn't exit within 30 seconds
- **Extraction Errors:** Displays error message and waits for user input
- **Detailed Logging:** Shows progress at each step for debugging

### Example Error Output

```
=========================================
Flutter GitUI Updater
=========================================

Zip file: C:\Temp\update.zip
App path: D:\bin\flutter-gitui\flutter_gitui.exe
App PID:  12345

[1/5] Verifying files...
      ✓ Files verified

[2/5] Waiting for application to close...
      ✓ Application closed

[3/5] Extracting update...

ERROR: Update failed!

Error details:
Exception: Failed to extract archive

Press any key to exit...
```

## Testing the Updater

### Manual Test (Windows)

1. Build the updater:
   ```powershell
   cd tools/updater
   dart pub get
   dart compile exe updater.dart -o updater.exe
   ```

2. Create a test zip of the current build
3. Get the Flutter GitUI process ID: `Get-Process flutter_gitui | Select-Object -ExpandProperty Id`
4. Run the updater:
   ```powershell
   .\updater.exe "path\to\test.zip" "D:\bin\flutter-gitui\flutter_gitui.exe" 12345
   ```

### Integration Test

1. Lower the version in `pubspec.yaml` (e.g., to 0.1.0+1)
2. Build and run the app
3. Wait for update notification
4. Click "Download & Install"
5. Observe:
   - Download progress
   - App exits
   - Updater window appears (if not silent)
   - Update extracts
   - App restarts with new version

## Dependencies

### Dart Packages

- **archive** (^3.6.1) - For extracting zip files
- **path** (^1.9.0) - For cross-platform path handling

### System Requirements

- **Windows:** PowerShell (for fallback), CMD
- **Linux:** bash, unzip, chmod
- **Dart SDK:** ^3.5.0

## Security Considerations

1. **Process ID Verification:** Waits for specific PID to exit (prevents race conditions)
2. **Path Validation:** Checks file existence before proceeding
3. **Timeout Protection:** 30-second limit prevents infinite waiting
4. **Error Recovery:** Safe failure modes with user notification

## Troubleshooting

### Updater Not Found

**Problem:** App uses fallback batch script instead of updater.exe

**Solution:**
- Rebuild the release: `.\build-release-universal.ps1`
- Verify `updater.exe` exists in installation directory
- Check build logs for updater compilation errors

### Update Fails Silently

**Problem:** App exits but doesn't update

**Solution:**
- Check for `_update.bat` or `_update.sh` still running
- Look for error windows that might be hidden
- Check temp directory for leftover zip files
- Run updater manually with verbose output

### Permission Denied

**Problem:** Cannot overwrite files during update

**Solution:**
- Close all instances of Flutter GitUI
- Run app as administrator (Windows)
- Check file/directory permissions
- Ensure no antivirus is blocking file writes

### App Doesn't Restart

**Problem:** Update completes but app doesn't relaunch

**Solution:**
- Check Windows Event Viewer for app launch errors
- Verify executable path is correct
- Try manual restart
- Check for missing DLL dependencies

## Future Enhancements

- Silent update option (no console window)
- Delta updates (only changed files)
- Rollback capability
- Update verification (checksum validation)
- Progress reporting back to main app
- Automatic retry on failure
