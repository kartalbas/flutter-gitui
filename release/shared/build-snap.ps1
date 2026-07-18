#!/usr/bin/env pwsh
# Build snap package using Docker

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    [Parameter(Mandatory=$true)]
    [string]$BundlePath
)

$scriptDir = $PSScriptRoot
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$manifestsDir = Join-Path $projectRoot "release/manifests/snap"
$artifactsDir = Join-Path $projectRoot "release/artifacts"

# Load .env for SNAPCRAFT_STORE_CREDENTIALS
$envFile = Join-Path $projectRoot ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^([^#=]+)=(.*)$') {
            [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim())
        }
    }
    Write-Host "DEBUG: Credentials loaded: $($env:SNAPCRAFT_STORE_CREDENTIALS.Length) chars" -ForegroundColor Cyan
} else {
    Write-Host "DEBUG: .env file not found at: $envFile" -ForegroundColor Red
}

# Create snapcraft.yaml with version
$snapcraftTemplate = Get-Content (Join-Path $manifestsDir "snapcraft.yaml") -Raw
$snapcraftContent = $snapcraftTemplate -replace '\$\{VERSION\}', $Version

$buildDir = Join-Path $env:TEMP "snap-build-$Version"
if (Test-Path $buildDir) { Remove-Item $buildDir -Recurse -Force }
New-Item -ItemType Directory -Path $buildDir -Force | Out-Null

# Validate bundle path exists
if (-not (Test-Path $BundlePath)) {
    Write-Host "[ERROR] Bundle path not found: $BundlePath" -ForegroundColor Red
    exit 1
}

# Copy bundle and create snap/snapcraft.yaml
Copy-Item -Path $BundlePath -Destination (Join-Path $buildDir "bundle") -Recurse

$snapDir = Join-Path $buildDir "snap"
New-Item -ItemType Directory -Path $snapDir -Force | Out-Null
$snapcraftContent | Set-Content (Join-Path $snapDir "snapcraft.yaml")

# Copy desktop file
$desktopSource = Join-Path $manifestsDir "flutter-gitui.desktop"
$desktopDest = Join-Path $buildDir "flutter-gitui.desktop"
if (Test-Path $desktopSource) {
    Copy-Item $desktopSource $desktopDest -Force
    Write-Host "  [OK] Copied desktop file" -ForegroundColor Green
} else {
    Write-Host "  [WARN] Desktop file not found: $desktopSource" -ForegroundColor Yellow
}

# Copy icon (create directory first)
$iconDestDir = Join-Path $buildDir "assets/icons"
New-Item -ItemType Directory -Path $iconDestDir -Force | Out-Null
Copy-Item (Join-Path $projectRoot "assets/icons/app_icon.svg") (Join-Path $iconDestDir "app_icon.svg") -Force

# Build snap builder Docker image
$dockerfileDir = Join-Path $projectRoot "release/docker"
$snapImageName = "flutter-gitui-snap-builder"

Write-Host "Building snap Docker image..." -ForegroundColor Yellow
& docker build -t $snapImageName -f (Join-Path $dockerfileDir "Dockerfile.snap-build") $dockerfileDir
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to build snap Docker image" -ForegroundColor Red
    exit 1
}

Write-Host "Building snap in Docker..." -ForegroundColor Yellow

# Use our custom snap builder image (based on Snapcraft 8.x)
# Note: The image expects the project in /project directory
$dockerArgs = @(
    "run", "--rm",
    "-v", "${buildDir}:/project",
    "-w", "/project",
    $snapImageName
)

& docker @dockerArgs
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Docker snap build failed" -ForegroundColor Red
    exit 1
}

$snapFile = Get-ChildItem -Path $buildDir -Filter "*.snap" | Select-Object -First 1
if ($snapFile) {
    $destPath = Join-Path $artifactsDir "flutter-gitui-v$Version.snap"
    Copy-Item $snapFile.FullName $destPath
    Write-Host "[OK] Snap created: $destPath" -ForegroundColor Green

    # Upload to Snap Store
    if ($env:SNAPCRAFT_STORE_CREDENTIALS) {
        Write-Host "Uploading to Snap Store..." -ForegroundColor Yellow
        Write-Host "DEBUG: Credentials length: $($env:SNAPCRAFT_STORE_CREDENTIALS.Length) chars" -ForegroundColor Cyan

        Write-Host "Snap file: $($snapFile.Name)" -ForegroundColor Gray

        # Upload using Docker with credentials as environment variable
        # Pass SNAPCRAFT_STORE_CREDENTIALS to the container
        $dockerUploadArgs = @(
            "run", "--rm",
            "-e", "SNAPCRAFT_STORE_CREDENTIALS=$env:SNAPCRAFT_STORE_CREDENTIALS",
            "-v", "${buildDir}:/build",
            "-w", "/build",
            $snapImageName,
            "upload", "--release=stable", "/build/$($snapFile.Name)"
        )

        & docker @dockerUploadArgs

        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Snap uploaded to store" -ForegroundColor Green
        } else {
            Write-Host "[ERROR] Snap upload failed" -ForegroundColor Red
            Write-Host "" -ForegroundColor Red
            Write-Host "The credentials may be invalid or the snap name is not registered." -ForegroundColor Yellow
            Write-Host "To upload manually:" -ForegroundColor Yellow
            Write-Host "  snapcraft login" -ForegroundColor Gray
            Write-Host "  snapcraft upload --release=stable $destPath" -ForegroundColor Gray
            Write-Host "" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "[ERROR] SNAPCRAFT_STORE_CREDENTIALS not found in .env" -ForegroundColor Red
        exit 1
    }

    return $destPath
    exit 0
} else {
    Write-Host "[ERROR] Snap build failed" -ForegroundColor Red
    exit 1
}
