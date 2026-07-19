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

    # Include commit hash in filename for development builds (same version, different commits).
    # The client rejects any manifest fileName outside [A-Za-z0-9._-], so the
    # build metadata has to join with '-' rather than '+'.
    $safeVersion = $Version -replace '\+', '-'
    $stem = if ($CommitShort) {
        "flutter-gitui-v$safeVersion-$CommitShort-$Platform"
    } else {
        "flutter-gitui-v$safeVersion-$Platform"
    }

    # Get parent directory for archive output
    $artifactsParent = Split-Path -Parent $ReleaseDir

    # Compress-Archive writes a plain zip with no POSIX mode bits, so a Linux
    # bundle packed with it arrives non-executable and a macOS .app loses its
    # bundle structure. Pack per platform instead.
    switch ($Platform) {
        'linux' {
            $archiveName = "$stem.tar.gz"
            $archivePath = Join-Path $artifactsParent $archiveName
            # Pack inside a container so the executable bits are real. Docker is
            # already required to build the Linux target.
            $srcMount = (Resolve-Path $ReleaseDir).Path
            $outMount = (Resolve-Path $artifactsParent).Path
            docker run --rm `
                -v "${srcMount}:/src" `
                -v "${outMount}:/out" `
                alpine:3.20 sh -c "cd /src && chmod +x flutter-gitui updater 2>/dev/null; tar czf /out/$archiveName ." | Out-Null
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path $archivePath)) {
                throw "Failed to create Linux archive $archiveName"
            }
        }
        'macos' {
            $archiveName = "$stem.zip"
            $archivePath = Join-Path $artifactsParent $archiveName
            # ditto is the only archiver that preserves an .app bundle intact.
            $app = Get-ChildItem -Path $ReleaseDir -Filter '*.app' -Directory | Select-Object -First 1
            if (-not $app) { throw "No .app bundle found in $ReleaseDir" }
            & ditto -c -k --sequesterRsrc --keepParent $app.FullName $archivePath
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path $archivePath)) {
                throw "Failed to create macOS archive $archiveName"
            }
        }
        default {
            $archiveName = "$stem.zip"
            $archivePath = Join-Path $artifactsParent $archiveName
            Compress-Archive -Path "$ReleaseDir/*" -DestinationPath $archivePath -Force
        }
    }
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

    # $Version already carries the build number that update detection compares.
    # Appending the commit would only add a second '+' component the client drops.
    $fullVersion = $Version

    # Create latest.json manifest for auto-update feature
    $manifestData = @{
        version = $fullVersion
        releaseDate = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        changelog = $ChangelogContent
        platform = $Platform
    }

    # Publish a digest of the archive. Without it the updater installs whatever
    # the download yields, so anyone able to write to the release storage gets
    # code execution on every client.
    $sha256 = (Get-FileHash -Path $ArchiveInfo.FilePath -Algorithm SHA256).Hash.ToLowerInvariant()

    # Add platform-specific download info
    $manifestData.$Platform = @{
        fileName = $ArchiveInfo.FileName
        fileSize = $ArchiveInfo.SizeBytes
        sha256   = $sha256
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
