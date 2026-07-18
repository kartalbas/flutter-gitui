#!/usr/bin/env pwsh
# ============================================================================
# Linux Release Build Script
# ============================================================================
# Orchestrates the complete Linux build process using Docker containers.
# Calls modular shared components and Linux-specific build modules.
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
$artifactsDir = Join-Path $releaseDir "artifacts/linux"
$dockerDir = Join-Path $releaseDir "docker"

# ============================================================================
# Setup Build Logging
# ============================================================================

$buildStartTime = Get-Date
$artifactsParent = Split-Path -Parent $artifactsDir
if (-not (Test-Path $artifactsParent)) { New-Item -ItemType Directory -Path $artifactsParent -Force | Out-Null }

$buildLogFile = Join-Path $artifactsParent "linux-release.log"
"" | Set-Content $buildLogFile -Encoding UTF8

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$timestamp] $Message" | Out-File -FilePath $script:buildLogFile -Append -Encoding UTF8
}

function Invoke-LoggedCommand {
    param([scriptblock]$Command, [string]$Description = "")
    if ($Description) { Write-Log $Description "Gray" }
    $output = & $Command 2>&1
    $output | ForEach-Object {
        Write-Host $_
        $_ | Out-File -FilePath $script:buildLogFile -Append -Encoding UTF8
    }
    return $output
}

Write-Log ""
Write-Log "============================================" "Cyan"
Write-Log "Flutter GitUI - Linux Release Build" "Cyan"
Write-Log "============================================" "Cyan"
Write-Log ""
Write-Log "Build started: $($buildStartTime.ToString('yyyy-MM-dd HH:mm:ss'))" "Gray"
Write-Log "Project Root:  $projectRoot" "Gray"
Write-Log "Artifacts:     $artifactsDir" "Gray"
Write-Log "Docker:        $dockerDir" "Gray"
Write-Log ""

# ============================================================================
# STEP 1: VERSION MANAGEMENT
# ============================================================================

$currentStep = 1
$totalSteps = 13

Write-Log "[Step $currentStep/$totalSteps] Managing version..." "Yellow"

try {
    $pubspecPath = Join-Path $projectRoot "pubspec.yaml"
    $versionResult = & (Join-Path $sharedDir "version-manager.ps1") -PubspecPath $pubspecPath

    if (-not $versionResult -or -not $versionResult.Success) {
        throw "Version management module failed"
    }

    $version = $versionResult.NewVersion
    $commit = $versionResult.CommitShort
    $commitFull = $versionResult.CommitFull

    Write-Log "[OK] Version: $version (commit: $commit)" "Green"

    # Rename log file to include version
    $newLogFile = Join-Path $artifactsParent "flutter-gitui-v$version-linux.log"
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
    & (Join-Path $sharedDir "sync-icons.ps1") 2>&1 | ForEach-Object {
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
    $changelogResult = & (Join-Path $sharedDir "changelog-generator.ps1") `
        -ProjectRoot $projectRoot `
        -ReleaseDir $releaseDir `
        -Version $version `
        -CommitShort $commit `
        -CommitFull $commitFull `
        -Tag $versionResult.Tag `
        -Platform "linux"

    if (-not $changelogResult -or -not $changelogResult.Success) {
        throw "Changelog generation module failed"
    }

    $changelogContent = $changelogResult.ChangelogMarkdown

    Write-Log "[OK] Changelog generated for Linux" "Green"
    Write-Log ""
} catch {
    Write-Log "[ERROR] Changelog generation failed: $($_.Exception.Message)" "Red"
    exit 1
}

# ============================================================================
# STEP 4: DOCKER PREREQUISITE CHECK
# ============================================================================

$currentStep++
Write-Log "[Step $currentStep/$totalSteps] Checking Docker prerequisites..." "Yellow"

try {
    $dockerCheckResult = & (Join-Path $scriptDir "build-linux.ps1") `
        -ProjectRoot $projectRoot `
        -ReleaseDir $artifactsDir `
        -DockerDir $dockerDir `
        -Version $version `
        -CheckOnly

    if (-not $dockerCheckResult -or -not $dockerCheckResult.Ready) {
        throw "Docker prerequisites not met. See error above."
    }

    Write-Log "[OK] Docker environment ready" "Green"
    Write-Log ""
} catch {
    Write-Log "[ERROR] Docker check failed: $($_.Exception.Message)" "Red"
    exit 1
}

# ============================================================================
# STEP 5: BUILD PREPARATION
# ============================================================================

$currentStep++
Write-Log "[Step $currentStep/$totalSteps] Preparing build environment..." "Yellow"

try {
    $prepResult = & (Join-Path $sharedDir "build-prep.ps1") `
        -ProjectRoot $projectRoot `
        -ReleaseDir $artifactsDir `
        -Platform "linux"

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
# STEP 6: LINUX BUILD (Docker)
# ============================================================================

$currentStep++
Write-Log "[Step $currentStep/$totalSteps] Building Linux binaries (Docker)..." "Yellow"

try {
    $buildLogPath = Join-Path $artifactsParent "flutter-gitui-v$version-linux-build.log"

    $linuxBuildResult = & (Join-Path $scriptDir "build-linux.ps1") `
        -ProjectRoot $projectRoot `
        -ReleaseDir $artifactsDir `
        -DockerDir $dockerDir `
        -Version $version `
        -LogFile $buildLogPath

    if (-not $linuxBuildResult -or -not $linuxBuildResult.Success) {
        throw "Linux build module failed"
    }

    Write-Log "[OK] Linux build complete ($($linuxBuildResult.BuildTime.TotalSeconds.ToString('0.0'))s)" "Green"
    Write-Log ""
} catch {
    Write-Log "[ERROR] Linux build failed: $($_.Exception.Message)" "Red"
    exit 1
}

# ============================================================================
# STEP 7: GENERATE DOCUMENTATION
# ============================================================================

$currentStep++
Write-Log "[Step $currentStep/$totalSteps] Generating documentation..." "Yellow"

try {
    $buildInfo = @{
        WindowsSizeMB = 0
        LinuxSizeMB = $linuxBuildResult.SizeMB
        WindowsBuildTimeSec = "0.0"
        LinuxBuildTimeSec = $linuxBuildResult.BuildTime.TotalSeconds.ToString('0.0')
    }

    $docsResult = & (Join-Path $sharedDir "generate-docs.ps1") `
        -ReleaseDir $artifactsDir `
        -Version $version `
        -CommitShort $commit `
        -ChangelogContent $changelogContent `
        -BuildInfo $buildInfo `
        -Platform "linux"

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
# STEP 8: PREPARE CHANGELOG FOR DISTRIBUTION
# ============================================================================

$currentStep++
Write-Log "[Step $currentStep/$totalSteps] Preparing changelog for distribution..." "Yellow"

try {
    $platformChangelogFile = Join-Path $projectRoot "assets/changelog-linux.json"
    $mainChangelogFile = Join-Path $projectRoot "assets/changelog.json"

    # Copy platform-specific changelog to main changelog.json
    if (Test-Path $platformChangelogFile) {
        Copy-Item $platformChangelogFile $mainChangelogFile -Force
        Write-Log "  [OK] Copied changelog-linux.json to changelog.json" "Green"
    }

    # Remove other platform changelogs
    $otherPlatforms = @("windows", "macos")
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
# STEP 9: CREATE ARCHIVE
# ============================================================================

$currentStep++
Write-Log "[Step $currentStep/$totalSteps] Creating release archive..." "Yellow"

try {
    $archiveResult = & (Join-Path $sharedDir "create-archive.ps1") `
        -ReleaseDir $artifactsDir `
        -Version $version `
        -ChangelogContent $changelogContent `
        -Platform "linux"

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
# STEP 9: AZURE UPLOAD (Optional)
# ============================================================================

if (-not $SkipAzureUpload) {
    $currentStep++
    Write-Log "[Step $currentStep/$totalSteps] Uploading to Azure..." "Yellow"

    try {
        $uploadOutput = & (Join-Path $sharedDir "upload-to-azure-rest.ps1") -FilePath $archiveResult.Archive.FilePath 2>&1
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
# STEP 10: BUILD SNAP PACKAGE
# ============================================================================

$currentStep++
Write-Log "[Step $currentStep/$totalSteps] Building Snap package..." "Yellow"

try {
    $bundlePath = $artifactsDir  # Contains flutter-gitui exe + linux/ subfolder
    Write-Log "Bundle path: $bundlePath" "Gray"

    # Run snap build (output will be logged by build-snap.ps1)
    & (Join-Path $sharedDir "build-snap.ps1") -Version $version -BundlePath $bundlePath 2>&1 | ForEach-Object {
        Write-Host $_
        $_ | Out-File -FilePath $buildLogFile -Append -Encoding UTF8
    }

    # Check exit code from build-snap.ps1
    if ($LASTEXITCODE -eq 0) {
        # Verify snap file exists in artifacts root
        $artifactsRoot = Split-Path -Parent $artifactsDir
        $snapFile = Get-ChildItem -Path $artifactsRoot -Filter "flutter-gitui-v$version.snap" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($snapFile) {
            Write-Log "[OK] Snap built: $($snapFile.Name)" "Green"
        } else {
            Write-Log "[ERROR] Snap file not found after build" "Red"
            exit 1
        }
    } else {
        Write-Log "[ERROR] Snap build failed" "Red"
        exit 1
    }
    Write-Log ""
} catch {
    Write-Log "[ERROR] Snap build failed: $($_.Exception.Message)" "Red"
    exit 1
}

# ============================================================================
# STEP 11: BUILD SUMMARY
# ============================================================================

$currentStep++
Write-Log "[Step $currentStep/$totalSteps] Validating build..." "Yellow"

try {
    $summaryResult = & (Join-Path $sharedDir "build-summary.ps1") `
        -Version $version `
        -Commit $commit `
        -ArchiveName $archiveResult.Archive.FileName `
        -ReleaseDir $artifactsDir `
        -Platform 'linux'

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
# STEP 12: GIT COMMIT
# ============================================================================

$currentStep++
Write-Log "[Step $currentStep/$totalSteps] Committing version changes..." "Yellow"

try {
    $gitResult = & (Join-Path $sharedDir "git-commit.ps1") `
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
Write-Log "Linux Build Complete!" "Green"
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
