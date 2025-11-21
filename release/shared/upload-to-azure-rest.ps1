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

# Azure Blob Storage configuration
$containerName = "releases"
$blobName = $fileName
$blobUrl = "https://$storageAccountName.blob.core.windows.net/$containerName/$blobName"

Write-Host "Uploading to: $blobUrl" -ForegroundColor Yellow
Write-Host ""

try {
    # Read file as bytes
    Write-Host "Reading file..." -ForegroundColor Gray
    $fileBytes = [System.IO.File]::ReadAllBytes($localFile)
    $contentLength = $fileBytes.Length

    # Prepare request
    $date = [DateTime]::UtcNow.ToString('R')
    $version = '2021-06-08'

    # Build canonical string for authorization
    $canonicalizedHeaders = "x-ms-blob-type:BlockBlob`nx-ms-date:$date`nx-ms-version:$version"
    $canonicalizedResource = "/$storageAccountName/$containerName/$blobName"

    $stringToSign = "PUT`n`n`n$contentLength`n`n`n`n`n`n`n`n`n$canonicalizedHeaders`n$canonicalizedResource"

    # Compute signature
    Write-Host "Computing signature..." -ForegroundColor Gray
    $hmacsha = New-Object System.Security.Cryptography.HMACSHA256
    $hmacsha.Key = [Convert]::FromBase64String($accountKey)
    $signature = [Convert]::ToBase64String($hmacsha.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign)))

    $authHeader = "SharedKey $($storageAccountName):$signature"

    # Prepare headers
    $headers = @{
        'x-ms-date' = $date
        'x-ms-version' = $version
        'x-ms-blob-type' = 'BlockBlob'
        'Authorization' = $authHeader
        'Content-Length' = $contentLength.ToString()
    }

    # Upload blob
    Write-Host "Uploading $fileSizeMB MB..." -ForegroundColor Yellow
    $uploadStart = Get-Date

    $response = Invoke-RestMethod -Uri $blobUrl -Method Put -Headers $headers -Body $fileBytes -ErrorAction Stop

    $uploadTime = (Get-Date) - $uploadStart
    Write-Host ""
    Write-Host "[OK] Successfully uploaded to Azure Blob Storage!" -ForegroundColor Green
    Write-Host "  Upload time: $($uploadTime.TotalSeconds.ToString('0.0'))s" -ForegroundColor Gray
    Write-Host "  Download URL: $blobUrl" -ForegroundColor Cyan
    Write-Host ""

} catch {
    Write-Host ""
    Write-Host "[ERROR] Upload failed: $($_.Exception.Message)" -ForegroundColor Red

    if ($_.Exception.Response) {
        try {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            Write-Host "Response: $responseBody" -ForegroundColor Gray
        } catch {
            # Ignore errors reading response
        }
    }

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
