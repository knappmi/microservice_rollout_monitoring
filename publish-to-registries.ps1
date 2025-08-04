#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Publishes the observability demo microservice to Docker Hub and GitHub Container Registry (GHCR)

.DESCRIPTION
    This script builds, tests, and publishes the observability microservice to GitHub Container Registry (GHCR) and Docker Hub.
    It performs comprehensive testing before publishing and supports semantic versioning. GHCR is the primary registry.

.PARAMETER DockerHubUsername
    Your Docker Hub username (required for Docker Hub publishing)

.PARAMETER GitHubUsername
    Your GitHub username (required for GHCR publishing, defaults to DockerHubUsername)

.PARAMETER Version
    Semantic version for the image (e.g., "1.0.0")

.PARAMETER SkipDockerHub
    Skip publishing to Docker Hub

.PARAMETER SkipGHCR
    Skip publishing to GitHub Container Registry

.PARAMETER SkipTests
    Skip the testing phase (not recommended)

.EXAMPLE
    .\publish-to-registries.ps1 -DockerHubUsername "myuser" -Version "1.0.0"
    
.EXAMPLE
    .\publish-to-registries.ps1 -DockerHubUsername "myuser" -GitHubUsername "myuser" -Version "1.2.0" -SkipDockerHub
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$DockerHubUsername,
    
    [Parameter(Mandatory=$false)]
    [string]$GitHubUsername,
    
    [Parameter(Mandatory=$true)]
    [string]$Version,
    
    [switch]$SkipDockerHub,
    [switch]$SkipGHCR,
    [switch]$SkipTests
)

# Validate parameters
if (-not $SkipDockerHub -and -not $DockerHubUsername) {
    Write-Error "DockerHubUsername is required when publishing to Docker Hub"
    exit 1
}

if (-not $SkipGHCR -and -not $GitHubUsername) {
    if ($DockerHubUsername) {
        $GitHubUsername = $DockerHubUsername
        Write-Host "Using DockerHubUsername '$DockerHubUsername' for GitHub username" -ForegroundColor Yellow
    } else {
        Write-Error "GitHubUsername is required when publishing to GHCR"
        exit 1
    }
}

# Validate version format
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    Write-Error "Version must be in semantic versioning format (e.g., '1.0.0')"
    exit 1
}

$IMAGE_NAME = "observability-demo-app"
$BUILD_DATE = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Publishing Observability Demo App" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Version: $Version" -ForegroundColor White
Write-Host "Build Date: $BUILD_DATE" -ForegroundColor White
if (-not $SkipGHCR) { Write-Host "GHCR: ghcr.io/$GitHubUsername/$IMAGE_NAME" -ForegroundColor White }
if (-not $SkipDockerHub) { Write-Host "Docker Hub: $DockerHubUsername/$IMAGE_NAME" -ForegroundColor White }
Write-Host ""

# Step 1: Build the production image
Write-Host "[1/6] Building production image..." -ForegroundColor Green
try {
    docker build -f Dockerfile.production -t $IMAGE_NAME:latest -t $IMAGE_NAME:$Version .
    if ($LASTEXITCODE -ne 0) { throw "Docker build failed" }
    Write-Host "Build completed successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to build image: $_"
    exit 1
}

# Step 2: Test the image
if (-not $SkipTests) {
    Write-Host "[2/6] Testing the image..." -ForegroundColor Green
    
    # Start container for testing
    Write-Host "Starting container for testing..."
    $containerId = docker run -d -p 5001:5000 --name test-obs-app $IMAGE_NAME:latest
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to start test container"
        exit 1
    }
    
    # Wait for container to be ready
    Write-Host "Waiting for container to be ready..."
    $maxAttempts = 30
    $attempt = 0
    do {
        Start-Sleep -Seconds 2
        $attempt++
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:5001/health" -UseBasicParsing -TimeoutSec 5
            if ($response.StatusCode -eq 200) {
                Write-Host "Health check passed: $($response.Content)" -ForegroundColor Green
                break
            }
        } catch {
            if ($attempt -eq $maxAttempts) {
                Write-Error "Health check failed after $maxAttempts attempts"
                docker logs test-obs-app
                docker stop test-obs-app | Out-Null
                docker rm test-obs-app | Out-Null
                exit 1
            }
        }
    } while ($attempt -lt $maxAttempts)
    
    # Test main endpoint
    Write-Host "Testing main endpoint..."
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:5001/" -UseBasicParsing -TimeoutSec 5
        if ($response.StatusCode -eq 200) {
            Write-Host "Main endpoint test passed" -ForegroundColor Green
        } else {
            throw "Unexpected status code: $($response.StatusCode)"
        }
    } catch {
        Write-Error "Main endpoint test failed: $_"
        docker logs test-obs-app
        docker stop test-obs-app | Out-Null
        docker rm test-obs-app | Out-Null
        exit 1
    }
    
    # Test failure simulation
    Write-Host "Testing failure simulation..."
    docker stop test-obs-app | Out-Null
    docker rm test-obs-app | Out-Null
    
    $containerId = docker run -d -p 5001:5000 -e SIM_BAD=true -e ERROR_RATE=1.0 --name test-obs-app-bad $IMAGE_NAME:latest
    Start-Sleep -Seconds 3
    
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:5001/" -UseBasicParsing -TimeoutSec 5
        if ($response.StatusCode -eq 500) {
            Write-Host "Failure simulation test passed" -ForegroundColor Green
        } else {
            Write-Warning "Expected 500 error for failure simulation, got: $($response.StatusCode)"
        }
    } catch {
        if ($_.Exception.Response.StatusCode -eq 500) {
            Write-Host "Failure simulation test passed (caught 500 error)" -ForegroundColor Green
        } else {
            Write-Warning "Failure simulation test inconclusive: $_"
        }
    }
    
    # Clean up test containers
    docker stop test-obs-app-bad | Out-Null
    docker rm test-obs-app-bad | Out-Null
    
    Write-Host "All tests passed!" -ForegroundColor Green
} else {
    Write-Host "[2/6] Skipping tests..." -ForegroundColor Yellow
}

# Step 3: Tag images for registries
Write-Host "[3/6] Tagging images..." -ForegroundColor Green

$tags = @()

if (-not $SkipDockerHub) {
    $dockerHubLatest = "$DockerHubUsername/$IMAGE_NAME:latest"
    $dockerHubVersioned = "$DockerHubUsername/$IMAGE_NAME:$Version"
    docker tag $IMAGE_NAME:latest $dockerHubLatest
    docker tag $IMAGE_NAME:latest $dockerHubVersioned
    $tags += $dockerHubLatest, $dockerHubVersioned
    Write-Host "Tagged for Docker Hub: $dockerHubLatest, $dockerHubVersioned" -ForegroundColor White
}

if (-not $SkipGHCR) {
    $ghcrLatest = "ghcr.io/$GitHubUsername/$IMAGE_NAME:latest"
    $ghcrVersioned = "ghcr.io/$GitHubUsername/$IMAGE_NAME:$Version"
    docker tag $IMAGE_NAME:latest $ghcrLatest
    docker tag $IMAGE_NAME:latest $ghcrVersioned
    $tags += $ghcrLatest, $ghcrVersioned
    Write-Host "Tagged for GHCR: $ghcrLatest, $ghcrVersioned" -ForegroundColor White
}

# Step 4: Login to registries
Write-Host "[4/6] Logging into registries..." -ForegroundColor Green

if (-not $SkipDockerHub) {
    Write-Host "Please login to Docker Hub:"
    docker login
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Docker Hub login failed"
        exit 1
    }
}

if (-not $SkipGHCR) {
    Write-Host "Please login to GitHub Container Registry:"
    Write-Host "You'll need a GitHub Personal Access Token with 'write:packages' permission" -ForegroundColor Yellow
    docker login ghcr.io
    if ($LASTEXITCODE -ne 0) {
        Write-Error "GHCR login failed"
        exit 1
    }
}

# Step 5: Push images
Write-Host "[5/6] Pushing images..." -ForegroundColor Green

foreach ($tag in $tags) {
    Write-Host "Pushing $tag..."
    docker push $tag
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to push $tag"
        exit 1
    }
    Write-Host "Successfully pushed $tag" -ForegroundColor Green
}

# Step 6: Verify and cleanup
Write-Host "[6/6] Verification and cleanup..." -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "     PUBLICATION SUCCESSFUL!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if (-not $SkipGHCR) {
    Write-Host "GitHub Container Registry Images (Primary):" -ForegroundColor White
    Write-Host "  - docker pull ghcr.io/$GitHubUsername/$IMAGE_NAME:latest" -ForegroundColor Gray
    Write-Host "  - docker pull ghcr.io/$GitHubUsername/$IMAGE_NAME:$Version" -ForegroundColor Gray
    Write-Host ""
}

if (-not $SkipDockerHub) {
    Write-Host "Docker Hub Images (Alternative):" -ForegroundColor White
    Write-Host "  - docker pull $DockerHubUsername/$IMAGE_NAME:latest" -ForegroundColor Gray
    Write-Host "  - docker pull $DockerHubUsername/$IMAGE_NAME:$Version" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "Quick Start Commands:" -ForegroundColor White
if (-not $SkipGHCR) {
    Write-Host "  docker run -p 5000:5000 ghcr.io/$GitHubUsername/$IMAGE_NAME:latest" -ForegroundColor Gray
}
if (-not $SkipDockerHub) {
    Write-Host "  docker run -p 5000:5000 $DockerHubUsername/$IMAGE_NAME:latest" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Image Details:" -ForegroundColor White
Write-Host "  Version: $Version" -ForegroundColor Gray
Write-Host "  Build Date: $BUILD_DATE" -ForegroundColor Gray
Write-Host "  Features: OpenTelemetry, Prometheus, Health Checks, Failure Simulation" -ForegroundColor Gray

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Update your Kubernetes manifests with the new image tags" -ForegroundColor Gray
Write-Host "  2. Test the published images in your environment" -ForegroundColor Gray
Write-Host "  3. Update documentation with the correct image URLs" -ForegroundColor Gray

Write-Host ""
Write-Host "Publication completed successfully!" -ForegroundColor Green
