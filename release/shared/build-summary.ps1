#!/usr/bin/env pwsh
# ============================================================================
# Build Summary Module
# ============================================================================
# Validates build completion and displays build summary
# BUILD-STEP: 12
# ============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,

    [Parameter(Mandatory=$true)]
    [string]$Commit,

    [Parameter(Mandatory=$true)]
    [string]$ArchiveName,

    [Parameter(Mandatory=$true)]
    [string]$ReleaseDir,

    [Parameter(Mandatory=$true)]
    [bool]$LinuxBuilt
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "Validating build artifacts..." -ForegroundColor Gray

# Validate all critical data is available
if (-not $Version -or -not $Commit -or -not $ArchiveName) {
    throw "Missing critical build information (version: $Version, commit: $Commit, archive: $ArchiveName)"
}

# Archive is in parent of platform-specific release dir
$artifactsParent = Split-Path -Parent $ReleaseDir
$archivePath = Join-Path $artifactsParent $ArchiveName
if (-not (Test-Path $archivePath)) {
    throw "Archive file does not exist at expected location: $archivePath"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Build Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Version:        " -NoNewline; Write-Host $Version -ForegroundColor Green
Write-Host "Commit:         " -NoNewline; Write-Host $Commit -ForegroundColor Green
Write-Host "Platforms:      " -NoNewline; Write-Host $(if ($LinuxBuilt) { "Windows + Linux" } else { "Windows" }) -ForegroundColor Green
Write-Host "Archive:        " -NoNewline; Write-Host $archivePath -ForegroundColor Cyan
Write-Host ""

return @{
    Success = $true
    Message = "Build summary validated"
}
