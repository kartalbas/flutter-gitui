#!/usr/bin/env pwsh
# ============================================================================
# Icon Sync Module
# ============================================================================
# Sync application icons from central location to all required locations
# BUILD-STEP: 2
# ============================================================================

Write-Host "Syncing icons from central location..." -ForegroundColor Cyan
Write-Host ""

# Path handling
$scriptDir = $PSScriptRoot
$releaseDir = Split-Path -Parent $scriptDir
$projectRoot = Split-Path -Parent $releaseDir

$centralIcon = Join-Path $projectRoot "assets/icons/app_icon.ico"

# Check if central icon exists
if (-not (Test-Path $centralIcon)) {
    Write-Host "[ERROR] Central icon not found: $centralIcon" -ForegroundColor Red
    exit 1
}

$centralFile = Get-Item $centralIcon
$centralSize = $centralFile.Length
$centralDate = $centralFile.LastWriteTime

Write-Host "Central icon:   $centralIcon" -ForegroundColor Green
Write-Host "Size:           $centralSize bytes" -ForegroundColor Gray
Write-Host "Modified:       $centralDate" -ForegroundColor Gray
Write-Host ""

# Locations to sync
$locations = @(
    @{
        Path = Join-Path $projectRoot "windows/runner/resources/app_icon.ico"
        Description = "Flutter Windows app icon"
    },
    @{
        Path = Join-Path $projectRoot "linux/app_icon.png"
        Description = "Flutter Linux app icon"
        SourceOverride = Join-Path $projectRoot "assets/icons/app_icon.png"
    },
    @{
        Path = Join-Path $projectRoot "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png"
        Description = "Flutter macOS app icon"
        SourceOverride = Join-Path $projectRoot "assets/icons/app_icon.png"
    }
)

$syncedCount = 0
$skippedCount = 0

foreach ($location in $locations) {
    $targetPath = $location.Path
    $description = $location.Description

    # Ensure directory exists
    $targetDir = Split-Path -Parent $targetPath
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    # Check if update needed
    $needsUpdate = $true
    if (Test-Path $targetPath) {
        $targetFile = Get-Item $targetPath
        if ($targetFile.Length -eq $centralSize -and $targetFile.LastWriteTime -eq $centralDate) {
            $needsUpdate = $false
        }
    }

    if ($needsUpdate) {
        $sourceFile = if ($location.SourceOverride) { $location.SourceOverride } else { $centralIcon }
        if (Test-Path $sourceFile) {
            Copy-Item $sourceFile $targetPath -Force
            Write-Host "[SYNCED]  $description" -ForegroundColor Green
            Write-Host "          -> $targetPath" -ForegroundColor Gray
            $syncedCount++
        } else {
            Write-Host "[SKIP]    $description (source not found: $sourceFile)" -ForegroundColor Yellow
            $skippedCount++
        }
    } else {
        Write-Host "[OK]      $description (already up-to-date)" -ForegroundColor DarkGray
        $skippedCount++
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Sync Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Synced:    $syncedCount file(s)" -ForegroundColor Green
Write-Host "Skipped:   $skippedCount file(s) (already up-to-date)" -ForegroundColor Gray
Write-Host ""

if ($syncedCount -gt 0) {
    Write-Host "[NOTICE] Icon files updated. Run build to see changes in executables." -ForegroundColor Yellow
} else {
    Write-Host "[OK] All icons are up-to-date!" -ForegroundColor Green
}
