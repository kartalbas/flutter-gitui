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
$centralSvg = Join-Path $projectRoot "assets/icons/app_icon.svg"

# Check if central icon exists
if (-not (Test-Path $centralIcon)) {
    Write-Host "[ERROR] Central icon not found: $centralIcon" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $centralSvg)) {
    Write-Host "[ERROR] Central icon source not found: $centralSvg" -ForegroundColor Red
    exit 1
}

if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] ImageMagick (magick) not found; PNG icons cannot be rendered." -ForegroundColor Red
    Write-Host "        Install from https://imagemagick.org/" -ForegroundColor Red
    exit 1
}

$centralFile = Get-Item $centralIcon
$centralSize = $centralFile.Length

Write-Host "Central icon:   $centralIcon" -ForegroundColor Green
Write-Host "Vector source:  $centralSvg" -ForegroundColor Green
Write-Host "Size:           $centralSize bytes" -ForegroundColor Gray
Write-Host ""

# Locations to sync. An entry with RenderSize is rasterised from the SVG at that
# pixel size instead of being copied from an existing bitmap.
$locations = @(
    @{
        Path = Join-Path $projectRoot "windows/runner/resources/app_icon.ico"
        Description = "Flutter Windows app icon"
        Source = $centralIcon
    },
    @{
        Path = Join-Path $projectRoot "linux/app_icon.png"
        Description = "Flutter Linux app icon"
        RenderSize = 512
    }
)

# Every size referenced by AppIcon.appiconset/Contents.json, not just 512.
foreach ($size in @(16, 32, 64, 128, 256, 512, 1024)) {
    $locations += @{
        Path = Join-Path $projectRoot "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$size.png"
        Description = "Flutter macOS app icon ${size}x${size}"
        RenderSize = $size
    }
}

# Renders land outside the tree so a run that changes nothing leaves it clean.
$renderDir = Join-Path ([System.IO.Path]::GetTempPath()) ("gitui-icons-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $renderDir -Force | Out-Null

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

    if ($location.RenderSize) {
        $renderSize = $location.RenderSize
        $sourceFile = Join-Path $renderDir "app_icon_$renderSize.png"
        # Excluding the date/time chunks keeps a re-render of an unchanged SVG
        # byte-identical, so the hash compare below stays stable across runs.
        magick -background none -size "${renderSize}x${renderSize}" $centralSvg -resize "${renderSize}x${renderSize}" -define png:exclude-chunk=date,time $sourceFile
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $sourceFile)) {
            Write-Host "[ERROR]   $description (render failed from $centralSvg)" -ForegroundColor Red
            Remove-Item $renderDir -Recurse -Force -ErrorAction SilentlyContinue
            exit 1
        }
    } else {
        $sourceFile = $location.Source
        if (-not (Test-Path $sourceFile)) {
            Write-Host "[ERROR]   $description (source not found: $sourceFile)" -ForegroundColor Red
            Remove-Item $renderDir -Recurse -Force -ErrorAction SilentlyContinue
            exit 1
        }
    }

    # Staleness is decided by content, never by timestamps: a checkout rewrites
    # the mtime of every file, so on a fresh clone a stale template icon would
    # otherwise look newer than its own source and never be replaced.
    $needsUpdate = $true
    if (Test-Path $targetPath) {
        $sourceHash = (Get-FileHash $sourceFile -Algorithm SHA256).Hash
        $targetHash = (Get-FileHash $targetPath -Algorithm SHA256).Hash
        $needsUpdate = $sourceHash -ne $targetHash
    }

    if ($needsUpdate) {
        Copy-Item $sourceFile $targetPath -Force
        Write-Host "[SYNCED]  $description" -ForegroundColor Green
        Write-Host "          -> $targetPath" -ForegroundColor Gray
        $syncedCount++
    } else {
        Write-Host "[OK]      $description (already up-to-date)" -ForegroundColor DarkGray
        $skippedCount++
    }
}

Remove-Item $renderDir -Recurse -Force -ErrorAction SilentlyContinue

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

# Callers gate the release on $LASTEXITCODE, which PowerShell leaves at the
# previous command's value unless a script exits explicitly.
exit 0
