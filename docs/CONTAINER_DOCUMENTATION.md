# Microservice Rollout Monitoring - Environment Documentation

## Overview

This project implements a microservice rollout monitoring system with OpenTelemetry instrumentation and distributed tracing capabilities. The system consists of multiple containers that work together to demonstrate SLO (Service Level Objective) monitoring, chaos engineering, and observability patterns.

## Container Architecture

### 1. Jaeger Tracing Service

**Container Name:** `jaeger-tracing` or `microservice_rollout_monitoring-jaeger-1`
**Image:** `jaegertracing/all-in-one:1.41`
**Purpose:** Distributed tracing backend for collecting, storing, and visualizing traces

#### Exposed Ports
- **16686**: Jaeger Web UI (Primary Interface)
- **4317**: OTLP gRPC receiver for trace ingestion
- **4318**: OTLP HTTP receiver for trace ingestion
- **14250**: gRPC receiver for Jaeger native protocol
- **14268**: HTTP receiver for Jaeger thrift format

#### Key Endpoints
- `http://localhost:16686/` - Jaeger Web UI Dashboard
- `http://localhost:16686/search` - Trace search interface
- `http://localhost:16686/api/services` - Available services API
- `http://localhost:16686/api/traces` - Trace query API

#### Environment Variables
- `COLLECTOR_OTLP_ENABLED=true` - Enables OpenTelemetry Protocol support
- `LOG_LEVEL=debug` - Sets logging verbosity

### 2. Microservice - Healthy Instance

**Container Name:** `microservice-healthy` or `microservice_rollout_monitoring-microservice-healthy-1`
**Image:** Built from local Dockerfile
**Purpose:** Baseline microservice instance with normal SLO performance

#### Exposed Ports
- **5001**: HTTP API endpoint (mapped from internal port 5000)

#### Application Endpoints
- `GET /` - Root endpoint returning service information
- `GET /users` - Returns list of sample users
- `GET /health` - Health check endpoint (returns "OK")
- `GET /metrics` - Prometheus-compatible metrics endpoint
- `GET /slo-config` - Current SLO configuration display

#### OpenTelemetry Configuration
- `OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger:4317`
- `OTEL_EXPORTER_OTLP_INSECURE=true`
- `OTEL_SERVICE_NAME=microservice-healthy`
- `OTEL_SERVICE_VERSION=1.0.0`
- `OTEL_RESOURCE_ATTRIBUTES=service.name=microservice-healthy,service.version=1.0.0`

#### SLO Configuration
- `SIM_BAD=false` - Disables chaos engineering features
- Normal response times (< 100ms typical)
- 99.9% availability target
- Error rate < 0.1%

### 3. Microservice - Chaos Instance

**Container Name:** `microservice-chaos` or `microservice_rollout_monitoring-microservice-chaos-1`
**Image:** Built from local Dockerfile
**Purpose:** Chaos engineering instance with degraded SLO performance for testing

#### Exposed Ports
- **5002**: HTTP API endpoint (mapped from internal port 5000)

#### Application Endpoints
- `GET /` - Root endpoint (may experience simulated failures)
- `GET /users` - User list (may experience latency or errors)
- `GET /health` - Health check (may simulate unhealthy states)
- `GET /metrics` - Metrics endpoint with chaos indicators
- `GET /slo-config` - SLO configuration showing chaos parameters

#### OpenTelemetry Configuration
- `OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger:4317`
- `OTEL_EXPORTER_OTLP_INSECURE=true`
- `OTEL_SERVICE_NAME=microservice-chaos`
- `OTEL_SERVICE_VERSION=1.0.0`
- `OTEL_RESOURCE_ATTRIBUTES=service.name=microservice-chaos,service.version=1.0.0`

#### Chaos Engineering Configuration
- `SIM_BAD=true` - Enables chaos engineering features
- `ERROR_RATE=0.3` - 30% of requests return errors
- `LATENCY_SIMULATION=true` - Adds artificial latency
- `MAX_LATENCY=2.0` - Maximum latency of 2 seconds
- `OUTAGE_SIMULATION=true` - Periodic service outages

### 4. Load Generator (Optional)

**Container Name:** `microservice_rollout_monitoring-load-generator-1`
**Image:** `curlimages/curl:latest`
**Purpose:** Automated traffic generation for testing and demonstration

#### Functionality
- Continuously sends HTTP requests to both healthy and chaos instances
- Tests all available endpoints on both services
- Generates realistic load patterns for trace collection
- Runs indefinitely until stopped

#### Test Pattern
```
GET http://microservice-healthy:5000/
GET http://microservice-healthy:5000/users  
GET http://microservice-healthy:5000/health
GET http://microservice-chaos:5000/
GET http://microservice-chaos:5000/users
GET http://microservice-chaos:5000/health
```

## Service Discovery and Networking

### Internal Network Communication
- All containers communicate via Docker internal network: `microservice_rollout_monitoring_default`
- Services reference each other by container name (e.g., `jaeger:4317`)
- No external dependencies required for inter-service communication

### External Access Points
- Jaeger UI: `http://localhost:16686`
- Healthy Service: `http://localhost:5001`
- Chaos Service: `http://localhost:5002`

## Health Checks and Monitoring

### Container Health Checks
All microservice containers include Docker health checks:
```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:5000/health || exit 1
```

### Service Dependencies
- Microservices depend on Jaeger for trace collection
- Load generator depends on both microservice instances
- Failed dependencies will prevent dependent services from starting

## Trace and Metrics Collection

### Automatic Instrumentation
- **HTTP requests**: Method, URL, status code, duration
- **Response timing**: Request/response cycle timing
- **Error tracking**: Exception details and stack traces

### Custom Instrumentation
- **SLO attributes**: `slo.sim_bad`, `slo.error_rate`
- **Performance metrics**: `response.latency_ms`
- **Health indicators**: `health.status`, `failure.type`
- **Business metrics**: `users.count`

### Trace Attributes
All traces include standardized attributes for monitoring:
- Service identification (name, version, environment)
- Request metadata (HTTP method, URL, user agent)
- Performance metrics (latency, error rates)
- Custom business logic indicators

## Development and Testing

### Local Development
```bash
# Build images
docker build -t microservice-app .

# Start core services
docker-compose up -d jaeger microservice-healthy

# Start with chaos testing
docker-compose up -d
```

### Testing Individual Services
```bash
# Test healthy service
curl http://localhost:5001/health

# Test chaos service  
curl http://localhost:5002/health

# View traces
open http://localhost:16686
```

### Debugging
```bash
# View container logs
docker-compose logs microservice-healthy
docker-compose logs microservice-chaos
docker-compose logs jaeger

# Inspect running containers
docker ps
docker-compose ps
```

## Production Considerations

### Security
- Microservices run as non-root user (`appuser`)
- Minimal base image (Python 3.10-slim)
- No sensitive data in environment variables

### Scalability
- Stateless microservice design
- Horizontal scaling supported via container orchestration
- Jaeger supports clustered deployments for production load

### Monitoring
- Comprehensive trace collection for all requests
- Health check endpoints for orchestrator integration
- Prometheus-compatible metrics export
- SLO compliance tracking through custom attributes
