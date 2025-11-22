#!/usr/bin/env pwsh
# ============================================================================
# Azure Blob Storage Upload Script (Pure REST API)
# ============================================================================
# Uploads release archive to Azure Blob Storage using REST API
# Requires FLUTTERGITUIARTIFACTS_CONNECTION_STRING in .env file
# BUILD-STEP: 11
# ============================================================================

param(
    [Parameter(Mandatory=$false)]
    [string]$FilePath
)

$ErrorActionPreference = "Stop"

# Path handling
$scriptDir = $PSScriptRoot
$releaseRootDir = Split-Path -Parent $scriptDir
$projectRoot = Split-Path -Parent $releaseRootDir

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Azure Blob Storage Upload (REST API)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Load connection string from .env file
$envPath = Join-Path $projectRoot ".env"
$connectionString = $null
if (Test-Path $envPath) {
    Get-Content $envPath | ForEach-Object {
        if ($_ -match '^FLUTTERGITUIARTIFACTS_CONNECTION_STRING=(.+)$') {
            $connectionString = $matches[1].Trim()
        }
    }
}

# Try environment variable if not in .env
if (-not $connectionString) {
    $connectionString = $env:FLUTTERGITUIARTIFACTS_CONNECTION_STRING
}

if (-not $connectionString) {
    Write-Host "[ERROR] FLUTTERGITUIARTIFACTS_CONNECTION_STRING not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please add to .env file:" -ForegroundColor Yellow
    Write-Host '  FLUTTERGITUIARTIFACTS_CONNECTION_STRING=DefaultEndpointsProtocol=https;AccountName=fluttergituiartifacts;AccountKey=YOUR_KEY;EndpointSuffix=core.windows.net' -ForegroundColor Gray
    Write-Host ""
    Write-Host "Get your connection string from:" -ForegroundColor Yellow
    Write-Host "  Azure Portal -> Storage Accounts -> fluttergituiartifacts -> Access keys" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

# Parse connection string
$storageAccountName = $null
$accountKey = $null

$connectionString -split ';' | ForEach-Object {
    if ($_ -match '^AccountName=(.+)$') {
        $storageAccountName = $matches[1]
    }
    if ($_ -match '^AccountKey=(.+)$') {
        $accountKey = $matches[1]
    }
}

if (-not $storageAccountName -or -not $accountKey) {
    Write-Host "[ERROR] Invalid connection string format" -ForegroundColor Red
    exit 1
}

Write-Host "Storage Account: $storageAccountName" -ForegroundColor Green
Write-Host ""

# Determine file to upload
if ($FilePath) {
    $localFile = $FilePath
} else {
    # Find most recent zip in artifacts folder
    $artifactsDir = Join-Path $releaseRootDir "artifacts"
    $releaseFiles = Get-ChildItem -Path $artifactsDir -Filter "flutter-gitui-*.zip" -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    if ($releaseFiles.Count -eq 0) {
        Write-Host "[ERROR] No release file found in release/artifacts/ folder" -ForegroundColor Red
        Write-Host "Run a platform-specific build script first or specify file with -FilePath" -ForegroundColor Yellow
        exit 1
    }
    $localFile = $releaseFiles[0].FullName
}

if (-not (Test-Path $localFile)) {
    Write-Host "[ERROR] File not found: $localFile" -ForegroundColor Red
    exit 1
}

$fileName = Split-Path -Leaf $localFile
$fileSize = (Get-Item $localFile).Length
$fileSizeMB = [math]::Round($fileSize / 1MB, 2)

Write-Host "File: $fileName" -ForegroundColor Gray
Write-Host "Size: $fileSizeMB MB" -ForegroundColor Gray
Write-Host ""

# Find corresponding manifest JSON file
$fileDir = Split-Path -Parent $localFile
if ($fileName -match 'windows') {
    $manifestFile = Join-Path $fileDir "latest-windows.json"
} elseif ($fileName -match 'linux') {
    $manifestFile = Join-Path $fileDir "latest-linux.json"
} elseif ($fileName -match 'macos') {
    $manifestFile = Join-Path $fileDir "latest-macos.json"
} else {
    $manifestFile = $null
}

# Azure Blob Storage configuration
$containerName = "releases"

# Function to upload a file
function Upload-ToAzureBlob {
    param(
        [string]$LocalFilePath,
        [string]$BlobName,
        [string]$StorageAccount,
        [string]$Key,
        [string]$Container
    )

    $blobUrl = "https://$StorageAccount.blob.core.windows.net/$Container/$BlobName"
    $fileBytes = [System.IO.File]::ReadAllBytes($LocalFilePath)
    $contentLength = $fileBytes.Length

    $date = [DateTime]::UtcNow.ToString('R')
    $version = '2021-06-08'

    $canonicalizedHeaders = "x-ms-blob-type:BlockBlob`nx-ms-date:$date`nx-ms-version:$version"
    $canonicalizedResource = "/$StorageAccount/$Container/$BlobName"
    $stringToSign = "PUT`n`n`n$contentLength`n`n`n`n`n`n`n`n`n$canonicalizedHeaders`n$canonicalizedResource"

    $hmacsha = New-Object System.Security.Cryptography.HMACSHA256
    $hmacsha.Key = [Convert]::FromBase64String($Key)
    $signature = [Convert]::ToBase64String($hmacsha.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign)))

    $headers = @{
        'x-ms-date' = $date
        'x-ms-version' = $version
        'x-ms-blob-type' = 'BlockBlob'
        'Authorization' = "SharedKey $($StorageAccount):$signature"
        'Content-Length' = $contentLength.ToString()
    }

    Invoke-RestMethod -Uri $blobUrl -Method Put -Headers $headers -Body $fileBytes -ErrorAction Stop
    return $blobUrl
}

try {
    # Upload ZIP archive
    Write-Host "Uploading $fileName ($fileSizeMB MB)..." -ForegroundColor Yellow
    $uploadStart = Get-Date

    $blobUrl = Upload-ToAzureBlob -LocalFilePath $localFile -BlobName $fileName -StorageAccount $storageAccountName -Key $accountKey -Container $containerName

    $uploadTime = (Get-Date) - $uploadStart
    Write-Host "[OK] Archive uploaded ($($uploadTime.TotalSeconds.ToString('0.0'))s)" -ForegroundColor Green
    Write-Host "  URL: $blobUrl" -ForegroundColor Cyan

    # Upload manifest JSON if exists
    if ($manifestFile -and (Test-Path $manifestFile)) {
        $manifestName = Split-Path -Leaf $manifestFile
        Write-Host ""
        Write-Host "Uploading $manifestName..." -ForegroundColor Yellow

        $manifestUrl = Upload-ToAzureBlob -LocalFilePath $manifestFile -BlobName $manifestName -StorageAccount $storageAccountName -Key $accountKey -Container $containerName

        Write-Host "[OK] Manifest uploaded" -ForegroundColor Green
        Write-Host "  URL: $manifestUrl" -ForegroundColor Cyan
    }

    Write-Host ""

} catch {
    Write-Host ""
    Write-Host "[ERROR] Upload failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Verify connection string in .env file" -ForegroundColor Gray
    Write-Host "  2. Ensure container 'releases' exists in storage account" -ForegroundColor Gray
    Write-Host "  3. Check storage account access permissions" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Upload completed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
exit 0
