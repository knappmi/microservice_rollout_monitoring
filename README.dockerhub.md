# Observability Demo Microservice

A production-ready Python Flask microservice designed for observability testing, canary deployments, and monitoring demonstrations. This application includes built-in OpenTelemetry instrumentation, Prometheus metrics, and configurable failure simulation capabilities.

## 🚀 Features

- **OpenTelemetry Integration**: Full distributed tracing support
- **Prometheus Metrics**: Built-in metrics endpoint (`/metrics`)
- **Health Checks**: Kubernetes-ready health endpoints (`/health`)
- **Failure Simulation**: Configurable error rates, latency, and outages
- **Production Ready**: Security hardened, multi-stage build, non-root user
- **Environment Flexible**: Works with Jaeger, Prometheus, Grafana, and other observability tools

## 📋 Quick Start

### Basic Usage
```bash
# From GitHub Container Registry (recommended)
docker run -p 5000:5000 ghcr.io/knappmi/observability-demo-app

# From Docker Hub (alternative)
docker run -p 5000:5000 knappmi/observability-demo-app
```

Visit: http://localhost:5000

### With Jaeger Tracing
```bash
docker run -p 5000:5000 \
  -e OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger:4317 \
  ghcr.io/knappmi/observability-demo-app
```

### With Failure Simulation
```bash
docker run -p 5000:5000 \
  -e SIM_BAD=true \
  -e ERROR_RATE=0.3 \
  -e LATENCY_SIMULATION=true \
  -e MAX_LATENCY=5.0 \
  ghcr.io/knappmi/observability-demo-app
```

## 🔧 Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SIM_BAD` | `false` | Enable failure simulation |
| `ERROR_RATE` | `0.05` | Error rate (0.0-1.0) when SIM_BAD=true |
| `LATENCY_SIMULATION` | `false` | Enable latency simulation |
| `MAX_LATENCY` | `1.0` | Maximum latency in seconds |
| `OUTAGE_SIMULATION` | `false` | Enable complete service outages |
| `VERSION_LABEL` | `v1.0.0-stable` | Custom version identifier |
| `OTEL_SERVICE_NAME` | `observability-demo-app` | Service name for tracing |
| `OTEL_SERVICE_VERSION` | `1.0.0` | Service version for tracing |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | - | OTLP endpoint for traces |

## 📊 Endpoints

| Endpoint | Description |
|----------|-------------|
| `/` | Main application endpoint |
| `/health` | Health check endpoint |
| `/metrics` | Prometheus metrics |
| `/version` | Version information |

## 🐳 Docker Compose Example

```yaml
version: '3.8'
services:
  microservice:
    image: ghcr.io/knappmi/observability-demo-app:latest
    ports:
      - "5000:5000"
    environment:
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger:4317
      - SIM_BAD=false
    depends_on:
      - jaeger

  jaeger:
    image: jaegertracing/all-in-one:latest
    ports:
      - "16686:16686"
      - "4317:4317"
```

## ☸️ Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: observability-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: observability-demo
  template:
    metadata:
      labels:
        app: observability-demo
    spec:
      containers:
      - name: app
        image: ghcr.io/knappmi/observability-demo-app:latest
        ports:
        - containerPort: 5000
        env:
        - name: OTEL_EXPORTER_OTLP_ENDPOINT
          value: "http://jaeger:4317"
        livenessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 5
          periodSeconds: 10
```

## 🎯 Use Cases

### Canary Deployments
Perfect for testing canary deployment strategies:
- **Stable Version**: `SIM_BAD=false`
- **Problematic Canary**: `SIM_BAD=true ERROR_RATE=0.5`

### Load Testing
Simulate different failure scenarios:
```bash
# High error rate scenario
docker run -p 5000:5000 -e SIM_BAD=true -e ERROR_RATE=0.8 ghcr.io/knappmi/observability-demo-app

# High latency scenario  
docker run -p 5000:5000 -e LATENCY_SIMULATION=true -e MAX_LATENCY=10.0 ghcr.io/knappmi/observability-demo-app
```

### Observability Stack Testing
Ideal for testing monitoring and alerting:
- Generates realistic traces, metrics, and logs
- Configurable failure patterns
- Health check endpoints for monitoring

## Security Features

- Runs as non-root user (`appuser`)
- Multi-stage build minimizes attack surface
- No unnecessary packages in final image
- Follows container security best practices

## OpenTelemetry Integration

This microservice provides comprehensive observability:

- **Traces**: Automatic instrumentation for Flask requests
- **Metrics**: Custom business metrics + Prometheus
- **Logs**: Structured logging with correlation IDs
- **Resource Attributes**: Service identification and versioning

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes  
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

- **Issues**: Report bugs or request features on GitHub
- **Documentation**: Full documentation available in the repository
- **Community**: Join discussions in GitHub Discussions

---

Perfect for: DevOps engineers, SRE teams, observability testing, canary deployments, chaos engineering, and monitoring demonstrations.
