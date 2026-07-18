#!/usr/bin/env pwsh
# ============================================================================
# Linux Build Module
# ============================================================================
# Handles Linux Flutter build using Docker containers
# BUILD-STEP: 5 (check) / 7 (build)
# ============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectRoot,

    [Parameter(Mandatory=$true)]
    [string]$ReleaseDir,

    [Parameter(Mandatory=$true)]
    [string]$DockerDir,

    [Parameter(Mandatory=$true)]
    [string]$Version,

    [Parameter(Mandatory=$false)]
    [string]$LogFile,

    [Parameter(Mandatory=$false)]
    [switch]$CheckOnly = $false
)

function Test-LinuxBuildPrerequisites {
    param(
        [string]$DockerDir
    )

    Write-Host "  Checking Linux build prerequisites..." -ForegroundColor Gray

    if (-not (Test-Path "$DockerDir/Dockerfile.linux-base")) {
        Write-Host "  [SKIP] $DockerDir/Dockerfile.linux-base not found" -ForegroundColor Yellow
        return $false
    }

    if (-not (Test-Path "$DockerDir/Dockerfile.linux-build")) {
        Write-Host "  [SKIP] $DockerDir/Dockerfile.linux-build not found" -ForegroundColor Yellow
        return $false
    }

    Write-Host "  [OK] Dockerfiles found" -ForegroundColor Green

    # Check if base image exists
    $baseImageExists = docker images -q flutter-gitui-linux-base:latest 2>$null

    if (-not $baseImageExists) {
        Write-Host "  [Docker] Building base image (one-time, ~2-3 minutes)..." -ForegroundColor Gray
        Push-Location $ProjectRoot
        docker build --progress=plain -t flutter-gitui-linux-base:latest -f $DockerDir/Dockerfile.linux-base . 2>&1 | ForEach-Object {
            Write-Host "    $_" -ForegroundColor DarkGray
        }
        Pop-Location

        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [Docker] Base image built successfully" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  [Docker] Base image build failed" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "  [OK] Base image exists" -ForegroundColor Green
    }

    # Build builder image
    Write-Host "  [Docker] Building builder image..." -ForegroundColor Gray
    $prevErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    Push-Location $ProjectRoot
    docker build --progress=plain -t flutter-linux-builder -f $DockerDir/Dockerfile.linux-build . 2>&1 | Out-Null
    $dockerExitCode = $LASTEXITCODE
    Pop-Location
    $ErrorActionPreference = $prevErrorAction

    if ($dockerExitCode -eq 0) {
        Write-Host "  [OK] Builder image ready" -ForegroundColor Green
        return $true
    } else {
        Write-Host "  [Docker] Builder image build failed" -ForegroundColor Red
        return $false
    }
}

function Invoke-LinuxBuild {
    param(
        [string]$ProjectRoot,
        [string]$LogFile
    )

    if ($LogFile) {
        '' | Out-File $LogFile -Encoding ASCII -NoNewline
        '=== Docker build ===' | Add-Content $LogFile -Encoding ASCII
        "Build started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content $LogFile -Encoding ASCII
        "Docker image: flutter-linux-builder" | Add-Content $LogFile -Encoding ASCII
        "" | Add-Content $LogFile -Encoding ASCII
        "=== DOCKER OUTPUT (COMPLETE) ===" | Add-Content $LogFile -Encoding ASCII
    }

    $startTime = Get-Date

    # Run docker build (isolated - no volume mounts)
    $containerName = "flutter-linux-build-$(Get-Random)"
    Push-Location $ProjectRoot

    docker run --name $containerName flutter-linux-builder 2>&1 | ForEach-Object {
        $line = $_.ToString()
        if ($LogFile) {
            Add-Content $LogFile -Value $line -Encoding ASCII
        }
        Write-Host "  [Lnx] $line" -ForegroundColor Green
    }

    $buildExitCode = $LASTEXITCODE

    if ($LogFile) {
        "" | Add-Content $LogFile -Encoding ASCII
        "Build completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content $LogFile -Encoding ASCII
        "Exit code: $buildExitCode" | Add-Content $LogFile -Encoding ASCII
    }

    # Copy build artifacts out of container
    if ($buildExitCode -eq 0) {
        Write-Host "  [Linux] Copying build artifacts from container..." -ForegroundColor Gray
        docker cp "${containerName}:/app/build" $ProjectRoot 2>&1 | Out-Null
    }

    # Clean up container
    docker rm $containerName 2>&1 | Out-Null
    Pop-Location

    $buildTime = (Get-Date) - $startTime

    return @{
        Success = ($buildExitCode -eq 0)
        BuildTime = $buildTime
        ExitCode = $buildExitCode
        ContainerName = $containerName
    }
}

function Copy-LinuxArtifacts {
    param(
        [string]$ProjectRoot,
        [string]$ReleaseDir
    )

    Write-Host "  [Linux] Copying organized build output..." -ForegroundColor Gray

    $linuxBuildPath = Join-Path $ProjectRoot "build/linux/x64/release/universal"

    # Copy main executable to root
    Copy-Item "$linuxBuildPath/flutter-gitui" "$ReleaseDir/" -Force

    # Copy linux subdirectory with all its contents
    Copy-Item "$linuxBuildPath/linux" "$ReleaseDir/" -Recurse -Force

    $linuxSize = (Get-ChildItem "$ReleaseDir" -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB

    return @{
        SizeMB = $linuxSize
    }
}

# ============================================================================
# Main Execution
# ============================================================================

if ($CheckOnly) {
    # Only check if Linux build is possible
    $ready = Test-LinuxBuildPrerequisites -DockerDir $DockerDir
    return @{
        Ready = $ready
    }
}

Write-Host "Building Linux binaries..." -ForegroundColor Yellow

try {
    # Check prerequisites
    $ready = Test-LinuxBuildPrerequisites -DockerDir $DockerDir

    if (-not $ready) {
        Write-Host "[SKIP] Linux build not available" -ForegroundColor Yellow
        return @{
            Success = $false
            Skipped = $true
            Reason = "Docker not ready"
        }
    }

    # Build Linux
    $buildResult = Invoke-LinuxBuild -ProjectRoot $ProjectRoot -LogFile $LogFile

    if (-not $buildResult.Success) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "LINUX BUILD FAILED" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "Build time: $($buildResult.BuildTime.TotalSeconds.ToString('0.0'))s" -ForegroundColor Yellow
        if ($LogFile) {
            Write-Host "Log file: $LogFile" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Last 30 lines of build output:" -ForegroundColor Yellow
            Write-Host "----------------------------------------" -ForegroundColor Gray
            if (Test-Path $LogFile) {
                Get-Content $LogFile -Tail 30 | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
            }
            Write-Host "----------------------------------------" -ForegroundColor Gray
        }
        throw "Linux build failed with exit code $($buildResult.ExitCode)"
    }

    # Copy artifacts
    $artifactInfo = Copy-LinuxArtifacts -ProjectRoot $ProjectRoot -ReleaseDir $ReleaseDir

    Write-Host "[OK] Linux build succeeded ($($buildResult.BuildTime.TotalSeconds.ToString('0.0'))s)" -ForegroundColor Green

    return @{
        Success = $true
        BuildTime = $buildResult.BuildTime
        SizeMB = $artifactInfo.SizeMB
    }

} catch {
    return @{
        Success = $false
        Skipped = $false
        Error = $_.Exception.Message
    }
}
