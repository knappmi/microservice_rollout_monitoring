# Multi-Environment Canary Deployment Script

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("local", "production")]
    [string]$Environment = "local",
    
    [Parameter(Mandatory=$true)]
    [string]$Action
)

$NAMESPACE = "microservice-canary"
$ErrorActionPreference = "Stop"

# Environment-specific settings
$envSettings = @{
    local = @{
        ConfigMap = "configmap-local.yaml"
        ImagePullPolicy = "Always"
        ServiceType = "NodePort"
        JaegerEndpoint = "http://jaeger:4317"
        ResourceProfile = "light"
        ImageName = "ghcr.io/knappmi/observability-demo-app:latest"  # Published GHCR image
    }
    production = @{
        ConfigMap = "configmap-production.yaml"
        ImagePullPolicy = "Always"
        ServiceType = "LoadBalancer"
        JaegerEndpoint = "http://jaeger.observability.svc.cluster.local:4317"
        ResourceProfile = "standard"
        ImageName = "ghcr.io/knappmi/observability-demo-app:latest"  # Published GHCR image
    }
}

$currentEnv = $envSettings[$Environment]

Write-Host "Multi-Environment Canary Deployment" -ForegroundColor Green
Write-Host "===================================" -ForegroundColor Green
Write-Host "Environment: $Environment" -ForegroundColor Cyan
Write-Host "Namespace: $NAMESPACE" -ForegroundColor Cyan

# Function to detect environment automatically
function Get-KubernetesEnvironment {
    try {
        $context = kubectl config current-context
        # Local indicators: minikube, docker-desktop, or anything starting with localhost
        if ($context -match "(minikube|docker-desktop|localhost|kind|k3s|microk8s)" -or 
            $context -match "test" -or 
            $context -match "dev" -or 
            $context -match "local") {
            return "local"
        } else {
            return "production"
        }
    } catch {
        Write-Host "Warning: Could not detect Kubernetes context. Using specified environment." -ForegroundColor Yellow
        return $Environment
    }
}

# Function to check cluster health
function Test-ClusterHealth {
    Write-Host "Checking cluster health..." -ForegroundColor Yellow
    
    # Check kubectl connectivity
    Write-Host "  Verifying kubectl connectivity..." -ForegroundColor White
    try {
        $nodes = kubectl get nodes --no-headers 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Cannot connect to Kubernetes cluster"
        }
        $nodeCount = ($nodes | Measure-Object).Count
        Write-Host "    [OK] Connected to cluster with $nodeCount node(s)" -ForegroundColor Green
    } catch {
        Write-Host "    [ERROR] Failed to connect to Kubernetes cluster" -ForegroundColor Red
        throw "Cluster connectivity check failed: $_"
    }
    
    # Check node readiness
    Write-Host "  Checking node readiness..." -ForegroundColor White
    try {
        $notReadyNodes = kubectl get nodes --no-headers 2>$null | Where-Object { $_ -notmatch "\s+Ready\s+" }
        if ($notReadyNodes) {
            $notReadyCount = ($notReadyNodes | Measure-Object).Count
            Write-Host "    [WARNING] Warning: $notReadyCount node(s) not ready" -ForegroundColor Yellow
            $notReadyNodes | ForEach-Object { Write-Host "      - $_" -ForegroundColor Yellow }
        } else {
            Write-Host "    [OK] All nodes are ready" -ForegroundColor Green
        }
    } catch {
        Write-Host "    [WARNING] Could not verify node readiness" -ForegroundColor Yellow
    }
    
    # Check system pods
    Write-Host "  Checking system pods..." -ForegroundColor White
    try {
        $systemPods = kubectl get pods -n kube-system --no-headers 2>$null
        if ($systemPods) {
            $failedPods = $systemPods | Where-Object { $_ -match "(Error|CrashLoopBackOff|ImagePullBackOff|Pending)" }
            if ($failedPods) {
                $failedCount = ($failedPods | Measure-Object).Count
                Write-Host "    [WARNING] Warning: $failedCount system pod(s) in failed state" -ForegroundColor Yellow
                $failedPods | ForEach-Object { Write-Host "      - $_" -ForegroundColor Yellow }
            } else {
                Write-Host "    [OK] System pods are healthy" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "    [WARNING] Could not check system pods" -ForegroundColor Yellow
    }
    
    # Check cluster resources
    Write-Host "  Checking cluster resources..." -ForegroundColor White
    try {
        $nodes = kubectl top nodes --no-headers 2>$null
        if ($LASTEXITCODE -eq 0 -and $nodes) {
            Write-Host "    [OK] Metrics server is available" -ForegroundColor Green
            
            # Check for high resource usage
            $highCpuNodes = $nodes | Where-Object { 
                $cpuPercent = ($_ -split '\s+')[2] -replace '%', ''
                [int]$cpuPercent -gt 80
            }
            $highMemNodes = $nodes | Where-Object { 
                $memPercent = ($_ -split '\s+')[4] -replace '%', ''
                [int]$memPercent -gt 80
            }
            
            if ($highCpuNodes -or $highMemNodes) {
                Write-Host "    [WARNING] Warning: High resource usage detected" -ForegroundColor Yellow
                if ($highCpuNodes) {
                    Write-Host "      High CPU nodes: $($highCpuNodes.Count)" -ForegroundColor Yellow
                }
                if ($highMemNodes) {
                    Write-Host "      High memory nodes: $($highMemNodes.Count)" -ForegroundColor Yellow
                }
            } else {
                Write-Host "    [OK] Resource usage is normal" -ForegroundColor Green
            }
        } else {
            Write-Host "    [WARNING] Metrics server not available (resource monitoring disabled)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "    [WARNING] Could not check cluster resources" -ForegroundColor Yellow
    }
    
    # Environment-specific checks
    if ($Environment -eq "local") {
        Write-Host "  Performing local environment checks..." -ForegroundColor White
        
        # Check if minikube
        $context = kubectl config current-context
        if ($context -match "minikube") {
            try {
                $minikubeStatus = minikube status 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "    [OK] Minikube is running" -ForegroundColor Green
                } else {
                    Write-Host "    [WARNING] Minikube status check failed" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "    [WARNING] Could not check minikube status" -ForegroundColor Yellow
            }
        }
        
        # Check Docker availability for local builds
        try {
            docker version --format '{{.Server.Version}}' 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "    [OK] Docker is available for local builds" -ForegroundColor Green
            } else {
                Write-Host "    [WARNING] Docker not available (required for local builds)" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "    [WARNING] Could not verify Docker availability" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  Performing production environment checks..." -ForegroundColor White
        
        # Check for production readiness indicators
        try {
            $storageClasses = kubectl get storageclass --no-headers 2>$null
            if ($storageClasses) {
                Write-Host "    [OK] Storage classes are configured" -ForegroundColor Green
            } else {
                Write-Host "    [WARNING] No storage classes found" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "    [WARNING] Could not check storage classes" -ForegroundColor Yellow
        }
        
        # Check for load balancer support
        try {
            $services = kubectl get services --all-namespaces --no-headers 2>$null | Where-Object { $_ -match "LoadBalancer" }
            if ($services) {
                $lbWithExternal = $services | Where-Object { $_ -notmatch "<pending>" }
                if ($lbWithExternal) {
                    Write-Host "    [OK] LoadBalancer services are functional" -ForegroundColor Green
                } else {
                    Write-Host "    [WARNING] LoadBalancer services exist but have no external IPs" -ForegroundColor Yellow
                }
            } else {
                Write-Host "    [INFO] No LoadBalancer services found (this is normal for new clusters)" -ForegroundColor Cyan
            }
        } catch {
            Write-Host "    [WARNING] Could not check LoadBalancer functionality" -ForegroundColor Yellow
        }
    }
    
    Write-Host "  Cluster health check complete" -ForegroundColor Green
}

# Function to check prerequisites
function Test-Prerequisites {
    Write-Host "Checking deployment prerequisites..." -ForegroundColor Yellow
    
    # Check if namespace already exists
    try {
        $existingNamespace = kubectl get namespace $NAMESPACE --no-headers 2>$null
        $namespaceExists = $LASTEXITCODE -eq 0
    } catch {
        $namespaceExists = $false
    }
    
    if ($namespaceExists -and $existingNamespace) {
        Write-Host "  [INFO] Namespace '$NAMESPACE' already exists" -ForegroundColor Cyan
        
        # Check for existing deployments only if namespace exists
        try {
            $existingDeployments = kubectl get deployments -n $NAMESPACE --no-headers 2>$null
            if ($LASTEXITCODE -eq 0 -and $existingDeployments) {
                Write-Host "  [WARNING] Existing deployments found in namespace:" -ForegroundColor Yellow
                $existingDeployments | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
                
                $response = Read-Host "  Continue with deployment? This may update existing resources (y/N)"
                if ($response -notmatch "^[Yy]") {
                    throw "Deployment cancelled by user"
                }
            }
        } catch {
            Write-Host "  [WARNING] Could not check existing deployments" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [OK] Namespace '$NAMESPACE' will be created" -ForegroundColor Green
    }
    
    # Check required manifest files
    $requiredFiles = @(
        "k8s/canary/namespace.yaml",
        "k8s/canary/$($currentEnv.ConfigMap)",
        "k8s/canary/jaeger.yaml",
        "k8s/canary/microservice-stable.yaml",
        "k8s/canary/microservice-canary.yaml",
        "k8s/canary/microservice-service.yaml",
        "k8s/canary/traffic-generator.yaml"
    )
    
    Write-Host "  Checking required manifest files..." -ForegroundColor White
    $missingFiles = @()
    foreach ($file in $requiredFiles) {
        if (Test-Path $file) {
            Write-Host "    [OK] $file" -ForegroundColor Green
        } else {
            Write-Host "    [ERROR] $file (missing)" -ForegroundColor Red
            $missingFiles += $file
        }
    }
    
    if ($missingFiles.Count -gt 0) {
        throw "Missing required files: $($missingFiles -join ', ')"
    }
    
    # Check for published image accessibility
    if ($Environment -eq "local") {
        Write-Host "  Checking local Kubernetes setup..." -ForegroundColor White
        
        # Check if Docker is available for image verification
        try {
            docker version --format '{{.Server.Version}}' 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "    [OK] Docker is available for image verification" -ForegroundColor Green
            } else {
                Write-Host "    [INFO] Docker not available (image verification will be skipped)" -ForegroundColor Cyan
            }
        } catch {
            Write-Host "    [INFO] Docker not available (image verification will be skipped)" -ForegroundColor Cyan
        }
    }
    
    Write-Host "  Using published container image: $($currentEnv.ImageName)" -ForegroundColor Green
    
    Write-Host "  Prerequisites check complete" -ForegroundColor Green
}

# Function to get pod counts (enhanced for bad rollout testing)
function Get-PodCounts {
    try {
        $stablePods = (kubectl get pods -n $NAMESPACE -l version=stable --no-headers 2>$null | Measure-Object).Count
        if ($LASTEXITCODE -ne 0) { $stablePods = 0 }
    } catch { $stablePods = 0 }
    
    try {
        $canaryPods = (kubectl get pods -n $NAMESPACE -l version=canary --no-headers 2>$null | Measure-Object).Count
        if ($LASTEXITCODE -ne 0) { $canaryPods = 0 }
    } catch { $canaryPods = 0 }
    
    try {
        $badCanaryPods = (kubectl get pods -n $NAMESPACE -l version=canary-bad --no-headers 2>$null | Measure-Object).Count
        if ($LASTEXITCODE -ne 0) { $badCanaryPods = 0 }
    } catch { $badCanaryPods = 0 }
    
    $totalPods = $stablePods + $canaryPods + $badCanaryPods
    
    if ($totalPods -gt 0) {
        $canaryPercentage = [math]::Round((($canaryPods + $badCanaryPods) * 100 / $totalPods), 0)
    } else {
        $canaryPercentage = 0
    }
    
    if ($badCanaryPods -gt 0) {
        Write-Host "Environment: $Environment | Stable: $stablePods | Canary: $canaryPods | Bad-Canary: $badCanaryPods | Canary Traffic: ~$canaryPercentage%" -ForegroundColor Cyan
    } else {
        Write-Host "Environment: $Environment | Stable: $stablePods | Canary: $canaryPods | Canary Traffic: ~$canaryPercentage%" -ForegroundColor Cyan
    }
    
    return @{
        Stable = $stablePods
        Canary = $canaryPods
        BadCanary = $badCanaryPods
        Percentage = $canaryPercentage
    }
}

# Function to apply configuration
function Set-Configuration {
    Write-Host "Applying $Environment configuration..." -ForegroundColor Yellow
    
    # Apply namespace
    kubectl apply -f k8s/canary/namespace.yaml
    
    # Apply environment-specific ConfigMap
    Write-Host "  Applying ConfigMap: $($currentEnv.ConfigMap)" -ForegroundColor White
    kubectl apply -f "k8s/canary/$($currentEnv.ConfigMap)"
    
    # Apply Jaeger
    Write-Host "  Deploying Jaeger..." -ForegroundColor White
    kubectl apply -f k8s/canary/jaeger.yaml
    
    # Wait for Jaeger
    Write-Host "  Waiting for Jaeger to be ready..." -ForegroundColor White
    kubectl wait --for=condition=available --timeout=180s deployment/jaeger -n $NAMESPACE
}

# Function to verify published image accessibility
function Test-PublishedImage {
    Write-Host "Verifying published image accessibility..." -ForegroundColor Yellow
    
    try {
        # Test if we can pull the image
        Write-Host "  Checking if image can be pulled: $($currentEnv.ImageName)" -ForegroundColor White
        docker pull $currentEnv.ImageName 2>$null | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    [OK] Published image is accessible" -ForegroundColor Green
        } else {
            Write-Host "    [WARNING] Could not verify image accessibility (may still work in cluster)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "    [WARNING] Could not test image pull locally (Docker may not be available)" -ForegroundColor Yellow
    }
    
    Write-Host "  Using published image: $($currentEnv.ImageName)" -ForegroundColor Green
}

# Function to deploy services
function Set-Services {
    Write-Host "Deploying microservices..." -ForegroundColor Yellow
    
    # Apply services first
    kubectl apply -f k8s/canary/microservice-service.yaml
    
    # Apply deployments
    kubectl apply -f k8s/canary/microservice-stable.yaml
    kubectl apply -f k8s/canary/microservice-canary.yaml
    
    # Wait for deployments
    Write-Host "  Waiting for stable deployment..." -ForegroundColor White
    kubectl wait --for=condition=available --timeout=180s deployment/microservice-stable -n $NAMESPACE
    
    Write-Host "  Waiting for canary deployment..." -ForegroundColor White
    kubectl wait --for=condition=available --timeout=180s deployment/microservice-canary -n $NAMESPACE
    
    # Apply traffic generator
    kubectl apply -f k8s/canary/traffic-generator.yaml
}

# Function to show access information
function Show-AccessInfo {
    Write-Host ""
    Write-Host "Access Information:" -ForegroundColor Cyan
    Write-Host "==================" -ForegroundColor Cyan
    
    if ($Environment -eq "local") {
        Write-Host "Local Development Access:" -ForegroundColor Yellow
        Write-Host "  Jaeger UI: kubectl port-forward -n $NAMESPACE svc/jaeger-ui 16686:16686" -ForegroundColor White
        Write-Host "  Microservice: kubectl port-forward -n $NAMESPACE svc/microservice-lb 5000:5000" -ForegroundColor White
        Write-Host "  Then access: http://localhost:16686 and http://localhost:5000" -ForegroundColor White
        
        if ((kubectl config current-context) -match "minikube") {
            Write-Host ""
            Write-Host "Minikube Access:" -ForegroundColor Yellow
            Write-Host "  minikube service -n $NAMESPACE jaeger-ui" -ForegroundColor White
            Write-Host "  minikube service -n $NAMESPACE microservice-lb" -ForegroundColor White
        }
    } else {
        Write-Host "Production Access:" -ForegroundColor Yellow
        Write-Host "  Check LoadBalancer external IPs:" -ForegroundColor White
        Write-Host "  kubectl get services -n $NAMESPACE" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "Monitoring Commands:" -ForegroundColor Cyan
    Write-Host "  kubectl logs -n $NAMESPACE -l app=traffic-generator -f" -ForegroundColor White
    Write-Host "  kubectl get pods -n $NAMESPACE -w" -ForegroundColor White
}

# Function to scale canary
function Set-CanaryScale {
    param($replicas)
    Write-Host "Scaling canary to $replicas replicas..." -ForegroundColor Yellow
    kubectl scale deployment microservice-canary -n $NAMESPACE --replicas=$replicas
    if ($LASTEXITCODE -ne 0) { throw "Failed to scale canary" }
    
    kubectl wait --for=condition=available --timeout=120s deployment/microservice-canary -n $NAMESPACE
    Get-PodCounts | Out-Null
}

# Function to clean up bad rollout test
function Remove-BadCanaryTest {
    param(
        [bool]$RestoreCanary = $true,
        [bool]$Verbose = $true
    )
    
    if ($Verbose) {
        Write-Host "Cleaning up bad rollout test..." -ForegroundColor Yellow
    }
    
    # Check if bad canary deployment exists
    try {
        $badCanaryDeployment = kubectl get deployment microservice-canary-bad -n $NAMESPACE --no-headers 2>$null
        $badCanaryExists = $LASTEXITCODE -eq 0
    } catch {
        $badCanaryExists = $false
    }
    
    if ($badCanaryExists -and $badCanaryDeployment) {
        if ($Verbose) {
            Write-Host "  Removing bad canary deployment..." -ForegroundColor White
        }
        kubectl delete deployment microservice-canary-bad -n $NAMESPACE --ignore-not-found=true
        
        # Wait for pods to terminate
        if ($Verbose) {
            Write-Host "  Waiting for bad canary pods to terminate..." -ForegroundColor White
        }
        
        $timeout = 60
        $elapsed = 0
        do {
            $badPods = kubectl get pods -n $NAMESPACE -l version=canary-bad --no-headers 2>$null
            if ($LASTEXITCODE -ne 0 -or -not $badPods) { break }
            Start-Sleep 2
            $elapsed += 2
        } while ($elapsed -lt $timeout)
        
        if ($elapsed -ge $timeout) {
            Write-Host "    [WARNING] Bad canary pods did not terminate within timeout" -ForegroundColor Yellow
        } else {
            if ($Verbose) {
                Write-Host "    [OK] Bad canary pods terminated" -ForegroundColor Green
            }
        }
    } else {
        if ($Verbose) {
            Write-Host "  [INFO] No bad canary deployment found" -ForegroundColor Cyan
        }
    }
    
    # Restore regular canary if requested
    if ($RestoreCanary) {
        try {
            $regularCanary = kubectl get deployment microservice-canary -n $NAMESPACE --no-headers 2>$null
            $canaryExists = $LASTEXITCODE -eq 0
        } catch {
            $canaryExists = $false
        }
        
        if ($canaryExists -and $regularCanary) {
            $currentReplicas = (kubectl get deployment microservice-canary -n $NAMESPACE -o jsonpath='{.spec.replicas}' 2>$null)
            if ($currentReplicas -eq "0") {
                if ($Verbose) {
                    Write-Host "  Restoring regular canary to 1 replica..." -ForegroundColor White
                }
                kubectl scale deployment microservice-canary -n $NAMESPACE --replicas=1
                
                if ($Verbose) {
                    Write-Host "  Waiting for regular canary to be ready..." -ForegroundColor White
                }
                kubectl wait --for=condition=available --timeout=60s deployment/microservice-canary -n $NAMESPACE 2>$null
                
                if ($LASTEXITCODE -eq 0) {
                    if ($Verbose) {
                        Write-Host "    [OK] Regular canary restored" -ForegroundColor Green
                    }
                } else {
                    Write-Host "    [WARNING] Regular canary restoration timed out" -ForegroundColor Yellow
                }
            } else {
                if ($Verbose) {
                    Write-Host "  [INFO] Regular canary already has $currentReplicas replica(s)" -ForegroundColor Cyan
                }
            }
        } else {
            if ($Verbose) {
                Write-Host "  [INFO] No regular canary deployment found" -ForegroundColor Cyan
            }
        }
    }
    
    if ($Verbose) {
        Write-Host "Bad rollout cleanup complete!" -ForegroundColor Green
    }
}

# Main execution
try {
    # Only warn if user didn't explicitly specify production and context seems production-like
    if ($Environment -eq "local") {
        $context = kubectl config current-context 2>$null
        if ($context -and $context -notmatch "(minikube|docker-desktop|localhost|kind|k3s|microk8s|test|dev|local)") {
            Write-Host "Warning: You specified 'local' environment but current context is '$context'" -ForegroundColor Yellow
            Write-Host "This appears to be a production cluster. Consider using -Environment production" -ForegroundColor Yellow
            $response = Read-Host "Continue with local environment settings? (y/N)"
            if ($response -notmatch "^[Yy]") {
                Write-Host "Operation cancelled. Please specify the correct environment." -ForegroundColor Yellow
                exit 0
            }
        }
    }
    
    switch ($Action.ToLower()) {
        "deploy" {
            Write-Host ""
            Test-ClusterHealth
            Write-Host ""
            Test-Prerequisites
            Write-Host ""
            
            Test-PublishedImage
            Set-Configuration
            Set-Services
            Get-PodCounts | Out-Null
            Show-AccessInfo
            Write-Host ""
            Write-Host "Deployment complete for $Environment environment!" -ForegroundColor Green
        }
        
        "rollout" {
            Write-Host ""
            Test-ClusterHealth
            Write-Host ""
            
            # Check if deployments exist
            $stableDeployment = kubectl get deployment microservice-stable -n $NAMESPACE --no-headers 2>$null
            $canaryDeployment = kubectl get deployment microservice-canary -n $NAMESPACE --no-headers 2>$null
            
            if (-not $stableDeployment -or -not $canaryDeployment) {
                throw "Required deployments not found. Please run 'deploy' action first."
            }
            
            Write-Host "Starting automated canary rollout..." -ForegroundColor Green
            
            Write-Host "Phase 1: 25% canary traffic" -ForegroundColor Green
            Set-CanaryScale 1
            Start-Sleep 30
            
            Write-Host "Phase 2: 50% canary traffic" -ForegroundColor Green
            kubectl scale deployment microservice-stable -n $NAMESPACE --replicas=2
            Set-CanaryScale 2
            Start-Sleep 30
            
            Write-Host "Phase 3: 75% canary traffic" -ForegroundColor Green
            kubectl scale deployment microservice-stable -n $NAMESPACE --replicas=1
            Set-CanaryScale 3
            Start-Sleep 30
            
            Write-Host "Phase 4: 100% canary traffic" -ForegroundColor Green
            kubectl scale deployment microservice-stable -n $NAMESPACE --replicas=0
            Set-CanaryScale 4
            
            Write-Host "Canary rollout complete!" -ForegroundColor Green
        }
        
        "status" {
            Write-Host ""
            Write-Host "Current Status:" -ForegroundColor Cyan
            Get-PodCounts | Out-Null
            Write-Host ""
            kubectl get pods -n $NAMESPACE -l app=microservice
            Write-Host ""
            kubectl get services -n $NAMESPACE
        }
        
        "health" {
            Write-Host ""
            Test-ClusterHealth
            Write-Host ""
            Test-Prerequisites
        }
        
        "detect" {
            Write-Host ""
            Write-Host "Environment Detection:" -ForegroundColor Cyan
            Write-Host "=====================" -ForegroundColor Cyan
            
            try {
                $context = kubectl config current-context
                Write-Host "Current Kubernetes context: $context" -ForegroundColor White
                
                $detectedEnv = Get-KubernetesEnvironment
                Write-Host "Detected environment: $detectedEnv" -ForegroundColor White
                Write-Host "Your specified environment: $Environment" -ForegroundColor White
                
                if ($detectedEnv -eq $Environment) {
                    Write-Host "[OK] Environment setting matches detected environment" -ForegroundColor Green
                } else {
                    Write-Host "[WARNING] Environment mismatch detected!" -ForegroundColor Yellow
                    Write-Host "  Consider using: -Environment $detectedEnv" -ForegroundColor Yellow
                }
                
                Write-Host ""
                Write-Host "Recommendation:" -ForegroundColor Cyan
                if ($context -match "(minikube|docker-desktop|localhost|kind|k3s|microk8s|test|dev|local)") {
                    Write-Host "  Use: -Environment local" -ForegroundColor Green
                } else {
                    Write-Host "  Use: -Environment production" -ForegroundColor Green
                }
            } catch {
                Write-Host "[ERROR] Could not detect environment: $_" -ForegroundColor Red
            }
        }
        
        "config" {
            Write-Host "Current Configuration:" -ForegroundColor Cyan
            Write-Host "Environment: $Environment" -ForegroundColor White
            Write-Host "ConfigMap: $($currentEnv.ConfigMap)" -ForegroundColor White
            Write-Host "Image Pull Policy: $($currentEnv.ImagePullPolicy)" -ForegroundColor White
            Write-Host "Service Type: $($currentEnv.ServiceType)" -ForegroundColor White
            Write-Host ""
            Write-Host "ConfigMap Contents:" -ForegroundColor Yellow
            try {
                $configMap = kubectl get configmap microservice-config -n $NAMESPACE -o yaml 2>$null
                if ($configMap) {
                    Write-Host $configMap
                } else {
                    Write-Host "ConfigMap not found" -ForegroundColor Red
                }
            } catch {
                Write-Host "ConfigMap not found" -ForegroundColor Red
            }
        }
        
        "cleanup" {
            Write-Host "Cleaning up $Environment deployment..." -ForegroundColor Red
            kubectl delete namespace $NAMESPACE --ignore-not-found=true
            Write-Host "Cleanup complete!" -ForegroundColor Green
        }
        
        "test-bad" {
            Write-Host ""
            Write-Host "Testing Bad Rollout Scenario" -ForegroundColor Red
            Write-Host "============================" -ForegroundColor Red
            Write-Host "This will deploy a canary with high error rates and latency" -ForegroundColor Yellow
            Write-Host ""
            
            Test-ClusterHealth
            Write-Host ""
            
            # Check if stable deployment exists
            $stableDeployment = kubectl get deployment microservice-stable -n $NAMESPACE --no-headers 2>$null
            if (-not $stableDeployment) {
                throw "Stable deployment not found. Please run 'deploy' action first."
            }
            
            # Clean up any existing bad canary first
            Remove-BadCanaryTest -RestoreCanary $false -Verbose $false
            
            Write-Host "Deploying bad canary with simulation parameters:" -ForegroundColor Yellow
            Write-Host "  ERROR_RATE: 70% (very bad!)" -ForegroundColor Red
            Write-Host "  MAX_LATENCY: 10 seconds" -ForegroundColor Red
            Write-Host "  SIM_BAD: true" -ForegroundColor Red
            Write-Host ""
            
            # Deploy the bad canary
            kubectl apply -f k8s/canary/microservice-canary-bad.yaml
            
            # Scale down regular canary if it exists
            $regularCanary = kubectl get deployment microservice-canary -n $NAMESPACE --no-headers 2>$null
            if ($regularCanary) {
                Write-Host "  Scaling down regular canary..." -ForegroundColor White
                kubectl scale deployment microservice-canary -n $NAMESPACE --replicas=0
            }
            
            # Wait for deployment with better error handling
            Write-Host "  Waiting for bad canary deployment..." -ForegroundColor White
            $deploymentReady = $false
            try {
                kubectl wait --for=condition=available --timeout=120s deployment/microservice-canary-bad -n $NAMESPACE
                $deploymentReady = $LASTEXITCODE -eq 0
            } catch {
                $deploymentReady = $false
            }
            
            if (-not $deploymentReady) {
                Write-Host "    [WARNING] Bad canary deployment not ready within timeout (this is expected for very bad configurations)" -ForegroundColor Yellow
            } else {
                Write-Host "    [OK] Bad canary deployment ready" -ForegroundColor Green
            }
            
            Get-PodCounts | Out-Null
            Write-Host ""
            Write-Host "Bad rollout test deployed!" -ForegroundColor Green
            Write-Host ""
            Write-Host "Test Commands:" -ForegroundColor Cyan
            Write-Host "  # Test bad behavior (expect many errors!):" -ForegroundColor White
            Write-Host "  kubectl port-forward -n $NAMESPACE svc/microservice-lb 5000:5000" -ForegroundColor White
            Write-Host "  # In another terminal: for `$i in 1..10 { Invoke-WebRequest http://localhost:5000 }" -ForegroundColor White
            Write-Host ""
            Write-Host "Monitoring Commands:" -ForegroundColor Cyan
            Write-Host "  kubectl logs -n $NAMESPACE -l version=canary-bad -f" -ForegroundColor White
            Write-Host "  kubectl get pods -n $NAMESPACE -l version=canary-bad -w" -ForegroundColor White
            Write-Host ""
            Write-Host "Auto-cleanup Options:" -ForegroundColor Cyan
            Write-Host "  .\multi-env-canary.ps1 -Environment $Environment -Action cleanup-bad" -ForegroundColor White
            Write-Host ""
            
            # Ask if user wants auto-cleanup after a delay
            Write-Host "Auto-cleanup Configuration:" -ForegroundColor Yellow
            $autoCleanup = Read-Host "  Auto-cleanup after testing? Enter minutes (0 to skip, default 5)"
            if ([string]::IsNullOrWhiteSpace($autoCleanup)) { $autoCleanup = "5" }
            
            if ([int]$autoCleanup -gt 0) {
                Write-Host "  Bad rollout will auto-cleanup in $autoCleanup minute(s)" -ForegroundColor Green
                Write-Host "  You can manually cleanup anytime with: .\multi-env-canary.ps1 -Environment $Environment -Action cleanup-bad" -ForegroundColor Cyan
                
                # Start background job for auto-cleanup
                $cleanupJob = Start-Job -ScriptBlock {
                    param($minutes, $namespace)
                    Start-Sleep ($minutes * 60)
                    
                    # Clean up bad canary
                    kubectl delete deployment microservice-canary-bad -n $namespace --ignore-not-found=true
                    
                    # Restore regular canary
                    $regularCanary = kubectl get deployment microservice-canary -n $namespace --no-headers 2>$null
                    if ($regularCanary) {
                        kubectl scale deployment microservice-canary -n $namespace --replicas=1
                    }
                } -ArgumentList $autoCleanup, $NAMESPACE
                
                Write-Host "  Background cleanup job started (ID: $($cleanupJob.Id))" -ForegroundColor Cyan
            } else {
                Write-Host "  Manual cleanup required when finished testing" -ForegroundColor Yellow
            }
        }
        
        "cleanup-bad" {
            Write-Host ""
            Write-Host "Cleaning Up Bad Rollout Test" -ForegroundColor Yellow
            Write-Host "============================" -ForegroundColor Yellow
            Write-Host ""
            
            Remove-BadCanaryTest -RestoreCanary $true -Verbose $true
            Write-Host ""
            Get-PodCounts | Out-Null
            Write-Host ""
            Write-Host "Bad rollout cleanup complete! Normal canary operations restored." -ForegroundColor Green
        }
        
        default {
            Write-Host "Usage: .\multi-env-canary.ps1 -Environment [local|production] -Action [command]" -ForegroundColor White
            Write-Host ""
            Write-Host "Environments:" -ForegroundColor Cyan
            Write-Host "  local      - Minikube/Docker Desktop (NodePort, local images)" -ForegroundColor White
            Write-Host "  production - Production K8s (LoadBalancer, registry images)" -ForegroundColor White
            Write-Host ""
            Write-Host "Commands:" -ForegroundColor Cyan
            Write-Host "  deploy      - Deploy complete setup for specified environment" -ForegroundColor White
            Write-Host "  rollout     - Execute automated canary rollout" -ForegroundColor White
            Write-Host "  status      - Show current deployment status" -ForegroundColor White
            Write-Host "  health      - Check cluster health and prerequisites" -ForegroundColor White
            Write-Host "  detect      - Detect and recommend correct environment setting" -ForegroundColor White
            Write-Host "  config      - Show current configuration" -ForegroundColor White
            Write-Host "  test-bad    - Deploy a bad canary for testing failure scenarios" -ForegroundColor White
            Write-Host "  cleanup-bad - Clean up bad rollout test and restore normal canary" -ForegroundColor White
            Write-Host "  cleanup     - Delete entire deployment" -ForegroundColor White
            Write-Host ""
            Write-Host "Examples:" -ForegroundColor Cyan
            Write-Host "  .\multi-env-canary.ps1 -Environment local -Action detect" -ForegroundColor White
            Write-Host "  .\multi-env-canary.ps1 -Environment local -Action health" -ForegroundColor White
            Write-Host "  .\multi-env-canary.ps1 -Environment local -Action deploy" -ForegroundColor White
            Write-Host "  .\multi-env-canary.ps1 -Environment production -Action deploy" -ForegroundColor White
            Write-Host "  .\multi-env-canary.ps1 -Environment local -Action rollout" -ForegroundColor White
            Write-Host "  .\multi-env-canary.ps1 -Environment local -Action test-bad" -ForegroundColor White
            Write-Host "  .\multi-env-canary.ps1 -Environment local -Action cleanup-bad" -ForegroundColor White
        }
    }
} catch {
    Write-Host "Command failed: $_" -ForegroundColor Red
    exit 1
}
