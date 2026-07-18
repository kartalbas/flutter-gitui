#!/usr/bin/env pwsh
# ============================================================================
# Archive Creation Module
# ============================================================================
# Creates ZIP archives and update manifests for releases
# BUILD-STEP: 10
# ============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ReleaseDir,

    [Parameter(Mandatory=$true)]
    [string]$Version,

    [Parameter(Mandatory=$true)]
    [string]$ChangelogContent,

    [Parameter(Mandatory=$false)]
    [ValidateSet('windows', 'linux', 'macos')]
    [string]$Platform = 'windows',

    [Parameter(Mandatory=$false)]
    [string]$CommitShort = ''
)

function New-Archive {
    param(
        [string]$ReleaseDir,
        [string]$Version,
        [string]$Platform,
        [string]$CommitShort
    )

    Write-Host "  Creating $Platform archive..." -ForegroundColor Gray

    # Include commit hash in filename for development builds (same version, different commits)
    if ($CommitShort) {
        $archiveName = "flutter-gitui-v$Version+$CommitShort-$Platform.zip"
    } else {
        $archiveName = "flutter-gitui-v$Version-$Platform.zip"
    }

    # Get parent directory for archive output
    $artifactsParent = Split-Path -Parent $ReleaseDir

    Compress-Archive -Path "$ReleaseDir/*" -DestinationPath "$artifactsParent/$archiveName" -Force
    $archivePath = "$artifactsParent/$archiveName"
    $totalSize = (Get-Item $archivePath).Length / 1MB
    $archiveBytes = (Get-Item $archivePath).Length

    Write-Host "  [OK] Archive created: $archiveName" -ForegroundColor Green

    return @{
        FileName = $archiveName
        FilePath = $archivePath
        SizeMB = $totalSize
        SizeBytes = $archiveBytes
    }
}

function New-UpdateManifest {
    param(
        [string]$ReleaseDir,
        [string]$Version,
        [string]$ChangelogContent,
        [hashtable]$ArchiveInfo,
        [string]$Platform,
        [string]$CommitShort = ''
    )

    Write-Host "  Creating update manifest..." -ForegroundColor Gray

    # Construct full version string including commit hash if provided
    # This ensures update detection works correctly when using commit-based builds
    $fullVersion = if ($CommitShort) { "$Version+$CommitShort" } else { $Version }

    # Create latest.json manifest for auto-update feature
    $manifestData = @{
        version = $fullVersion
        releaseDate = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        changelog = $ChangelogContent
        platform = $Platform
    }

    # Add platform-specific download info
    $manifestData.$Platform = @{
        fileName = $ArchiveInfo.FileName
        fileSize = $ArchiveInfo.SizeBytes
        platform = $Platform
    }

    # Write manifest file with proper UTF-8 encoding
    $artifactsParent = Split-Path -Parent $ReleaseDir
    $manifestPath = "$artifactsParent/latest-$Platform.json"
    $manifestJson = $manifestData | ConvertTo-Json -Depth 10
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($manifestPath, $manifestJson, $utf8NoBom)

    Write-Host "  [OK] Manifest created: latest-$Platform.json" -ForegroundColor Green

    return @{
        Path = $manifestPath
        Data = $manifestData
    }
}

# ============================================================================
# Main Execution
# ============================================================================

Write-Host "Creating archive and manifest..." -ForegroundColor Yellow

try {
    $archiveInfo = New-Archive -ReleaseDir $ReleaseDir -Version $Version -Platform $Platform -CommitShort $CommitShort

    # Validate archive was created
    if (-not (Test-Path $archiveInfo.FilePath)) {
        throw "Archive file was not created at $($archiveInfo.FilePath)"
    }

    if ($archiveInfo.SizeBytes -lt 1MB) {
        throw "Archive file is too small ($($archiveInfo.SizeMB) MB) - likely incomplete"
    }

    $manifestInfo = New-UpdateManifest `
        -ReleaseDir $ReleaseDir `
        -Version $Version `
        -ChangelogContent $ChangelogContent `
        -ArchiveInfo $archiveInfo `
        -Platform $Platform `
        -CommitShort $CommitShort

    # Validate manifest was created
    if (-not (Test-Path $manifestInfo.Path)) {
        throw "Manifest file was not created at $($manifestInfo.Path)"
    }

    Write-Host "[OK] Archive and manifest created" -ForegroundColor Green

    return @{
        Success = $true
        Archive = $archiveInfo
        Manifest = $manifestInfo
    }

} catch {
    Write-Host "[ERROR] Archive creation failed: $($_.Exception.Message)" -ForegroundColor Red
    throw "Archive creation failed - cannot release without archive"
}
