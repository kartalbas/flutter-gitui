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
# Setup Build Logging (transcript started after version detection)
# ============================================================================

$buildStartTime = Get-Date
$transcriptStarted = $false
$buildLogFile = $null

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Flutter GitUI - Windows Release Build" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Build started: $($buildStartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
Write-Host "Project Root:  $projectRoot" -ForegroundColor Gray
Write-Host "Artifacts:     $artifactsDir" -ForegroundColor Gray
Write-Host ""

# ============================================================================
# STEP 1: VERSION MANAGEMENT
# ============================================================================

$currentStep = 1
$totalSteps = 10

Write-Host "[Step $currentStep/$totalSteps] Managing version..." -ForegroundColor Yellow

try {
    $pubspecPath = Join-Path $projectRoot "pubspec.yaml"
    $versionResult = & "$sharedDir/version-manager.ps1" -PubspecPath $pubspecPath

    if (-not $versionResult -or -not $versionResult.Success) {
        throw "Version management module failed"
    }

    $version = $versionResult.NewVersion
    $commit = $versionResult.CommitShort
    $commitFull = $versionResult.CommitFull

    Write-Host "[OK] Version: $version (commit: $commit)" -ForegroundColor Green

    # Start transcript now that we know the version
    $artifactsParent = Split-Path -Parent $artifactsDir
    if (-not (Test-Path $artifactsParent)) { New-Item -ItemType Directory -Path $artifactsParent -Force | Out-Null }
    $buildLogFile = Join-Path $artifactsParent "flutter-gitui-v$version-windows.log"
    try {
        Stop-Transcript -ErrorAction SilentlyContinue
        Start-Transcript -Path $buildLogFile -Force
        $transcriptStarted = $true
        Write-Host "Log File:      $buildLogFile" -ForegroundColor Gray
    } catch {
        Write-Host "[WARN] Could not start transcript logging: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    Write-Host ""
} catch {
    Write-Host "[ERROR] Version management failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ============================================================================
# STEP 2: ICON SYNC
# ============================================================================

$currentStep++
Write-Host "[Step $currentStep/$totalSteps] Syncing icons..." -ForegroundColor Yellow

try {
    & "$sharedDir/sync-icons.ps1"
    if ($LASTEXITCODE -ne 0) {
        throw "Icon sync module failed"
    }
    Write-Host ""
} catch {
    Write-Host "[ERROR] Icon sync failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ============================================================================
# STEP 3: CHANGELOG GENERATION
# ============================================================================

$currentStep++
Write-Host "[Step $currentStep/$totalSteps] Generating changelog..." -ForegroundColor Yellow

try {
    $changelogResult = & "$sharedDir/changelog-generator.ps1" `
        -ProjectRoot $projectRoot `
        -ReleaseDir $releaseDir `
        -Version $version `
        -CommitShort $commit `
        -CommitFull $commitFull `
        -Tag $versionResult.Tag

    if (-not $changelogResult -or -not $changelogResult.Success) {
        throw "Changelog generation module failed"
    }

    $changelogContent = $changelogResult.ChangelogMarkdown

    Write-Host "[OK] Changelog generated" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "[ERROR] Changelog generation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ============================================================================
# STEP 4: BUILD PREPARATION
# ============================================================================

$currentStep++
Write-Host "[Step $currentStep/$totalSteps] Preparing build environment..." -ForegroundColor Yellow

try {
    $prepResult = & "$sharedDir/build-prep.ps1" `
        -ProjectRoot $projectRoot `
        -ReleaseDir $artifactsDir `
        -Platform "windows"

    if (-not $prepResult -or -not $prepResult.Success) {
        throw "Build preparation module failed"
    }

    Write-Host "[OK] Build environment ready" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "[ERROR] Build preparation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ============================================================================
# STEP 5: WINDOWS BUILD
# ============================================================================

$currentStep++
Write-Host "[Step $currentStep/$totalSteps] Building Windows binaries..." -ForegroundColor Yellow

try {
    $buildLogPath = Join-Path $projectRoot "build_windows.log"

    $windowsBuildResult = & "$scriptDir/build-windows.ps1" `
        -ProjectRoot $projectRoot `
        -ReleaseDir $artifactsDir `
        -UpdaterDir $updaterDir `
        -Version $version `
        -LogFile $buildLogPath

    if (-not $windowsBuildResult -or -not $windowsBuildResult.Success) {
        throw "Windows build module failed"
    }

    Write-Host "[OK] Windows build complete ($($windowsBuildResult.BuildTime.TotalSeconds.ToString('0.0'))s)" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "[ERROR] Windows build failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ============================================================================
# STEP 6: GENERATE DOCUMENTATION
# ============================================================================

$currentStep++
Write-Host "[Step $currentStep/$totalSteps] Generating documentation..." -ForegroundColor Yellow

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

    Write-Host "[OK] Documentation generated" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "[ERROR] Documentation generation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ============================================================================
# STEP 7: CREATE ARCHIVE
# ============================================================================

$currentStep++
Write-Host "[Step $currentStep/$totalSteps] Creating release archive..." -ForegroundColor Yellow

try {
    $archiveResult = & "$sharedDir/create-archive.ps1" `
        -ReleaseDir $artifactsDir `
        -Version $version `
        -ChangelogContent $changelogContent `
        -Platform "windows"

    if (-not $archiveResult -or -not $archiveResult.Success) {
        throw "Archive creation module failed"
    }

    Write-Host "[OK] Archive created: $($archiveResult.Archive.FileName)" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "[ERROR] Archive creation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ============================================================================
# STEP 8: AZURE UPLOAD (Optional)
# ============================================================================

if (-not $SkipAzureUpload) {
    $currentStep++
    Write-Host "[Step $currentStep/$totalSteps] Uploading to Azure..." -ForegroundColor Yellow

    try {
        & "$sharedDir/upload-to-azure-rest.ps1" -FilePath $archiveResult.Archive.FilePath

        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Upload complete" -ForegroundColor Green
        } else {
            Write-Host "[WARN] Upload failed (continuing)" -ForegroundColor Yellow
        }
        Write-Host ""
    } catch {
        Write-Host "[WARN] Upload failed: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host ""
    }
} else {
    Write-Host "[SKIP] Azure upload (--SkipAzureUpload)" -ForegroundColor Yellow
    Write-Host ""
}

# ============================================================================
# STEP 9: BUILD SUMMARY
# ============================================================================

$currentStep++
Write-Host "[Step $currentStep/$totalSteps] Validating build..." -ForegroundColor Yellow

try {
    $summaryResult = & "$sharedDir/build-summary.ps1" `
        -Version $version `
        -Commit $commit `
        -ArchiveName $archiveResult.Archive.FileName `
        -ReleaseDir $artifactsDir `
        -LinuxBuilt $false

    if (-not $summaryResult -or -not $summaryResult.Success) {
        throw "Build summary validation failed"
    }

    Write-Host "[OK] Build validated" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "[ERROR] Build validation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ============================================================================
# STEP 10: GIT COMMIT
# ============================================================================

$currentStep++
Write-Host "[Step $currentStep/$totalSteps] Committing version changes..." -ForegroundColor Yellow

try {
    $gitResult = & "$sharedDir/git-commit.ps1" `
        -ProjectRoot $projectRoot `
        -Version $version

    if ($gitResult -and $gitResult.Success) {
        Write-Host "[OK] Changes committed and pushed" -ForegroundColor Green
    } else {
        Write-Host "[INFO] No changes to commit" -ForegroundColor Gray
    }
    Write-Host ""
} catch {
    Write-Host "[WARN] Git commit failed: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host ""
}

# ============================================================================
# FINAL SUMMARY
# ============================================================================

$buildEndTime = Get-Date
$totalBuildTime = $buildEndTime - $buildStartTime

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "Windows Build Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Version:       $version" -ForegroundColor White
Write-Host "Commit:        $commit" -ForegroundColor White
Write-Host "Archive:       $($archiveResult.Archive.FileName)" -ForegroundColor White
Write-Host "Size:          $([math]::Round($archiveResult.Archive.SizeMB, 2)) MB" -ForegroundColor White
Write-Host "Build Time:    $($totalBuildTime.TotalSeconds.ToString('0.0'))s" -ForegroundColor White
Write-Host ""
Write-Host "Artifacts:     $artifactsDir" -ForegroundColor Gray
Write-Host "Log File:      $buildLogFile" -ForegroundColor Gray
Write-Host ""

# Stop transcript logging
if ($transcriptStarted) {
    Stop-Transcript
}

exit 0
