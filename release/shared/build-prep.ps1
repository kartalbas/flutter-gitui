#!/usr/bin/env pwsh
# ============================================================================
# Build Preparation Module
# ============================================================================
# Handles cleaning previous builds, creating release structure, and
# managing Flutter dependencies with proper plugin symlink handling
# BUILD-STEP: 4
# ============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectRoot,

    [Parameter(Mandatory=$true)]
    [string]$ReleaseDir,

    [Parameter(Mandatory=$false)]
    [ValidateSet('windows', 'linux', 'macos')]
    [string]$Platform = 'windows'
)

function Clear-PreviousBuilds {
    param([string]$ProjectRoot)

    Write-Host "  Cleaning previous builds..." -ForegroundColor Gray

    $buildPath = Join-Path $ProjectRoot "build"

    if (Test-Path $buildPath) {
        Remove-Item -Recurse -Force $buildPath -ErrorAction SilentlyContinue
    }

    Push-Location $ProjectRoot
    flutter config --enable-windows-desktop 2>&1 | Out-Null
    flutter clean 2>&1 | Out-Null
    Pop-Location

    Write-Host "  [OK] Clean complete" -ForegroundColor Green
}

function New-ReleaseStructure {
    param(
        [string]$ReleaseDir,
        [string]$Platform
    )

    Write-Host "  Creating release structure..." -ForegroundColor Gray

    if (Test-Path $ReleaseDir) {
        Write-Host "    Removing existing $Platform artifacts folder..." -ForegroundColor Gray
        Remove-Item -Path $ReleaseDir -Recurse -Force
    }

    New-Item -ItemType Directory -Force -Path $ReleaseDir | Out-Null

    Write-Host "  [OK] $Platform artifacts folder created" -ForegroundColor Green
}

function Initialize-FlutterDependencies {
    param([string]$ProjectRoot)

    Write-Host "  Resolving Flutter dependencies..." -ForegroundColor Gray

    Push-Location $ProjectRoot

    # CRITICAL: Remove plugin symlinks directory manually
    # Git Bash can create Unix-style symlinks (/c/Users/...) that Windows CMake can't follow
    # We need to delete the entire directory and let PowerShell's flutter create fresh ones
    $pluginSymlinksPath = "windows/flutter/ephemeral/.plugin_symlinks"
    if (Test-Path $pluginSymlinksPath) {
        Write-Host "    Removing old plugin symlinks directory..." -ForegroundColor Gray
        Remove-Item -Recurse -Force $pluginSymlinksPath -ErrorAction SilentlyContinue
    }

    # Run flutter clean to remove any other stale artifacts
    Write-Host "    Running flutter clean..." -ForegroundColor Gray
    flutter clean 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    [WARN] Flutter clean had warnings (continuing)" -ForegroundColor Yellow
    }

    # Run flutter pub get in PowerShell to create fresh Windows-compatible symlinks
    Write-Host "    Running flutter pub get (creating Windows-compatible symlinks)..." -ForegroundColor Gray
    flutter pub get 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Pop-Location
        throw "Failed to get dependencies!"
    }

    # Brief delay to ensure plugin symlinks are fully committed to filesystem
    Start-Sleep -Milliseconds 500

    # Verify plugin symlinks were created and are valid
    if (Test-Path $pluginSymlinksPath) {
        $symlinkCount = (Get-ChildItem $pluginSymlinksPath -ErrorAction SilentlyContinue).Count
        Write-Host "    Plugin symlinks: $symlinkCount plugins created" -ForegroundColor Gray

        # Show first few symlink targets for verification (should be Windows-style paths)
        Write-Host "    Verifying symlink format..." -ForegroundColor Gray
        $symlinks = Get-ChildItem $pluginSymlinksPath -ErrorAction SilentlyContinue | Select-Object -First 3
        foreach ($symlink in $symlinks) {
            $target = $symlink.Target
            if ($target -match "^/c/") {
                Write-Host "      [WARN] $($symlink.Name) -> $target (Unix-style!)" -ForegroundColor Yellow
            } else {
                Write-Host "      [OK] $($symlink.Name) -> $target" -ForegroundColor Gray
            }
        }
    } else {
        Pop-Location
        throw "Plugin symlinks directory not found after pub get!"
    }

    Pop-Location

    Write-Host "  [OK] Dependencies resolved with fresh symlinks" -ForegroundColor Green
}

# ============================================================================
# Main Execution
# ============================================================================

Write-Host "Preparing build environment..." -ForegroundColor Yellow

try {
    Clear-PreviousBuilds -ProjectRoot $ProjectRoot
    New-ReleaseStructure -ReleaseDir $ReleaseDir -Platform $Platform
    Initialize-FlutterDependencies -ProjectRoot $ProjectRoot

    Write-Host "[OK] Build preparation complete for $Platform" -ForegroundColor Green

    return @{
        Success = $true
        Message = "Build environment ready"
    }

} catch {
    Write-Host "[ERROR] Build preparation failed: $($_.Exception.Message)" -ForegroundColor Red
    return @{
        Success = $false
        Message = $_.Exception.Message
    }
}
