#!/usr/bin/env pwsh
# ============================================================================
# Winget Manifest Update Module
# ============================================================================
param(
    [Parameter(Mandatory=$true)][string]$Tag,
    [Parameter(Mandatory=$false)][string]$Repository = 'kartalbas/flutter-gitui',
    [Parameter(Mandatory=$false)][string]$WingetPkgsPath = $null,
    [Parameter(Mandatory=$false)][switch]$SkipWinget = $false
)

$scriptDir = $PSScriptRoot
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$templatesDir = Join-Path $projectRoot "release/manifests/winget"

Write-Host "Updating winget manifest..." -ForegroundColor Yellow

try {
    if ($SkipWinget) {
        # Checked before the release is read: a build of a commit that was never
        # released has no release to describe, and skipping is exactly what the
        # caller asked for.
        Write-Host "  [SKIP] Winget manifest update skipped on request" -ForegroundColor Yellow
        return @{ Success = $true; Skipped = $true }
    }

    # The URL and the digest pinned beside it have to describe the same bytes.
    # Hashing a locally built archive cannot achieve that: the local build and
    # the published one are separate files that do not even share a name. Both
    # values therefore come from the manifest the release itself carries.
    $releaseUrl = "https://api.github.com/repos/$Repository/releases/tags/$Tag"
    Write-Host "  Reading release $Tag from $Repository..." -ForegroundColor Gray
    try {
        $release = Invoke-RestMethod -Uri $releaseUrl -Headers @{ Accept = 'application/vnd.github+json' }
    } catch {
        # A draft release is invisible to the unauthenticated API, so this also
        # covers "the draft has not been published yet".
        throw "Release $Tag of $Repository is not published. Publish the draft release before updating the winget manifest."
    }

    $manifestAsset = $release.assets | Where-Object { $_.name -eq 'latest-windows.json' } | Select-Object -First 1
    if (-not $manifestAsset) {
        throw "Release $Tag publishes no latest-windows.json asset."
    }

    $releaseManifest = Invoke-RestMethod -Uri $manifestAsset.browser_download_url
    $archiveName = $releaseManifest.windows.fileName
    $hash = $releaseManifest.windows.sha256
    if (-not $archiveName -or -not $hash) {
        throw "Release manifest of $Tag carries no windows fileName and sha256."
    }
    # winget validates the digest case-insensitively but publishes it upper-case.
    $hash = $hash.ToUpperInvariant()

    $archiveAsset = $release.assets | Where-Object { $_.name -eq $archiveName } | Select-Object -First 1
    if (-not $archiveAsset) {
        throw "Release $Tag publishes no $archiveName asset."
    }
    $downloadUrl = $archiveAsset.browser_download_url

    Write-Host "  Installer: $archiveName" -ForegroundColor Gray
    Write-Host "  SHA256: $hash" -ForegroundColor Gray

    if (-not $WingetPkgsPath) {
        # The checkout location differs per machine, so it is configured rather than guessed.
        $possiblePaths = @($env:WINGET_PKGS_PATH, "$env:USERPROFILE\repos\winget-pkgs")
        foreach ($path in $possiblePaths) {
            if ($path -and (Test-Path $path)) { $WingetPkgsPath = $path; break }
        }
    }

    if (-not $WingetPkgsPath -or -not (Test-Path $WingetPkgsPath)) {
        # Reporting success here would ship a release whose winget users silently stay on the old version.
        throw "Winget-pkgs repo not found. Set WINGET_PKGS_PATH, pass -WingetPkgsPath, or pass -SkipWinget to skip this step."
    }

    $baseVersion = $Tag -replace '^v', ''
    $manifestDir = Join-Path $WingetPkgsPath "manifests\f\FlutterGitUI\FlutterGitUI\$baseVersion"
    if (-not (Test-Path $manifestDir)) { New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null }

    # Process templates from local manifests
    $templateFiles = @(
        "FlutterGitUI.FlutterGitUI.yaml",
        "FlutterGitUI.FlutterGitUI.installer.yaml",
        "FlutterGitUI.FlutterGitUI.locale.en-US.yaml"
    )

    foreach ($templateFile in $templateFiles) {
        $templatePath = Join-Path $templatesDir $templateFile
        $content = Get-Content $templatePath -Raw
        $content = $content -replace '\$\{VERSION\}', $baseVersion
        $content = $content -replace '\$\{DOWNLOAD_URL\}', $downloadUrl
        $content = $content -replace '\$\{SHA256\}', $hash
        $destPath = Join-Path $manifestDir $templateFile
        $content | Set-Content $destPath -Encoding UTF8 -NoNewline
        Write-Host "  [OK] $templateFile" -ForegroundColor Green
    }

    Write-Host "[OK] Winget manifest updated at $manifestDir" -ForegroundColor Green
    return @{ Success = $true; SHA256 = $hash; ManifestDir = $manifestDir }

} catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    return @{ Success = $false; Error = $_.Exception.Message }
}
