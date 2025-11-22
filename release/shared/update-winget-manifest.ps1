#!/usr/bin/env pwsh
# ============================================================================
# Winget Manifest Update Module
# ============================================================================
param(
    [Parameter(Mandatory=$true)][string]$ArchivePath,
    [Parameter(Mandatory=$true)][string]$Version,
    [Parameter(Mandatory=$false)][string]$WingetPkgsPath = $null,
    [Parameter(Mandatory=$false)][string]$DownloadUrlBase = 'https://fluttergituiartifacts.blob.core.windows.net/releases'
)

$scriptDir = $PSScriptRoot
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$templatesDir = Join-Path $projectRoot "release/manifests/winget"

Write-Host "Updating winget manifest..." -ForegroundColor Yellow

try {
    Write-Host "  Calculating SHA256 hash..." -ForegroundColor Gray
    $hash = (Get-FileHash -Path $ArchivePath -Algorithm SHA256).Hash
    Write-Host "  SHA256: $hash" -ForegroundColor Gray

    if (-not $WingetPkgsPath) {
        $possiblePaths = @("D:\repos\kartalbas\winget-pkgs", "$env:USERPROFILE\repos\winget-pkgs")
        foreach ($path in $possiblePaths) {
            if (Test-Path $path) { $WingetPkgsPath = $path; break }
        }
    }

    if (-not $WingetPkgsPath -or -not (Test-Path $WingetPkgsPath)) {
        Write-Host "  [SKIP] Winget-pkgs repo not found" -ForegroundColor Yellow
        return @{ Success = $true; Skipped = $true; SHA256 = $hash }
    }

    $baseVersion = $Version -replace '\+.*$', ''
    $manifestDir = Join-Path $WingetPkgsPath "manifests\f\FlutterGitUI\FlutterGitUI\$baseVersion"
    if (-not (Test-Path $manifestDir)) { New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null }

    $archiveName = Split-Path -Leaf $ArchivePath
    $downloadUrl = "$DownloadUrlBase/$archiveName"

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
