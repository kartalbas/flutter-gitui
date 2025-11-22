#!/usr/bin/env pwsh
# ============================================================================
# Windows Build Module
# ============================================================================
# Handles Windows Flutter build, updater compilation, and artifact copying
# BUILD-STEP: 6
# ============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectRoot,

    [Parameter(Mandatory=$true)]
    [string]$ReleaseDir,

    [Parameter(Mandatory=$true)]
    [string]$UpdaterDir,

    [Parameter(Mandatory=$true)]
    [string]$Version,

    [Parameter(Mandatory=$false)]
    [string]$LogFile
)

function Invoke-WindowsBuild {
    param(
        [string]$ProjectRoot,
        [string]$LogFile
    )

    Write-Host "  [Windows] Building..." -ForegroundColor Cyan

    # Log header
    if ($LogFile) {
        "=== Flutter build windows --release ===" | Add-Content $LogFile -Encoding ASCII
        "Build started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content $LogFile -Encoding ASCII
        "Working directory: $ProjectRoot" | Add-Content $LogFile -Encoding ASCII
        "Flutter version:" | Add-Content $LogFile -Encoding ASCII
        flutter --version 2>&1 | Add-Content $LogFile -Encoding ASCII
        "" | Add-Content $LogFile -Encoding ASCII
        "Plugin symlinks:" | Add-Content $LogFile -Encoding ASCII
        Get-ChildItem "$ProjectRoot/windows/flutter/ephemeral/.plugin_symlinks" 2>&1 | Add-Content $LogFile -Encoding ASCII
        "" | Add-Content $LogFile -Encoding ASCII
        "=== BUILD OUTPUT (VERBOSE) ===" | Add-Content $LogFile -Encoding ASCII
    }

    $startTime = Get-Date
    Push-Location $ProjectRoot

    # Run Windows build with VERBOSE logging
    $lineCount = 0
    flutter build windows --release --verbose 2>&1 | ForEach-Object {
        $line = $_.ToString()
        $lineCount++

        # ALL output goes to log file
        if ($LogFile) {
            Add-Content $LogFile -Value $line -Encoding ASCII
        }

        # Only important lines to console (filtered for readability)
        if ($line -match "error|fail|success|building|compiling" -or $lineCount % 50 -eq 0) {
            Write-Host "  [Win] $line" -ForegroundColor Cyan
        }
    }

    if ($LogFile) {
        "" | Add-Content $LogFile -Encoding ASCII
        "Build completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content $LogFile -Encoding ASCII
        "Exit code: $LASTEXITCODE" | Add-Content $LogFile -Encoding ASCII
    }

    $buildTime = (Get-Date) - $startTime
    $success = ($LASTEXITCODE -eq 0)

    Pop-Location

    return @{
        Success = $success
        BuildTime = $buildTime
        ExitCode = $LASTEXITCODE
    }
}

function Build-Updater {
    param(
        [string]$UpdaterDir
    )

    Write-Host "  [Windows] Compiling updater..." -ForegroundColor Gray
    Push-Location $UpdaterDir

    try {
        # Get dependencies
        dart pub get *> $null

        # Compile to native executable
        dart compile exe updater.dart -o updater.exe 2>&1 | Out-Null

        if (Test-Path "updater.exe") {
            Write-Host "    ✓ Updater compiled successfully" -ForegroundColor Green
            Pop-Location
            return @{
                Success = $true
                Path = Join-Path $UpdaterDir "updater.exe"
            }
        } else {
            Write-Host "    ! Failed to compile updater.exe" -ForegroundColor Yellow
            Pop-Location
            return @{
                Success = $false
                Path = $null
            }
        }
    } catch {
        Write-Host "    ! Error compiling updater: $($_.Exception.Message)" -ForegroundColor Yellow
        Pop-Location
        return @{
            Success = $false
            Path = $null
        }
    }
}

function Copy-WindowsArtifacts {
    param(
        [string]$ProjectRoot,
        [string]$ReleaseDir,
        [string]$UpdaterPath
    )

    Write-Host "  [Windows] Copying binaries..." -ForegroundColor Gray

    $windowsBuildPath = Join-Path $ProjectRoot "build/windows/x64/runner/Release"

    # Copy main binaries
    Copy-Item "$windowsBuildPath/*.exe" $ReleaseDir -Force
    Copy-Item "$windowsBuildPath/*.dll" $ReleaseDir -Force

    # Copy updater.exe if it was compiled successfully
    if ($UpdaterPath -and (Test-Path $UpdaterPath)) {
        Copy-Item $UpdaterPath $ReleaseDir -Force
        Write-Host "    ✓ Updater.exe copied to release" -ForegroundColor Green
    }

    Write-Host "  [Windows] Copying data files..." -ForegroundColor Gray
    Copy-Item "$windowsBuildPath/data" "$ReleaseDir/" -Recurse -Force

    $windowsSize = (Get-ChildItem "$ReleaseDir" -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB

    return @{
        SizeMB = $windowsSize
    }
}

# ============================================================================
# Main Execution
# ============================================================================

Write-Host "Building Windows binaries..." -ForegroundColor Yellow

try {
    # Build Windows
    $buildResult = Invoke-WindowsBuild -ProjectRoot $ProjectRoot -LogFile $LogFile

    if (-not $buildResult.Success) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "WINDOWS BUILD FAILED" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "Build time: $($buildResult.BuildTime.TotalSeconds.ToString('0.0'))s" -ForegroundColor Yellow
        if ($LogFile) {
            Write-Host "Log file: $LogFile" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Last 30 lines of build output:" -ForegroundColor Yellow
            Write-Host "----------------------------------------" -ForegroundColor Gray
            Get-Content $LogFile -Tail 30 | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
            Write-Host "----------------------------------------" -ForegroundColor Gray
        }
        throw "Windows build failed with exit code $($buildResult.ExitCode)"
    }

    # Compile updater
    $updaterResult = Build-Updater -UpdaterDir $UpdaterDir

    # Copy artifacts
    $artifactInfo = Copy-WindowsArtifacts -ProjectRoot $ProjectRoot -ReleaseDir $ReleaseDir -UpdaterPath $updaterResult.Path

    Write-Host "[OK] Windows build succeeded ($($buildResult.BuildTime.TotalSeconds.ToString('0.0'))s)" -ForegroundColor Green

    return @{
        Success = $true
        BuildTime = $buildResult.BuildTime
        SizeMB = $artifactInfo.SizeMB
        UpdaterCompiled = $updaterResult.Success
    }

} catch {
    return @{
        Success = $false
        Error = $_.Exception.Message
    }
}
