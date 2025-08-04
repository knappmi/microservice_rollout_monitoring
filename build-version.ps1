# Version Management for Docker Hub Images
param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    
    [Parameter(Mandatory=$true)]
    [string]$DockerUsername,
    
    [Parameter(Mandatory=$false)]
    [switch]$Push = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$Test = $true
)

$IMAGE_NAME = "observability-demo-app"
$IMAGE_TAG = "${DockerUsername}/${IMAGE_NAME}"

Write-Host "Building version $Version for Docker Hub" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green

# Build the image
Write-Host "Building image..." -ForegroundColor Yellow
docker build -f Dockerfile.production -t "${IMAGE_TAG}:${Version}" .
if ($LASTEXITCODE -ne 0) { throw "Docker build failed" }

# Tag with semantic versions
$versionParts = $Version.Split('.')
if ($versionParts.Length -ge 3) {
    $majorMinor = "$($versionParts[0]).$($versionParts[1])"
    $major = $versionParts[0]
    
    docker tag "${IMAGE_TAG}:${Version}" "${IMAGE_TAG}:${majorMinor}"
    docker tag "${IMAGE_TAG}:${Version}" "${IMAGE_TAG}:${major}"
    docker tag "${IMAGE_TAG}:${Version}" "${IMAGE_TAG}:latest"
    
    Write-Host "Created tags: ${Version}, ${majorMinor}, ${major}, latest" -ForegroundColor Cyan
}

# Test the image if requested
if ($Test) {
    Write-Host "Testing image..." -ForegroundColor Yellow
    
    # Start container for testing
    $containerId = docker run -d -p 5002:5000 "${IMAGE_TAG}:${Version}"
    Start-Sleep 10
    
    try {
        # Test main endpoint
        $response = Invoke-WebRequest -Uri "http://localhost:5002" -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            Write-Host "✅ Main endpoint test passed" -ForegroundColor Green
        } else {
            Write-Host "❌ Main endpoint test failed: $($response.StatusCode)" -ForegroundColor Red
        }
        
        # Test health endpoint
        $health = Invoke-WebRequest -Uri "http://localhost:5002/health" -TimeoutSec 10
        if ($health.StatusCode -eq 200) {
            Write-Host "✅ Health endpoint test passed" -ForegroundColor Green
        } else {
            Write-Host "❌ Health endpoint test failed: $($health.StatusCode)" -ForegroundColor Red
        }
        
        # Test version endpoint
        $version = Invoke-WebRequest -Uri "http://localhost:5002/version" -TimeoutSec 10
        if ($version.StatusCode -eq 200) {
            Write-Host "✅ Version endpoint test passed" -ForegroundColor Green
            Write-Host "   Response: $($version.Content)" -ForegroundColor Cyan
        } else {
            Write-Host "❌ Version endpoint test failed: $($version.StatusCode)" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "❌ Test failed: $_" -ForegroundColor Red
    } finally {
        # Clean up test container
        docker stop $containerId | Out-Null
        docker rm $containerId | Out-Null
    }
}

# Push to Docker Hub if requested
if ($Push) {
    Write-Host "Pushing to Docker Hub..." -ForegroundColor Yellow
    
    # Check if logged in
    $loginTest = docker info 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Please login to Docker Hub first: docker login" -ForegroundColor Red
        exit 1
    }
    
    # Push all tags
    docker push "${IMAGE_TAG}:${Version}"
    docker push "${IMAGE_TAG}:latest"
    
    if ($versionParts.Length -ge 3) {
        docker push "${IMAGE_TAG}:${majorMinor}"
        docker push "${IMAGE_TAG}:${major}"
    }
    
    Write-Host "✅ Successfully pushed to Docker Hub!" -ForegroundColor Green
    Write-Host "Image available at: https://hub.docker.com/r/${DockerUsername}/${IMAGE_NAME}" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Build Summary:" -ForegroundColor Green
Write-Host "  Version: $Version" -ForegroundColor White
Write-Host "  Image: ${IMAGE_TAG}:${Version}" -ForegroundColor White
Write-Host "  Size: $(docker images ${IMAGE_TAG}:${Version} --format 'table {{.Size}}' | Select-Object -Skip 1)" -ForegroundColor White

if (-not $Push) {
    Write-Host ""
    Write-Host "To push to Docker Hub, run:" -ForegroundColor Yellow
    Write-Host "  .\build-version.ps1 -Version $Version -DockerUsername $DockerUsername -Push" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Usage examples:" -ForegroundColor Green
Write-Host "  docker run -p 5000:5000 ${IMAGE_TAG}:${Version}" -ForegroundColor White
Write-Host "  docker run -p 5000:5000 -e SIM_BAD=true ${IMAGE_TAG}:${Version}" -ForegroundColor White
