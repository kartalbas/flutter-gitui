#!/usr/bin/env pwsh
# ============================================================================
# Changelog Generator Module
# ============================================================================
# Generates AI-assisted changelogs via a configurable API and maintains historical
# changelog tracking in assets/changelog.json
# BUILD-STEP: 3
# ============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectRoot,

    [Parameter(Mandatory=$true)]
    [string]$ReleaseDir,

    [Parameter(Mandatory=$true)]
    [string]$Version,

    [Parameter(Mandatory=$true)]
    [string]$CommitShort,

    [Parameter(Mandatory=$true)]
    [string]$CommitFull,

    [Parameter(Mandatory=$false)]
    [string]$Tag,

    [Parameter(Mandatory=$false)]
    [ValidateSet('windows', 'linux', 'macos')]
    [string]$Platform = 'windows',

    # A build that fails after this step must leave its commits inside the next
    # `git log` range, so the caller can defer the watermark until it has a
    # validated artifact and advance it with -WatermarkOnly afterwards.
    [Parameter(Mandatory=$false)]
    [switch]$SkipWatermark,

    [Parameter(Mandatory=$false)]
    [switch]$WatermarkOnly
)

function Get-CommitsSinceLastBuild {
    param(
        [string]$ReleaseDir,
        [string]$LastTag,
        [string]$Platform
    )

    $lastBuildFile = Join-Path $ReleaseDir ".last-build-commit-$Platform"
    $lastCommit = $null

    if (Test-Path $lastBuildFile) {
        $lastCommit = Get-Content $lastBuildFile -ErrorAction SilentlyContinue
    }

    # Get commits since last build
    $commitRange = if ($lastCommit) {
        "$lastCommit..HEAD"
    } elseif ($LastTag) {
        "$lastTag..HEAD"
    } else {
        "HEAD~10..HEAD"
    }

    $commits = @(git log $commitRange --pretty=format:"%h|%s|%an|%ar" 2>$null)

    return @{
        Commits = $commits
        Range = $commitRange
    }
}

function Get-ChangelogApiSetting {
    param(
        [string]$ProjectRoot,
        [string]$Name
    )

    $envPath = Join-Path $ProjectRoot ".env"
    if (Test-Path $envPath) {
        foreach ($line in Get-Content $envPath) {
            if ($line -match "^$([regex]::Escape($Name))=(.+)$") {
                return $matches[1].Trim()
            }
        }
    }
    return [Environment]::GetEnvironmentVariable($Name)
}

function Invoke-AiChangelogGeneration {
    param(
        [string]$ProjectRoot,
        [array]$Commits
    )

    # Every provider-specific value comes from configuration, so this script
    # names no vendor and can point at any chat-completions style endpoint.
    $apiKey    = Get-ChangelogApiSetting -ProjectRoot $ProjectRoot -Name 'CHANGELOG_API_KEY'
    $apiUrl    = Get-ChangelogApiSetting -ProjectRoot $ProjectRoot -Name 'CHANGELOG_API_URL'
    $apiModel  = Get-ChangelogApiSetting -ProjectRoot $ProjectRoot -Name 'CHANGELOG_API_MODEL'
    $keyHeader = Get-ChangelogApiSetting -ProjectRoot $ProjectRoot -Name 'CHANGELOG_API_KEY_HEADER'
    $extra     = Get-ChangelogApiSetting -ProjectRoot $ProjectRoot -Name 'CHANGELOG_API_HEADERS'

    if (-not $apiKey -or -not $apiUrl -or -not $apiModel) {
        Write-Host "  [INFO] AI changelog not configured (set CHANGELOG_API_URL, CHANGELOG_API_KEY and CHANGELOG_API_MODEL in .env)" -ForegroundColor Gray
        return $null
    }

    Write-Host "  Requesting AI-assisted changelog..." -ForegroundColor Gray

    $commitList = ($Commits | ForEach-Object { "- $_" }) -join "`n"
    $prompt = @"
Analyze these git commits and create a concise, structured changelog in markdown format.

Commits (format: hash|message|author|time):
$commitList

Generate a changelog with these sections (only include sections that have changes):
### ✨ Features
### 🐛 Bug Fixes
### 🔧 Improvements
### 📝 Documentation
### 🧹 Chores

Rules:
- Be concise, use bullet points
- Group related changes
- Use imperative mood (e.g., "Add feature" not "Added feature")
- Omit commit hashes and authors
- Only include meaningful changes
- Maximum 10 items total
"@

    $body = @{
        model = $apiModel
        max_tokens = 1024
        messages = @(@{
            role = "user"
            content = $prompt
        })
    } | ConvertTo-Json -Depth 10

    $headers = @{ "content-type" = "application/json; charset=utf-8" }
    if ($keyHeader) { $headers[$keyHeader] = $apiKey }
    else            { $headers["Authorization"] = "Bearer $apiKey" }

    # Optional provider extras, e.g. a required API-version header:
    #   CHANGELOG_API_HEADERS=some-version: 2023-06-01; x-other: value
    if ($extra) {
        foreach ($pair in $extra -split ';') {
            if ($pair -match '^\s*([^:]+)\s*:\s*(.+?)\s*$') {
                $headers[$matches[1].Trim()] = $matches[2].Trim()
            }
        }
    }

    try {
        $response = Invoke-RestMethod -Uri $apiUrl `
            -Method Post `
            -Headers $headers `
            -Body $body `
            -ErrorAction Stop

        # Accept the common reply shapes rather than binding to one provider.
        $text = $null
        if ($response.content -and $response.content[0].text) { $text = $response.content[0].text }
        elseif ($response.choices -and $response.choices[0].message.content) { $text = $response.choices[0].message.content }
        elseif ($response.output_text) { $text = $response.output_text }

        if (-not $text) {
            Write-Host "  [WARN] Changelog API returned an unrecognised response shape" -ForegroundColor Yellow
            return $null
        }

        Write-Host "  [OK] AI-assisted changelog generated" -ForegroundColor Green
        return $text
    } catch {
        Write-Host "  [WARN] Changelog API call failed: $($_.Exception.Message)" -ForegroundColor Yellow
        return $null
    }
}

function New-FallbackChangelog {
    param([array]$Commits)

    if ($Commits.Count -eq 0) {
        return "## Changes`n`nNo changes since last build."
    }

    $changelogContent = "## Changes`n`n"
    $changelogContent += ($Commits | ForEach-Object {
        $parts = $_ -split '\|'
        "- $($parts[1])"
    }) -join "`n"

    return $changelogContent
}

function Update-HistoricalChangelog {
    param(
        [string]$ProjectRoot,
        [string]$Version,
        [string]$CommitShort,
        [string]$ChangelogContent,
        [string]$Platform
    )

    $changelogFile = Join-Path $ProjectRoot "assets/changelog-$Platform.json"
    $assetsDir = Join-Path $ProjectRoot "assets"

    if (-not (Test-Path $assetsDir)) {
        New-Item -ItemType Directory -Path $assetsDir | Out-Null
    }

    $historicalChangelog = @{ releases = @() }
    if (Test-Path $changelogFile) {
        try {
            $historicalChangelog = Get-Content $changelogFile -Raw | ConvertFrom-Json
            if (-not $historicalChangelog.releases) {
                $historicalChangelog.releases = @()
            }
        } catch {
            $historicalChangelog = @{ releases = @() }
        }
    }

    # Add new release
    $newRelease = @{
        version = $Version
        date = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        changelog = $ChangelogContent
        commit = $CommitShort
    }

    $releases = @($newRelease)
    if ($historicalChangelog.releases -and $historicalChangelog.releases.Count -gt 0) {
        $releases += $historicalChangelog.releases
    }
    $historicalChangelog.releases = $releases

    # Write JSON with proper UTF-8 encoding (without BOM) to preserve emojis
    $jsonContent = $historicalChangelog | ConvertTo-Json -Depth 10
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($changelogFile, $jsonContent, $utf8NoBom)

    Write-Host "  [OK] Updated $changelogFile" -ForegroundColor Green
}

function Save-LastBuildCommit {
    param(
        [string]$ReleaseDir,
        [string]$CommitFull,
        [string]$Platform
    )

    $lastBuildFile = Join-Path $ReleaseDir ".last-build-commit-$Platform"
    $CommitFull | Set-Content $lastBuildFile -NoNewline
}

# ============================================================================
# Main Execution
# ============================================================================

if ($WatermarkOnly) {
    Save-LastBuildCommit -ReleaseDir $ReleaseDir -CommitFull $CommitFull -Platform $Platform
    Write-Host "[OK] Changelog watermark advanced for $Platform" -ForegroundColor Green

    return @{
        Success = $true
        ChangelogMarkdown = ""
        CommitCount = 0
    }
}

Write-Host "Generating AI-powered changelog for $Platform..." -ForegroundColor Yellow

try {
    # Get commits since last build
    $lastTag = $Tag
    $commitData = Get-CommitsSinceLastBuild -ReleaseDir $ReleaseDir -LastTag $lastTag -Platform $Platform

    if ($commitData.Commits -and $commitData.Commits.Count -gt 0) {
        Write-Host "  Analyzing $($commitData.Commits.Count) commits..." -ForegroundColor Gray

        # Try the optional AI-assisted changelog first
        $changelogContent = Invoke-AiChangelogGeneration -ProjectRoot $ProjectRoot -Commits $commitData.Commits

        # Fallback to simple changelog if API failed
        if (-not $changelogContent) {
            $changelogContent = New-FallbackChangelog -Commits $commitData.Commits
        }
    } else {
        Write-Host "  No new commits to analyze" -ForegroundColor DarkGray
        $changelogContent = "## Changes`n`nNo changes since last build."
    }

    # Update historical changelog
    Update-HistoricalChangelog -ProjectRoot $ProjectRoot -Version $Version -CommitShort $CommitShort -ChangelogContent $changelogContent -Platform $Platform

    # Save current commit as last build
    if (-not $SkipWatermark) {
        Save-LastBuildCommit -ReleaseDir $ReleaseDir -CommitFull $CommitFull -Platform $Platform
    }

    Write-Host "[OK] Changelog generation complete" -ForegroundColor Green

    # Validate changelog was generated
    if (-not $changelogContent -or $changelogContent.Length -lt 10) {
        Write-Host "[ERROR] Changelog generation produced invalid content" -ForegroundColor Red
        throw "Invalid changelog content"
    }

    # Return changelog content
    return @{
        Success = $true
        ChangelogMarkdown = $changelogContent
        CommitCount = if ($commitData.Commits) { $commitData.Commits.Count } else { 0 }
    }

} catch {
    Write-Host "[ERROR] Changelog generation failed: $($_.Exception.Message)" -ForegroundColor Red
    throw "Changelog generation failed: $($_.Exception.Message)"
}
