#!/usr/bin/env pwsh
<#
.SYNOPSIS
    GHCR Authentication and Upload Troubleshooter

.DESCRIPTION
    This script helps diagnose and fix common GitHub Container Registry (GHCR) upload issues.
    It walks you through authentication, token validation, and common fixes.

.PARAMETER GitHubUsername
    Your GitHub username

.PARAMETER TestOnly
    Only run diagnostics, don't attempt fixes

.EXAMPLE
    .\fix-ghcr-issues.ps1 -GitHubUsername "yourusername"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubUsername,
    
    [switch]$TestOnly
)

$IMAGE_NAME = "observability-demo-app"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   GHCR Troubleshooter & Fixer" -ForegroundColor Cyan
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

# Step 4: Guide through authentication
if (-not $isGHCRAuthenticated -and -not $TestOnly) {
    Write-Host ""
    Write-Host "[4] Setting up GHCR authentication..." -ForegroundColor Green
    
    Write-Host ""
    Write-Host "🔑 You need a GitHub Personal Access Token with these permissions:" -ForegroundColor Yellow
    Write-Host "   ✅ write:packages" -ForegroundColor Gray
    Write-Host "   ✅ read:packages" -ForegroundColor Gray
    Write-Host "   ✅ delete:packages (optional)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "📋 How to create a token:" -ForegroundColor Yellow
    Write-Host "   1. Go to: https://github.com/settings/tokens" -ForegroundColor Gray
    Write-Host "   2. Click 'Generate new token (classic)'" -ForegroundColor Gray
    Write-Host "   3. Select the permissions above" -ForegroundColor Gray
    Write-Host "   4. Copy the token (starts with 'ghp_')" -ForegroundColor Gray
    Write-Host ""
    
    $continue = Read-Host "Do you have a GitHub Personal Access Token ready? (y/n)"
    if ($continue -eq 'y' -or $continue -eq 'Y') {
        Write-Host ""
        Write-Host "🔐 Logging into GHCR..." -ForegroundColor Green
        Write-Host "Username: $GitHubUsername" -ForegroundColor Gray
        Write-Host "Password: [Your GitHub Personal Access Token]" -ForegroundColor Gray
        Write-Host ""
        
        docker login ghcr.io -u $GitHubUsername
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ GHCR login successful!" -ForegroundColor Green
            $isGHCRAuthenticated = $true
        } else {
            Write-Host "❌ GHCR login failed" -ForegroundColor Red
            Write-Host ""
            Write-Host "Common login issues:" -ForegroundColor Yellow
            Write-Host "  - Incorrect username (use your GitHub username, not email)" -ForegroundColor Gray
            Write-Host "  - Token doesn't have 'write:packages' permission" -ForegroundColor Gray
            Write-Host "  - Token is expired" -ForegroundColor Gray
            Write-Host "  - Copy/paste error in token" -ForegroundColor Gray
        }
    }
}

# Step 5: Test upload (if authenticated)
if ($isGHCRAuthenticated -and $localImages -and -not $TestOnly) {
    Write-Host ""
    Write-Host "[5] Testing GHCR upload..." -ForegroundColor Green
    
    $testTag = "ghcr.io/$GitHubUsername/$IMAGE_NAME`:test"
    
    Write-Host "Tagging image for GHCR test..."
    docker tag "$IMAGE_NAME`:latest" $testTag
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Pushing test image to GHCR..."
        docker push $testTag
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ GHCR upload successful!" -ForegroundColor Green
            Write-Host ""
            Write-Host "🎉 Your image is now available at:" -ForegroundColor Cyan
            Write-Host "   ghcr.io/$GitHubUsername/$IMAGE_NAME`:test" -ForegroundColor White
            Write-Host ""
            Write-Host "Test it with:" -ForegroundColor Yellow
            Write-Host "   docker pull ghcr.io/$GitHubUsername/$IMAGE_NAME`:test" -ForegroundColor Gray
            Write-Host "   docker run -p 5000:5000 ghcr.io/$GitHubUsername/$IMAGE_NAME`:test" -ForegroundColor Gray
            
            # Clean up test image
            Write-Host ""
            $cleanup = Read-Host "Remove test image from GHCR? (y/n)"
            if ($cleanup -eq 'y' -or $cleanup -eq 'Y') {
                Write-Host "Note: You'll need to delete it manually from GitHub packages UI" -ForegroundColor Yellow
                Write-Host "Go to: https://github.com/$GitHubUsername?tab=packages" -ForegroundColor Gray
            }
            
        } else {
            Write-Host "❌ GHCR upload failed" -ForegroundColor Red
            Write-Host ""
            Write-Host "Common upload issues:" -ForegroundColor Yellow
            Write-Host "  - Package doesn't exist yet (first upload creates it)" -ForegroundColor Gray
            Write-Host "  - Wrong repository name or tag format" -ForegroundColor Gray
            Write-Host "  - Network connectivity issues" -ForegroundColor Gray
            Write-Host "  - Token permissions insufficient" -ForegroundColor Gray
        }
    }
}

# Step 6: Final recommendations
Write-Host ""
Write-Host "[6] Recommendations and Next Steps..." -ForegroundColor Green

if ($isGHCRAuthenticated) {
    Write-Host "✅ Authentication: Ready" -ForegroundColor Green
} else {
    Write-Host "❌ Authentication: Needs setup" -ForegroundColor Red
    Write-Host "   Run this script again without -TestOnly after getting a token" -ForegroundColor Yellow
}

if ($localImages) {
    Write-Host "✅ Local images: Available" -ForegroundColor Green
} else {
    Write-Host "❌ Local images: Need to build" -ForegroundColor Red
    Write-Host "   docker build -f Dockerfile.production -t $IMAGE_NAME:latest ." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "📝 Publishing commands (after fixing issues above):" -ForegroundColor Cyan
Write-Host ""
Write-Host "Using the automated script:" -ForegroundColor White
Write-Host "   .\publish-to-registries.ps1 -GitHubUsername '$GitHubUsername' -Version '1.0.0' -SkipDockerHub" -ForegroundColor Gray
Write-Host ""
Write-Host "Manual commands:" -ForegroundColor White
Write-Host "   docker tag $IMAGE_NAME`:latest ghcr.io/$GitHubUsername/$IMAGE_NAME`:latest" -ForegroundColor Gray
Write-Host "   docker tag $IMAGE_NAME`:latest ghcr.io/$GitHubUsername/$IMAGE_NAME`:1.0.0" -ForegroundColor Gray
Write-Host "   docker push ghcr.io/$GitHubUsername/$IMAGE_NAME`:latest" -ForegroundColor Gray
Write-Host "   docker push ghcr.io/$GitHubUsername/$IMAGE_NAME`:1.0.0" -ForegroundColor Gray

Write-Host ""
Write-Host "Troubleshooting complete!" -ForegroundColor Cyan
