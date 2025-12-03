#!/usr/bin/env pwsh
# ============================================================================
# Windows Release Build Script
# ============================================================================
# Orchestrates the complete Windows build process by calling modular
# shared components and Windows-specific build modules.
# ============================================================================

param(
    [Parameter(Mandatory=$false)]
    [switch]$SkipAzureUpload = $false
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ============================================================================
# Setup Paths
# ============================================================================

$scriptDir = $PSScriptRoot
$releaseDir = Split-Path -Parent $scriptDir
$projectRoot = Split-Path -Parent $releaseDir
$sharedDir = Join-Path $releaseDir "shared"
$artifactsDir = Join-Path $releaseDir "artifacts/windows"
$updaterDir = Join-Path $releaseDir "updater"

# ============================================================================
# Setup Build Logging
# ============================================================================

$buildStartTime = Get-Date
$artifactsParent = Split-Path -Parent $artifactsDir
if (-not (Test-Path $artifactsParent)) { New-Item -ItemType Directory -Path $artifactsParent -Force | Out-Null }

$buildLogFile = Join-Path $artifactsParent "windows-release.log"
"" | Set-Content $buildLogFile -Encoding UTF8

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$timestamp] $Message" | Out-File -FilePath $script:buildLogFile -Append -Encoding UTF8
}

Write-Log ""
Write-Log "============================================" "Cyan"
Write-Log "Flutter GitUI - Windows Release Build" "Cyan"
Write-Log "============================================" "Cyan"
Write-Log ""
Write-Log "Build started: $($buildStartTime.ToString('yyyy-MM-dd HH:mm:ss'))" "Gray"
Write-Log "Project Root:  $projectRoot" "Gray"
Write-Log "Artifacts:     $artifactsDir" "Gray"
Write-Log ""

# ============================================================================
# STEP 1: VERSION MANAGEMENT
# ============================================================================

$currentStep = 1
$totalSteps = 12

Write-Log "[Step $currentStep/$totalSteps] Managing version..." "Yellow"

try {
    $pubspecPath = Join-Path $projectRoot "pubspec.yaml"
    $versionResult = & "$sharedDir/version-manager.ps1" -PubspecPath $pubspecPath

    if (-not $versionResult -or -not $versionResult.Success) {
        throw "Version management module failed"
    }

    $version = $versionResult.NewVersion
    $commit = $versionResult.CommitShort
    $commitFull = $versionResult.CommitFull

    Write-Log "[OK] Version: $version (commit: $commit)" "Green"

    # Rename log file to include version
    $newLogFile = Join-Path $artifactsParent "flutter-gitui-v$version-windows.log"
    if ($buildLogFile -ne $newLogFile) {
        if (Test-Path $newLogFile) { Remove-Item $newLogFile -Force }
        Move-Item $buildLogFile $newLogFile -Force
        $buildLogFile = $newLogFile
    }
    Write-Log "Log File:      $buildLogFile" "Gray"
    Write-Log ""
} catch {
    Write-Log "[ERROR] Version management failed: $($_.Exception.Message)" "Red"
    exit 1
}

# ============================================================================
# STEP 2: ICON SYNC
# ============================================================================

$currentStep++
Write-Log "[Step $currentStep/$totalSteps] Syncing icons..." "Yellow"

try {
    & "$sharedDir/sync-icons.ps1" 2>&1 | ForEach-Object {
        Write-Host $_
        $_ | Out-File -FilePath $buildLogFile -Append -Encoding UTF8
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Icon sync module failed"
    }
    Write-Log ""
} catch {
    Write-Log "[ERROR] Icon sync failed: $($_.Exception.Message)" "Red"
    exit 1
}

# ============================================================================
# STEP 3: CHANGELOG GENERATION
# ============================================================================

$currentStep++
Write-Log "[Step $currentStep/$totalSteps] Generating changelog..." "Yellow"

try {
    $changelogResult = & "$sharedDir/changelog-generator.ps1" `
        -ProjectRoot $projectRoot `
        -ReleaseDir $releaseDir `
        -Version $version `
        -CommitShort $commit `
        -CommitFull $commitFull `
        -Tag $versionResult.Tag `
        -Platform "windows"

    if (-not $changelogResult -or -not $changelogResult.Success) {
        throw "Changelog generation module failed"
    }

    $changelogContent = $changelogResult.ChangelogMarkdown

    Write-Log "[OK] Changelog generated for Windows" "Green"
    Write-Log ""
} catch {
    Write-Log "[ERROR] Changelog generation failed: $($_.Exception.Message)" "Red"
    exit 1
}

# ============================================================================
# STEP 4: BUILD PREPARATION
# ============================================================================

$currentStep++
Write-Log "[Step $currentStep/$totalSteps] Preparing build environment..." "Yellow"

try {
    $prepResult = & "$sharedDir/build-prep.ps1" `
        -ProjectRoot $projectRoot `
        -ReleaseDir $artifactsDir `
        -Platform "windows"

    if (-not $prepResult -or -not $prepResult.Success) {
        throw "Build preparation module failed"
    }

    Write-Log "[OK] Build environment ready" "Green"
    Write-Log ""
} catch {
    Write-Log "[ERROR] Build preparation failed: $($_.Exception.Message)" "Red"
    exit 1
}

# ============================================================================
# STEP 5: WINDOWS BUILD
# ============================================================================

$currentStep++
Write-Log "[Step $currentStep/$totalSteps] Building Windows binaries..." "Yellow"

try {
    $buildLogPath = Join-Path $artifactsParent "flutter-gitui-v$version-windows-build.log"
    $buildDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $windowsBuildResult = & "$scriptDir/build-windows.ps1" `
        -ProjectRoot $projectRoot `
        -ReleaseDir $artifactsDir `
        -UpdaterDir $updaterDir `
        -CommitShort $commit `
        -BuildDate $buildDate `
        -Version $version `
        -LogFile $buildLogPath

    if (-not $windowsBuildResult -or -not $windowsBuildResult.Success) {
        throw "Windows build module failed"
    }

    Write-Log "[OK] Windows build complete ($($windowsBuildResult.BuildTime.TotalSeconds.ToString('0.0'))s)" "Green"
    Write-Log ""
} catch {
    Write-Log "[ERROR] Windows build failed: $($_.Exception.Message)" "Red"
    exit 1
}

# ============================================================================
# STEP 6: GENERATE DOCUMENTATION
# ============================================================================

$currentStep++
Write-Log "[Step $currentStep/$totalSteps] Generating documentation..." "Yellow"

try {
    $buildInfo = @{
        WindowsSizeMB = $windowsBuildResult.SizeMB
        LinuxSizeMB = 0
        WindowsBuildTimeSec = $windowsBuildResult.BuildTime.TotalSeconds.ToString('0.0')
        LinuxBuildTimeSec = "0.0"
    }

    $docsResult = & "$sharedDir/generate-docs.ps1" `
        -ReleaseDir $artifactsDir `
        -Version $version `
        -CommitShort $commit `
        -ChangelogContent $changelogContent `
        -BuildInfo $buildInfo `
        -Platform "windows"

    if (-not $docsResult -or -not $docsResult.Success) {
        throw "Documentation generation module failed"
    }

    Write-Log "[OK] Documentation generated" "Green"
    Write-Log ""
} catch {
    Write-Log "[ERROR] Documentation generation failed: $($_.Exception.Message)" "Red"
    exit 1
}

# ============================================================================
# STEP 7: PREPARE CHANGELOG FOR DISTRIBUTION
# ============================================================================

$currentStep++
Write-Log "[Step $currentStep/$totalSteps] Preparing changelog for distribution..." "Yellow"

try {
    $platformChangelogFile = Join-Path $projectRoot "assets/changelog-windows.json"
    $mainChangelogFile = Join-Path $projectRoot "assets/changelog.json"

    # Copy platform-specific changelog to main changelog.json
    if (Test-Path $platformChangelogFile) {
        Copy-Item $platformChangelogFile $mainChangelogFile -Force
        Write-Log "  [OK] Copied changelog-windows.json to changelog.json" "Green"
    }

    # Remove other platform changelogs
    $otherPlatforms = @("linux", "macos")
    foreach ($platform in $otherPlatforms) {
        $otherChangelogFile = Join-Path $projectRoot "assets/changelog-$platform.json"
        if (Test-Path $otherChangelogFile) {
            Remove-Item $otherChangelogFile -Force
            Write-Log "  [OK] Removed changelog-$platform.json" "Gray"
        }
    }

    Write-Log ""
} catch {
    Write-Log "[ERROR] Changelog preparation failed: $($_.Exception.Message)" "Red"
    exit 1
}

# ============================================================================
# STEP 8: CREATE ARCHIVE
# ============================================================================

$currentStep++
Write-Log "[Step $currentStep/$totalSteps] Creating release archive..." "Yellow"

try {
    $archiveResult = & "$sharedDir/create-archive.ps1" `
        -ReleaseDir $artifactsDir `
        -Version $version `
        -ChangelogContent $changelogContent `
        -Platform "windows" `
        -CommitShort $commit

    if (-not $archiveResult -or -not $archiveResult.Success) {
        throw "Archive creation module failed"
    }

    Write-Log "[OK] Archive created: $($archiveResult.Archive.FileName)" "Green"
    Write-Log ""
} catch {
    Write-Log "[ERROR] Archive creation failed: $($_.Exception.Message)" "Red"
    exit 1
}

# ============================================================================
# STEP 8: UPDATE WINGET MANIFEST
# ============================================================================

$currentStep++
Write-Log "[Step $currentStep/$totalSteps] Updating winget manifest..." "Yellow"

try {
    $wingetOutput = & "$sharedDir/update-winget-manifest.ps1" `
        -ArchivePath $archiveResult.Archive.FilePath `
        -Version $version 2>&1
    $wingetOutput | ForEach-Object {
        Write-Host $_
        $_ | Out-File -FilePath $buildLogFile -Append -Encoding UTF8
    }
    $wingetResult = $wingetOutput | Select-Object -Last 1

    if ($wingetResult -and $wingetResult.Success) {
        if ($wingetResult.Skipped) {
            Write-Log "[SKIP] Winget-pkgs repo not found" "Yellow"
        } else {
            Write-Log "[OK] Winget manifest updated" "Green"
        }
    } else {
        Write-Log "[WARN] Winget manifest update failed" "Yellow"
    }
    Write-Log ""
} catch {
    Write-Log "[WARN] Winget manifest update failed: $($_.Exception.Message)" "Yellow"
    Write-Log ""
}

# ============================================================================
# STEP 9: AZURE UPLOAD (Optional)
# ============================================================================

if (-not $SkipAzureUpload) {
    $currentStep++
    Write-Log "[Step $currentStep/$totalSteps] Uploading to Azure..." "Yellow"

    try {
        $uploadOutput = & "$sharedDir/upload-to-azure-rest.ps1" -FilePath $archiveResult.Archive.FilePath 2>&1
        $uploadOutput | ForEach-Object {
            Write-Host $_
            $_ | Out-File -FilePath $buildLogFile -Append -Encoding UTF8
        }

        if ($LASTEXITCODE -eq 0) {
            Write-Log "[OK] Upload complete" "Green"
        } else {
            Write-Log "[ERROR] Upload failed" "Red"
            exit 1
        }
        Write-Log ""
    } catch {
        Write-Log "[ERROR] Upload failed: $($_.Exception.Message)" "Red"
        exit 1
    }
} else {
    Write-Log "[SKIP] Azure upload (--SkipAzureUpload)" "Yellow"
    Write-Log ""
}

# ============================================================================
# STEP 10: BUILD SUMMARY
# ============================================================================

$currentStep++
Write-Log "[Step $currentStep/$totalSteps] Validating build..." "Yellow"

try {
    $summaryResult = & "$sharedDir/build-summary.ps1" `
        -Version $version `
        -Commit $commit `
        -ArchiveName $archiveResult.Archive.FileName `
        -ReleaseDir $artifactsDir `
        -Platform 'windows'

    if (-not $summaryResult -or -not $summaryResult.Success) {
        throw "Build summary validation failed"
    }

    Write-Log "[OK] Build validated" "Green"
    Write-Log ""
} catch {
    Write-Log "[ERROR] Build validation failed: $($_.Exception.Message)" "Red"
    exit 1
}

# ============================================================================
# STEP 11: GIT COMMIT
# ============================================================================

$currentStep++
Write-Log "[Step $currentStep/$totalSteps] Committing version changes..." "Yellow"

try {
    $gitResult = & "$sharedDir/git-commit.ps1" `
        -ProjectRoot $projectRoot `
        -Version $version

    if ($gitResult -and $gitResult.Success) {
        Write-Log "[OK] Changes committed and pushed" "Green"
    } else {
        Write-Log "[INFO] No changes to commit" "Gray"
    }
    Write-Log ""
} catch {
    Write-Log "[WARN] Git commit failed: $($_.Exception.Message)" "Yellow"
    Write-Log ""
}

# ============================================================================
# FINAL SUMMARY
# ============================================================================

$buildEndTime = Get-Date
$totalBuildTime = $buildEndTime - $buildStartTime

Write-Log ""
Write-Log "============================================" "Green"
Write-Log "Windows Build Complete!" "Green"
Write-Log "============================================" "Green"
Write-Log ""
Write-Log "Version:       $version" "White"
Write-Log "Commit:        $commit" "White"
Write-Log "Archive:       $($archiveResult.Archive.FileName)" "White"
Write-Log "Size:          $([math]::Round($archiveResult.Archive.SizeMB, 2)) MB" "White"
Write-Log "Build Time:    $($totalBuildTime.TotalSeconds.ToString('0.0'))s" "White"
Write-Log ""
Write-Log "Artifacts:     $artifactsDir" "Gray"
Write-Log "Log File:      $buildLogFile" "Gray"
Write-Log ""

exit 0
