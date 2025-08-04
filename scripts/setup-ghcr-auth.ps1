# GHCR Authentication Setup for Kubernetes
# This script creates the necessary secrets for pulling from GitHub Container Registry

param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubToken,
    
    [Parameter(Mandatory=$false)]
    [string]$GitHubUsername = "knappmi",
    
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "microservice-canary"
)

Write-Host "Setting up GHCR authentication for Kubernetes..." -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
Write-Host "Username: $GitHubUsername" -ForegroundColor Cyan
Write-Host "Namespace: $Namespace" -ForegroundColor Cyan
Write-Host ""

# Check if kubectl is available
try {
    kubectl version --client --short 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "kubectl not found" }
    Write-Host "✓ kubectl available" -ForegroundColor Green
} catch {
    Write-Host "✗ kubectl not found or not working" -ForegroundColor Red
    throw "kubectl is required but not available"
}

# Check cluster connectivity
try {
    kubectl cluster-info --request-timeout=5s 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Cannot connect to cluster" }
    Write-Host "✓ Kubernetes cluster accessible" -ForegroundColor Green
} catch {
    Write-Host "✗ Cannot connect to Kubernetes cluster" -ForegroundColor Red
    throw "Kubernetes cluster is not accessible"
}

# Create namespace if it doesn't exist
Write-Host ""
Write-Host "Creating namespace if needed..." -ForegroundColor Yellow
kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -

# Create the image pull secret
Write-Host "Creating GHCR image pull secret..." -ForegroundColor Yellow
kubectl create secret docker-registry ghcr-secret `
    --docker-server=ghcr.io `
    --docker-username=$GitHubUsername `
    --docker-password=$GitHubToken `
    --docker-email="$GitHubUsername@users.noreply.github.com" `
    --namespace=$Namespace `
    --dry-run=client -o yaml | kubectl apply -f -

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ GHCR secret created successfully" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to create GHCR secret" -ForegroundColor Red
    throw "Failed to create image pull secret"
}

# Test the secret by trying to pull the image
Write-Host ""
Write-Host "Testing GHCR access..." -ForegroundColor Yellow
$testPod = @"
apiVersion: v1
kind: Pod
metadata:
  name: ghcr-test
  namespace: $Namespace
spec:
  imagePullSecrets:
  - name: ghcr-secret
  containers:
  - name: test
    image: ghcr.io/knappmi/observability-demo-app:latest
    command: ["sleep", "10"]
  restartPolicy: Never
"@

$testPod | kubectl apply -f -

Write-Host "Waiting for test pod to start..." -ForegroundColor White
$timeout = 60
$elapsed = 0
do {
    $podStatus = kubectl get pod ghcr-test -n $Namespace -o jsonpath='{.status.phase}' 2>$null
    if ($podStatus -eq "Running" -or $podStatus -eq "Succeeded") {
        Write-Host "✓ GHCR image pull test successful!" -ForegroundColor Green
        break
    } elseif ($podStatus -eq "Failed") {
        Write-Host "✗ GHCR image pull test failed" -ForegroundColor Red
        kubectl describe pod ghcr-test -n $Namespace
        break
    }
    Start-Sleep 2
    $elapsed += 2
} while ($elapsed -lt $timeout)

# Clean up test pod
kubectl delete pod ghcr-test -n $Namespace --ignore-not-found=true 2>$null

Write-Host ""
Write-Host "GHCR Authentication Summary:" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
Write-Host "Secret Name: ghcr-secret" -ForegroundColor White
Write-Host "Namespace: $Namespace" -ForegroundColor White
Write-Host "Registry: ghcr.io" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. The deployments should now be able to pull from GHCR" -ForegroundColor White
Write-Host "2. Run your deployment script: .\multi-env-canary.ps1 -Environment local -Action deploy" -ForegroundColor White
Write-Host "3. For AKS, use: .\multi-env-canary.ps1 -Environment production -Action deploy" -ForegroundColor White
Write-Host ""
Write-Host "Note: This secret will need to be recreated if the GitHub token expires." -ForegroundColor Yellow
