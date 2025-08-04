#!/usr/bin/env pwsh
# Quick GHCR Debug Script

Write-Host "=== GHCR Debug Information ===" -ForegroundColor Cyan
Write-Host ""

# Check if logged in
Write-Host "1. Checking Docker authentication..." -ForegroundColor Yellow
$dockerConfig = "$env:USERPROFILE\.docker\config.json"
if (Test-Path $dockerConfig) {
    $auths = (Get-Content $dockerConfig | ConvertFrom-Json).auths
    Write-Host "Authenticated registries:" -ForegroundColor White
    $auths | Get-Member -MemberType NoteProperty | ForEach-Object { 
        Write-Host "  - $($_.Name)" -ForegroundColor Gray 
    }
    
    if ($auths."ghcr.io") {
        Write-Host "✅ GHCR authentication found" -ForegroundColor Green
    } else {
        Write-Host "❌ GHCR authentication missing" -ForegroundColor Red
    }
} else {
    Write-Host "❌ No Docker config found" -ForegroundColor Red
}

Write-Host ""

# Check if image exists locally
Write-Host "2. Checking local images..." -ForegroundColor Yellow
$images = docker images observability-demo-app --format "{{.Repository}}:{{.Tag}}"
if ($images) {
    Write-Host "Local images found:" -ForegroundColor Green
    $images | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
} else {
    Write-Host "❌ No local images found" -ForegroundColor Red
}

Write-Host ""

# Test GHCR connectivity
Write-Host "3. Testing GHCR connectivity..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "https://ghcr.io/v2/" -Method Get -Headers @{"Authorization" = "Bearer anonymous"} -ErrorAction Stop
    Write-Host "✅ GHCR is reachable" -ForegroundColor Green
} catch {
    Write-Host "GHCR response: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Next Steps ===" -ForegroundColor Cyan

Write-Host "If you haven't logged in yet:" -ForegroundColor Yellow
Write-Host "  docker login ghcr.io -u knappmi" -ForegroundColor Gray
Write-Host "  (Use your GitHub token as password)" -ForegroundColor Gray

Write-Host ""
Write-Host "If login fails, check:" -ForegroundColor Yellow
Write-Host "  - Token has 'write:packages' and 'read:packages' permissions" -ForegroundColor Gray
Write-Host "  - Username is exactly 'knappmi' (your GitHub username)" -ForegroundColor Gray
Write-Host "  - Token starts with 'ghp_' and was copied correctly" -ForegroundColor Gray

Write-Host ""
Write-Host "Once logged in, push with:" -ForegroundColor Yellow
Write-Host "  docker tag observability-demo-app:latest ghcr.io/knappmi/observability-demo-app:latest" -ForegroundColor Gray
Write-Host "  docker push ghcr.io/knappmi/observability-demo-app:latest" -ForegroundColor Gray
