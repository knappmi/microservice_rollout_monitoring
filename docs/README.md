# Multi-Environment Canary Deployment System

This directory contains a comprehensive Kubernetes canary deployment system that works across both local development (minikube) and production environments using ConfigMap-based configuration.

## Architecture Overview

The system implements:
- **Environment-agnostic deployments**: Same manifests work in local and production
- **ConfigMap-based configuration**: Environment-specific settings without code changes
- **Automated canary rollouts**: Progressive traffic shifting with monitoring
- **OpenTelemetry integration**: Complete observability with Jaeger tracing
- **SLO simulation**: Configurable error rates and latency for testing

## Directory Structure

```
k8s/canary/
├── README.md                    # This documentation
├── multi-env-canary.ps1         # Multi-environment deployment script
├── namespace.yaml               # Namespace definition
├── configmap-local.yaml         # Local/minikube configuration
├── configmap-production.yaml    # Production configuration
├── jaeger.yaml                  # Jaeger tracing infrastructure
├── microservice-stable.yaml     # Stable version deployment
├── microservice-canary.yaml     # Canary version deployment
├── microservice-service.yaml    # Service definitions
└── traffic-generator.yaml       # Load testing pod
```

## Environment Configurations

### Local Development (configmap-local.yaml)
- **Target**: Minikube, Docker Desktop
- **Service Type**: NodePort
- **Resources**: Light (64Mi-128Mi memory)
- **Error Rates**: Higher for testing (5%)
- **OpenTelemetry**: Local Jaeger endpoints

### Production (configmap-production.yaml)
- **Target**: Production Kubernetes
- **Service Type**: LoadBalancer
- **Resources**: Standard (256Mi-512Mi memory)
- **Error Rates**: Conservative (0.1%)
- **OpenTelemetry**: Secure production endpoints

## Quick Start

### 1. Local Development Setup

Deploy to minikube:
```powershell
.\multi-env-canary.ps1 -Environment local -Action deploy
```

### 2. Production Deployment

Deploy to production cluster:
```powershell
.\multi-env-canary.ps1 -Environment production -Action deploy
```

### 3. Execute Canary Rollout

Run automated progressive rollout:
```powershell
.\multi-env-canary.ps1 -Environment local -Action rollout
```

## Available Commands

| Command | Description |
|---------|-------------|
| `deploy` | Deploy complete setup for specified environment |
| `rollout` | Execute automated canary rollout (25% → 50% → 75% → 100%) |
| `status` | Show current deployment status and traffic distribution |
| `config` | Display current configuration and ConfigMap contents |
| `cleanup` | Delete entire deployment |

## Monitoring and Observability

### Access Jaeger UI

**Local (minikube):**
```bash
kubectl port-forward -n microservice-canary svc/jaeger-ui 16686:16686
# Then visit: http://localhost:16686
```

**Production:**
```bash
kubectl get services -n microservice-canary
# Use external LoadBalancer IP
```

### Access Microservice

**Local:**
```bash
kubectl port-forward -n microservice-canary svc/microservice-lb 5000:5000
# Then visit: http://localhost:5000
```

### Monitor Traffic

Watch traffic generation:
```bash
kubectl logs -n microservice-canary -l app=traffic-generator -f
```

Watch pod scaling:
```bash
kubectl get pods -n microservice-canary -w
```

## Canary Rollout Process

The automated rollout follows this progression:

1. **Phase 1 (25% canary)**: 1 canary pod, 3 stable pods
2. **Phase 2 (50% canary)**: 2 canary pods, 2 stable pods  
3. **Phase 3 (75% canary)**: 3 canary pods, 1 stable pod
4. **Phase 4 (100% canary)**: 4 canary pods, 0 stable pods

Each phase includes:
- 30-second monitoring period
- Automatic scaling
- Health checks
- Traffic distribution updates

## Configuration Customization

### Environment Variables (ConfigMap)

Key configuration options:

| Variable | Local Default | Production Default | Description |
|----------|---------------|-------------------|-------------|
| `ERROR_RATE_DEFAULT` | 5 | 0.1 | Base error rate percentage |
| `LATENCY_SIMULATION_DEFAULT` | true | false | Enable latency simulation |
| `MAX_LATENCY_DEFAULT` | 2000 | 1500 | Maximum latency in ms |
| `SERVICE_TYPE` | NodePort | LoadBalancer | Kubernetes service type |
| `MEMORY_LIMIT` | 128Mi | 512Mi | Container memory limit |

### SLO Simulation

The system includes configurable SLO simulation:

- **Error rates**: HTTP 500 responses
- **Latency injection**: Artificial delays
- **Version identification**: Stable vs canary routing
- **Health endpoints**: `/health`, `/version`, `/slo-status`

## Troubleshooting

### Common Issues

**Image pull errors (local):**
```bash
# Ensure image is built and available
docker build -t microservice-app:latest .
minikube image load microservice-app:latest  # For minikube
```

**ConfigMap not found:**
```bash
# Verify ConfigMap is applied
kubectl get configmap -n microservice-canary
kubectl describe configmap microservice-config -n microservice-canary
```

**Jaeger not accessible:**
```bash
# Check Jaeger deployment
kubectl get pods -n microservice-canary -l app=jaeger
kubectl port-forward -n microservice-canary svc/jaeger-ui 16686:16686
```

### Diagnostic Commands

Check deployment status:
```bash
kubectl get all -n microservice-canary
```

View logs:
```bash
kubectl logs -n microservice-canary deployment/microservice-stable
kubectl logs -n microservice-canary deployment/microservice-canary
```

Inspect configuration:
```bash
kubectl get configmap microservice-config -n microservice-canary -o yaml
```

## Advanced Usage

### Manual Scaling

Scale canary deployment:
```bash
kubectl scale deployment microservice-canary -n microservice-canary --replicas=2
```

Scale stable deployment:
```bash
kubectl scale deployment microservice-stable -n microservice-canary --replicas=1
```

### Custom Environment Configuration

Create custom ConfigMap:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: microservice-config
  namespace: microservice-canary
data:
  ENVIRONMENT: "staging"
  ERROR_RATE_DEFAULT: "2"
  # ... other configuration
```

Apply custom configuration:
```bash
kubectl apply -f custom-configmap.yaml
```

### Production Considerations

1. **Image Registry**: Update image references to your container registry
2. **Resource Limits**: Adjust based on actual workload requirements
3. **Network Policies**: Implement security restrictions
4. **RBAC**: Apply proper role-based access controls
5. **Secrets**: Use Kubernetes secrets for sensitive configuration
6. **Monitoring**: Integrate with Prometheus/Grafana for production monitoring

## Integration Points

### CI/CD Pipeline Integration

Example GitHub Actions integration:
```yaml
- name: Deploy Canary
  run: |
    .\k8s\canary\multi-env-canary.ps1 -Environment production -Action deploy

- name: Execute Rollout
  run: |
    .\k8s\canary\multi-env-canary.ps1 -Environment production -Action rollout
```

### Prometheus Integration

The microservice exposes metrics at `/metrics` endpoint for Prometheus scraping.

### Alerting

Configure alerts based on:
- Error rate thresholds
- Latency percentiles  
- Pod health status
- Traffic distribution

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Kubernetes logs and events
3. Verify ConfigMap configuration
4. Ensure proper RBAC permissions
