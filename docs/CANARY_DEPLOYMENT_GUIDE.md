# Canary Deployment Quick Start Guide

## Overview
This setup provides a real canary deployment testing environment where traffic is gradually shifted between stable and canary versions of your microservice.

## Key Features
- **Traffic Splitting**: Load balancing between stable and canary versions based on replica count
- **Version Identification**: Each response includes version labels for tracking
- **OpenTelemetry Tracing**: Full observability during rollouts
- **SLO Simulation**: Canary version simulates degraded performance
- **Automated Rollout**: Scripts for progressive traffic shifting

## Quick Start

### 1. Deploy Initial Setup
```powershell
# Navigate to your project directory
cd c:\Users\knapp\Documents\Code\microservice_rollout_monitoring

# Deploy everything (builds image and deploys to Kubernetes)
.\k8s\canary\canary-rollout.ps1 deploy
```

### 2. Execute Canary Rollout
```powershell
# Run automated rollout (25% -> 50% -> 75% -> 100%)
.\k8s\canary\canary-rollout.ps1 rollout
```

### 3. Monitor Traffic
```powershell
# Watch traffic distribution in real-time
kubectl logs -n microservice-canary -l app=traffic-generator -f

# Check pod distribution
.\k8s\canary\canary-rollout.ps1 status
```

### 4. Access Services
```powershell
# Access the load-balanced service
kubectl port-forward -n microservice-canary svc/microservice-lb 5000:5000

# Access Jaeger tracing UI
kubectl port-forward -n microservice-canary svc/jaeger-ui 16686:16686
```

## Traffic Distribution

The system uses Kubernetes native load balancing. Traffic is distributed based on the number of replicas:

| Phase | Stable Replicas | Canary Replicas | Canary Traffic % |
|-------|----------------|-----------------|------------------|
| 1     | 3              | 1               | ~25%             |
| 2     | 2              | 2               | ~50%             |
| 3     | 1              | 3               | ~75%             |
| 4     | 0              | 4               | 100%             |

## Version Identification

Each service response includes version information:
- **Stable**: `v1.0.0-stable` (SIM_BAD=false)
- **Canary**: `v1.1.0-canary` (SIM_BAD=true, higher error rate)

## Available Endpoints

- `GET /` - Root endpoint with version info
- `GET /health` - Health check with version
- `GET /users` - Sample data endpoint
- `GET /version` - Detailed version and config info
- `GET /slo-config` - SLO simulation configuration
- `GET /metrics` - Prometheus metrics

## Commands Reference

```powershell
# Deploy initial setup
.\k8s\canary\canary-rollout.ps1 deploy

# Execute full rollout
.\k8s\canary\canary-rollout.ps1 rollout

# Manual scaling
.\k8s\canary\canary-rollout.ps1 scale 2

# Promote canary to stable
.\k8s\canary\canary-rollout.ps1 promote

# Rollback canary
.\k8s\canary\canary-rollout.ps1 rollback

# Check status
.\k8s\canary\canary-rollout.ps1 status

# Clean up everything
.\k8s\canary\canary-rollout.ps1 cleanup
```

## Observability

### Traces in Jaeger
- Access Jaeger at `http://localhost:16686`
- Search for service `microservice`
- Filter by `service.version` tag to see stable vs canary traces
- Compare error rates and latency between versions

### Custom Trace Attributes
- `service.version`: v1.0.0 or v1.1.0
- `version.label`: v1.0.0-stable or v1.1.0-canary
- `deployment.type`: stable or canary
- `slo.sim_bad`: true/false
- `slo.error_rate`: configured error rate

## Testing Scenarios

### Successful Rollout
1. Deploy and verify stable version works
2. Start rollout and monitor traces
3. Confirm canary receives expected traffic
4. Promote canary if metrics are acceptable

### Failed Rollout (Rollback)
1. Deploy and start rollout
2. Monitor canary error rates in Jaeger
3. If SLOs are violated, execute rollback
4. Confirm traffic returns to stable version

## Troubleshooting

### Common Issues
- **Pods not starting**: Check `kubectl get pods -n microservice-canary`
- **No traffic to canary**: Verify replica counts with `status` command
- **Image pull errors**: Ensure Docker image was built with `docker build -t microservice-app:latest .`

### Debug Commands
```powershell
# Check pod logs
kubectl logs -n microservice-canary -l version=canary
kubectl logs -n microservice-canary -l version=stable

# Check service endpoints
kubectl get endpoints -n microservice-canary

# Verify image
docker images | findstr microservice-app
```

This setup provides a production-ready canary deployment testing environment with full observability and automated rollout capabilities.
