#!/usr/bin/env pwsh
<#
.SYNOPSIS
    GHCR Authentication and Upload Troubleshooter

.DESCRIPTION
    This script helps diagnose and fix common GitHub Container Registry (GHCR) upload issues.

.PARAMETER GitHubUsername
    Your GitHub username

.EXAMPLE
    .\ghcr-troubleshoot.ps1 -GitHubUsername "knappmi"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubUsername
)

$IMAGE_NAME = "observability-demo-app"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   GHCR Troubleshooter" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "GitHub Username: $GitHubUsername" -ForegroundColor White
Write-Host "Target: ghcr.io/$GitHubUsername/$IMAGE_NAME" -ForegroundColor White
Write-Host ""

# Step 1: Check current authentication
Write-Host "[1] Checking current authentication status..." -ForegroundColor Green

$dockerConfig = "$env:USERPROFILE\.docker\config.json"
$isGHCRAuthenticated = $false

if (Test-Path $dockerConfig) {
    $config = Get-Content $dockerConfig | ConvertFrom-Json
    if ($config.auths -and $config.auths."ghcr.io") {
        Write-Host "✅ GHCR authentication found" -ForegroundColor Green
        $isGHCRAuthenticated = $true
    } else {
        Write-Host "❌ GHCR authentication NOT found" -ForegroundColor Red
    }
} else {
    Write-Host "❌ No Docker config found" -ForegroundColor Red
}

# Step 2: Test GHCR connectivity
Write-Host ""
Write-Host "[2] Testing GHCR connectivity..." -ForegroundColor Green

try {
    $response = Invoke-WebRequest -Uri "https://ghcr.io/v2/" -UseBasicParsing -TimeoutSec 10
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ GHCR is accessible" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ Cannot reach GHCR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Check your internet connection and proxy settings" -ForegroundColor Yellow
}

# Step 3: Check if image exists locally
Write-Host ""
Write-Host "[3] Checking local image..." -ForegroundColor Green

$localImages = docker images --format "table {{.Repository}}:{{.Tag}}" | Select-String $IMAGE_NAME
if ($localImages) {
    Write-Host "✅ Local images found:" -ForegroundColor Green
    $localImages | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
} else {
    Write-Host "❌ No local images found for $IMAGE_NAME" -ForegroundColor Red
    Write-Host "You need to build the image first:" -ForegroundColor Yellow
    Write-Host "  docker build -f Dockerfile.production -t $IMAGE_NAME:latest ." -ForegroundColor Gray
}

# Step 4: Provide setup instructions
Write-Host ""
Write-Host "[4] GHCR Setup Instructions..." -ForegroundColor Green

if (-not $isGHCRAuthenticated) {
    Write-Host ""
    Write-Host "You need to authenticate with GHCR first:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Create a GitHub Personal Access Token:" -ForegroundColor White
    Write-Host "   - Go to: https://github.com/settings/tokens" -ForegroundColor Gray
    Write-Host "   - Click 'Generate new token (classic)'" -ForegroundColor Gray
    Write-Host "   - Select these permissions:" -ForegroundColor Gray
    Write-Host "     ✅ write:packages" -ForegroundColor Gray
    Write-Host "     ✅ read:packages" -ForegroundColor Gray
    Write-Host "   - Copy the token (starts with 'ghp_')" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Login to GHCR:" -ForegroundColor White
    Write-Host "   docker login ghcr.io -u $GitHubUsername" -ForegroundColor Gray
    Write-Host "   (Use your GitHub username and the token as password)" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host "✅ GHCR authentication is ready!" -ForegroundColor Green
}

# Step 5: Commands to fix common issues
Write-Host ""
Write-Host "[5] Common Fixes..." -ForegroundColor Green
Write-Host ""

Write-Host "If you get 'unauthorized' errors:" -ForegroundColor Yellow
Write-Host "  - Check your token has 'write:packages' permission" -ForegroundColor Gray
Write-Host "  - Make sure you're using your GitHub username (not email)" -ForegroundColor Gray
Write-Host "  - Verify the token isn't expired" -ForegroundColor Gray
Write-Host ""

Write-Host "If you get 'repository does not exist' errors:" -ForegroundColor Yellow
Write-Host "  - First push creates the repository automatically" -ForegroundColor Gray
Write-Host "  - Make sure the image name is lowercase" -ForegroundColor Gray
Write-Host "  - Check the namespace matches your username" -ForegroundColor Gray
Write-Host ""

Write-Host "If you get 'denied' errors:" -ForegroundColor Yellow
Write-Host "  - Re-generate your token with correct permissions" -ForegroundColor Gray
Write-Host "  - Make sure you're logged into the correct account" -ForegroundColor Gray
Write-Host ""

# Step 6: Ready-to-run commands
Write-Host ""
Write-Host "[6] Ready-to-run commands..." -ForegroundColor Green
Write-Host ""

Write-Host "After authentication, use these commands:" -ForegroundColor White
Write-Host ""
Write-Host "Build the image (if not done):" -ForegroundColor Yellow
Write-Host "  docker build -f Dockerfile.production -t $IMAGE_NAME:latest ." -ForegroundColor Gray
Write-Host ""
Write-Host "Tag and push to GHCR:" -ForegroundColor Yellow
Write-Host "  docker tag $IMAGE_NAME`:latest ghcr.io/$GitHubUsername/$IMAGE_NAME`:latest" -ForegroundColor Gray
Write-Host "  docker push ghcr.io/$GitHubUsername/$IMAGE_NAME`:latest" -ForegroundColor Gray
Write-Host ""
Write-Host "Or use the automated script:" -ForegroundColor Yellow
Write-Host "  .\publish-to-registries.ps1 -GitHubUsername '$GitHubUsername' -Version '1.0.0' -SkipDockerHub" -ForegroundColor Gray

Write-Host ""
Write-Host "Troubleshooting complete!" -ForegroundColor Cyan
Write-Host "Follow the instructions above to resolve GHCR upload issues." -ForegroundColor White
