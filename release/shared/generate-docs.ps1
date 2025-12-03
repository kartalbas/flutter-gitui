#!/usr/bin/env pwsh
# ============================================================================
# Documentation Generation Module
# ============================================================================
# Generates comprehensive README.md and optional PDF documentation
# BUILD-STEP: 9
#
# PDF GENERATION REQUIREMENTS (Optional):
# ----------------------------------------
# Windows:
#   - Pandoc: scoop install pandoc (or winget install JohnMacFarlane.Pandoc)
#   - LaTeX:  scoop install latex  (or winget install MiKTeX.MiKTeX)
#
# Linux (pre-installed in Docker build image):
#   - Ubuntu/Debian: apt-get install pandoc texlive-latex-base texlive-xetex
#   - Fedora/RHEL:   dnf install pandoc texlive-scheme-basic texlive-xetex
#   - Arch:          pacman -S pandoc texlive-core
#
# macOS:
#   - Pandoc: brew install pandoc
#   - LaTeX:  brew install basictex (lightweight) or mactex-no-gui (full)
#
# NOTE: PDF generation is optional. Build will succeed without it.
# ============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ReleaseDir,

    [Parameter(Mandatory=$true)]
    [string]$Version,

    [Parameter(Mandatory=$true)]
    [string]$CommitShort,

    [Parameter(Mandatory=$true)]
    [string]$ChangelogContent,

    [Parameter(Mandatory=$true)]
    [hashtable]$BuildInfo,

    [Parameter(Mandatory=$false)]
    [ValidateSet('windows', 'linux', 'macos')]
    [string]$Platform = 'windows'
)

function New-ReadmeContent {
    param(
        [string]$Version,
        [string]$CommitShort,
        [string]$ChangelogContent,
        [hashtable]$BuildInfo,
        [string]$Platform
    )

    $platformName = $Platform.Substring(0,1).ToUpper() + $Platform.Substring(1)
    $buildSize = if ($Platform -eq 'windows') { $BuildInfo.WindowsSizeMB } else { $BuildInfo.LinuxSizeMB }

    if ($Platform -eq 'windows') {
        $readme = @"
# Flutter GitUI - $platformName Release

**Version:** $Version
**Commit:** $CommitShort
**Built:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Platform:** $platformName
**Size:** $([math]::Round($buildSize, 2)) MB

---

$ChangelogContent

---

## Package Structure

``````
flutter-gitui/
├── windows/                 # Windows binaries
│   ├── flutter_gitui.exe    # Main application
│   ├── *.dll                # Required libraries
│   └── data/                # Application data files
├── Updater.exe              # Auto-updater
└── README.md                # This file
``````

---

## How to Run

1. Extract the archive to your preferred location
2. Navigate to the ``windows`` folder
3. Double-click ``flutter_gitui.exe``

---

## System Requirements

- Windows 10 or later (x64)
- Git must be installed and available in PATH

---

## Configuration

Settings are stored in: ``%USERPROFILE%\.flutter-gitui\config.yaml``

---

## Build Information

- **Build Time:** $($BuildInfo.WindowsBuildTimeSec)s

---

**Developer:** Mehmet Kartalbas
**Contact:** kartalbas@gmail.com
"@
    } else {
        $readme = @"
# Flutter GitUI - $platformName Release

**Version:** $Version
**Commit:** $CommitShort
**Built:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Platform:** $platformName
**Size:** $([math]::Round($buildSize, 2)) MB

---

$ChangelogContent

---

## Package Structure

``````
flutter-gitui/
├── flutter-gitui            # Main executable
├── linux/                   # Linux binaries
│   ├── flutter_gitui        # Application binary
│   ├── lib/                 # Required libraries
│   └── data/                # Application data files
├── updater                  # Auto-updater
└── README.md                # This file
``````

---

## How to Run

1. Extract the archive to your preferred location
2. Make executable: ``chmod +x flutter-gitui``
3. Run: ``./flutter-gitui``

---

## System Requirements

- Linux with GTK 3.0+
- Git must be installed and available in PATH

---

## Configuration

Settings are stored in: ``~/.flutter-gitui/config.yaml``

---

## Build Information

- **Build Time:** $($BuildInfo.LinuxBuildTimeSec)s

---

**Developer:** Mehmet Kartalbas
**Contact:** kartalbas@gmail.com
"@
    }

    return $readme
}

function New-Pdf {
    param([string]$ReleaseDir)

    Write-Host "  Attempting to generate PDF from README..." -ForegroundColor Cyan

    $pandocAvailable = Get-Command pandoc -ErrorAction SilentlyContinue
    if (-not $pandocAvailable) {
        Write-Host "  [INFO] PDF generation skipped - pandoc not installed" -ForegroundColor Cyan
        Write-Host "  Install: scoop install pandoc  (or see release/README.md for other options)" -ForegroundColor DarkGray
        return $false
    }

    $readmePath = "$ReleaseDir/README.md"
    $pdfPath = "$ReleaseDir/README.pdf"

    # Try to find xelatex (check common installation paths)
    $xelatexPaths = @(
        "xelatex",  # Try PATH first
        "D:\bin\scoop\apps\latex\current\texmfs\install\miktex\bin\x64\xelatex.exe",  # Scoop install
        "$env:LOCALAPPDATA\Programs\MiKTeX\miktex\bin\x64\xelatex.exe",  # Standard MiKTeX install
        "$env:ProgramFiles\MiKTeX\miktex\bin\x64\xelatex.exe"  # System-wide install
    )

    # Try xelatex first (best quality)
    foreach ($xelatexPath in $xelatexPaths) {
        try {
            & pandoc $readmePath -o $pdfPath --pdf-engine=$xelatexPath -V geometry:margin=1in 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  [OK] README.pdf generated" -ForegroundColor Green
                return $true
            }
        } catch {}
    }

    # Fallback to pdflatex
    $pdflatexPaths = @(
        "pdflatex",  # Try PATH first
        "D:\bin\scoop\apps\latex\current\texmfs\install\miktex\bin\x64\pdflatex.exe",  # Scoop install
        "$env:LOCALAPPDATA\Programs\MiKTeX\miktex\bin\x64\pdflatex.exe",  # Standard MiKTeX install
        "$env:ProgramFiles\MiKTeX\miktex\bin\x64\pdflatex.exe"  # System-wide install
    )

    foreach ($pdflatexPath in $pdflatexPaths) {
        try {
            & pandoc $readmePath -o $pdfPath --pdf-engine=$pdflatexPath -V geometry:margin=1in 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  [OK] README.pdf generated" -ForegroundColor Green
                return $true
            }
        } catch {}
    }

    Write-Host "  [INFO] PDF generation skipped - no PDF engine available" -ForegroundColor Cyan
    Write-Host "  Install LaTeX: scoop install latex  (or see release/README.md for other options)" -ForegroundColor DarkGray
    Write-Host "  Note: You may need to restart your terminal after installation" -ForegroundColor DarkGray
    return $false
}

# ============================================================================
# Main Execution
# ============================================================================

Write-Host "Generating documentation..." -ForegroundColor Yellow

try {
    $readmeContent = New-ReadmeContent `
        -Version $Version `
        -CommitShort $CommitShort `
        -ChangelogContent $ChangelogContent `
        -BuildInfo $BuildInfo `
        -Platform $Platform

    if (-not $readmeContent -or $readmeContent.Length -lt 50) {
        throw "README content is invalid or too short"
    }

    $readmePath = "$ReleaseDir/README.md"
    $readmeContent | Out-File -FilePath $readmePath -Encoding UTF8

    if (-not (Test-Path $readmePath)) {
        throw "README file was not created"
    }

    Write-Host "[OK] README generated" -ForegroundColor Green

    $pdfSuccess = New-Pdf -ReleaseDir $ReleaseDir

    return @{
        Success = $true
        ReadmeGenerated = $true
        PdfGenerated = $pdfSuccess
    }

} catch {
    Write-Host "[ERROR] Documentation generation failed: $($_.Exception.Message)" -ForegroundColor Red
    throw "Documentation generation failed - cannot release without README"
}
