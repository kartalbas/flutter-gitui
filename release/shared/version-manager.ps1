#!/usr/bin/env pwsh
# ============================================================================
# Version Manager Module (Tag-Based)
# ============================================================================
# Gets version from git tags. Format: v{major}.{minor}.{patch}
# Build number = commits since tag
# Final version: {major}.{minor}.{patch}+{build}
# BUILD-STEP: 1
# ============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$PubspecPath,

    [Parameter(Mandatory=$false)]
    [switch]$DryRun = $false
)

function Get-VersionFromTag {
    # Get latest version tag (matching v*.*.* exactly, no suffix)
    try {
        $allTags = @(git tag -l "v*" --sort=-v:refname 2>$null)
        $versionTags = @($allTags | Where-Object { $_ -match '^v\d+\.\d+\.\d+$' })
        if ($versionTags.Count -eq 0) {
            throw "No version tags found. Create a tag first: git tag v0.1.0"
        }
        $latestTag = $versionTags[0]
    } catch {
        throw "No version tags found. Create a tag first: git tag v0.1.0"
    }

    Write-Host "  Latest tag: $latestTag" -ForegroundColor Gray

    # Parse tag (expects v{major}.{minor}.{patch})
    if ($latestTag -match '^v?(\d+)\.(\d+)\.(\d+)$') {
        $major = [int]$matches[1]
        $minor = [int]$matches[2]
        $patch = [int]$matches[3]
        $baseVersion = "$major.$minor.$patch"
    } else {
        throw "Invalid tag format: $latestTag. Expected: v{major}.{minor}.{patch} (e.g., v0.1.0)"
    }

    Write-Host "  Version: $baseVersion" -ForegroundColor Gray

    return @{
        Tag = $latestTag
        BaseVersion = $baseVersion
        FullVersion = $baseVersion
        Major = $major
        Minor = $minor
        Patch = $patch
    }
}

function Get-CurrentPubspecVersion {
    param([string]$PubspecPath)

    $currentVersion = (Select-String -Path $PubspecPath -Pattern "^version:\s*(.+)$").Matches.Groups[1].Value.Trim()
    return $currentVersion
}

function Update-PubspecVersion {
    param(
        [string]$PubspecPath,
        [string]$NewVersion
    )

    $pubspecContent = Get-Content $PubspecPath -Raw
    $pubspecContent = $pubspecContent -replace "version:\s*.+", "version: $NewVersion"
    $pubspecContent | Set-Content $PubspecPath -NoNewline

    Write-Host "  [OK] Updated pubspec.yaml to $NewVersion" -ForegroundColor Green
}

function Get-GitCommitInfo {
    try {
        $commitShort = (git rev-parse --short HEAD 2>$null)
        $commitFull = (git rev-parse HEAD 2>$null)
        Write-Host "  Commit: $commitShort" -ForegroundColor Gray

        return @{
            Short = $commitShort
            Full = $commitFull
        }
    } catch {
        return @{
            Short = "unknown"
            Full = "unknown"
        }
    }
}

# ============================================================================
# Main Execution
# ============================================================================

Write-Host "Getting version from git tag..." -ForegroundColor Yellow

try {
    $versionInfo = Get-VersionFromTag
    $currentVersion = Get-CurrentPubspecVersion -PubspecPath $PubspecPath
    $commitInfo = Get-GitCommitInfo

    Write-Host "  Current pubspec: $currentVersion" -ForegroundColor Gray
    Write-Host "  New version: $($versionInfo.FullVersion)" -ForegroundColor Green

    # Update pubspec if version changed and not dry-run
    $changed = ($currentVersion -ne $versionInfo.FullVersion)
    if ($changed -and -not $DryRun) {
        Update-PubspecVersion -PubspecPath $PubspecPath -NewVersion $versionInfo.FullVersion
    }

    Write-Host "[OK] Version: $($versionInfo.FullVersion)" -ForegroundColor Green

    return @{
        Success = $true
        OldVersion = $currentVersion
        NewVersion = $versionInfo.FullVersion
        BaseVersion = $versionInfo.BaseVersion
        BuildNumber = $versionInfo.BuildNumber
        Tag = $versionInfo.Tag
        Changed = $changed
        CommitShort = $commitInfo.Short
        CommitFull = $commitInfo.Full
    }

} catch {
    Write-Host "[ERROR] $_" -ForegroundColor Red
    throw $_
}
