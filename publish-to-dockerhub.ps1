# Docker Hub Publication Scripts
# Run these commands to build and publish your image

# 1. Build the production image
echo "Building production image..."
docker build -f Dockerfile.production -t observability-demo-app:latest .

# 2. Tag for Docker Hub (replace 'yourusername' with your Docker Hub username)
$DOCKER_USERNAME = "yourusername"  # Change this to your Docker Hub username
$IMAGE_NAME = "observability-demo-app"
$VERSION = "1.0.0"

docker tag observability-demo-app:latest "${DOCKER_USERNAME}/${IMAGE_NAME}:latest"
docker tag observability-demo-app:latest "${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION}"
docker tag observability-demo-app:latest "${DOCKER_USERNAME}/${IMAGE_NAME}:1.0"
docker tag observability-demo-app:latest "${DOCKER_USERNAME}/${IMAGE_NAME}:1"

# 3. Test the image locally
echo "Testing image locally..."
docker run -d -p 5000:5000 --name test-app "${DOCKER_USERNAME}/${IMAGE_NAME}:latest"
Start-Sleep 10

# Test endpoints
echo "Testing endpoints..."
try {
    $response = Invoke-WebRequest -Uri "http://localhost:5000" -TimeoutSec 5
    Write-Host "✅ Main endpoint: $($response.StatusCode)"
} catch {
    Write-Host "❌ Main endpoint failed: $_"
}

try {
    $health = Invoke-WebRequest -Uri "http://localhost:5000/health" -TimeoutSec 5
    Write-Host "✅ Health endpoint: $($health.StatusCode)"
} catch {
    Write-Host "❌ Health endpoint failed: $_"
}

try {
    $metrics = Invoke-WebRequest -Uri "http://localhost:5000/metrics" -TimeoutSec 5
    Write-Host "✅ Metrics endpoint: $($metrics.StatusCode)"
} catch {
    Write-Host "❌ Metrics endpoint failed: $_"
}

# Clean up test
docker stop test-app
docker rm test-app

# 4. Login to Docker Hub (you'll be prompted for credentials)
echo "Logging in to Docker Hub..."
docker login

# 5. Push to Docker Hub
echo "Pushing to Docker Hub..."
docker push "${DOCKER_USERNAME}/${IMAGE_NAME}:latest"
docker push "${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION}"
docker push "${DOCKER_USERNAME}/${IMAGE_NAME}:1.0"
docker push "${DOCKER_USERNAME}/${IMAGE_NAME}:1"

echo "✅ Successfully published to Docker Hub!"
echo "Your image is available at: https://hub.docker.com/r/${DOCKER_USERNAME}/${IMAGE_NAME}"

# 6. Test the published image
echo "Testing published image..."
docker run --rm -p 5001:5000 "${DOCKER_USERNAME}/${IMAGE_NAME}:latest" &
Start-Sleep 10
try {
    $response = Invoke-WebRequest -Uri "http://localhost:5001" -TimeoutSec 5
    Write-Host "✅ Published image test: $($response.StatusCode)"
} catch {
    Write-Host "❌ Published image test failed: $_"
}

Write-Host ""
Write-Host "🎉 Publication complete!"
Write-Host "Usage examples:"
Write-Host "  docker run -p 5000:5000 ${DOCKER_USERNAME}/${IMAGE_NAME}:latest"
Write-Host "  docker run -p 5000:5000 -e SIM_BAD=true ${DOCKER_USERNAME}/${IMAGE_NAME}:latest"
