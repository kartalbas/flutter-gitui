#!/usr/bin/env pwsh
# ============================================================================
# Icon Conversion Script
# ============================================================================
# Converts SVG icon to ICO format using ImageMagick
# Requires: ImageMagick (magick command)
# ============================================================================

param(
    [Parameter(Mandatory=$false)]
    [string]$SvgPath = $null
)

$scriptDir = $PSScriptRoot
$projectRoot = Split-Path -Parent $scriptDir
$iconsDir = Join-Path $projectRoot "assets/icons"

if (-not $SvgPath) {
    $SvgPath = Join-Path $iconsDir "app_icon.svg"
}

$icoPath = [System.IO.Path]::ChangeExtension($SvgPath, ".ico")

Write-Host "Converting icon..." -ForegroundColor Yellow
Write-Host "  Source: $SvgPath" -ForegroundColor Gray
Write-Host "  Output: $icoPath" -ForegroundColor Gray

# Check ImageMagick
if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] ImageMagick not found. Install from https://imagemagick.org/" -ForegroundColor Red
    exit 1
}

# Check source exists
if (-not (Test-Path $SvgPath)) {
    Write-Host "[ERROR] SVG not found: $SvgPath" -ForegroundColor Red
    exit 1
}

# Convert SVG to ICO with multiple sizes
try {
    magick $SvgPath -define icon:auto-resize=256,128,64,48,32,16 $icoPath
    Write-Host "[OK] Created: $icoPath" -ForegroundColor Green

    # Copy to Windows runner
    $windowsIconPath = Join-Path $projectRoot "windows/runner/resources/app_icon.ico"
    Copy-Item $icoPath $windowsIconPath -Force
    Write-Host "[OK] Copied to: $windowsIconPath" -ForegroundColor Green

} catch {
    Write-Host "[ERROR] Conversion failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Icon conversion complete!" -ForegroundColor Green
