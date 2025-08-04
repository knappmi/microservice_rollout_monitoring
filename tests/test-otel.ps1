Write-Host "OpenTelemetry Microservice Testing Script" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
$ErrorActionPreference = "Stop"

# Build the image
Write-Host "Building Docker image..." -ForegroundColor Yellow
docker build -t microservice-otel .

# Test different configurations
Write-Host ""
Write-Host "Testing OpenTelemetry Auto-Instrumentation" -ForegroundColor Cyan
Write-Host ""

# 1. Test with console exporter (traces to stdout)
Write-Host "Testing with Console Exporter (traces to stdout)" -ForegroundColor Blue
docker run -d --name test-console `
  -p 5001:5000 `
  -e OTEL_TRACES_EXPORTER=console `
  -e OTEL_LOGS_EXPORTER=console `
  -e OTEL_SERVICE_NAME=microservice-console `
  microservice-otel

Write-Host "   Service running at: http://localhost:5001" -ForegroundColor Green
Write-Host "   Check 'docker logs test-console' to see traces" -ForegroundColor Yellow
Write-Host ""

# 2. Test with OTLP exporter (for Jaeger/observability platforms)
Write-Host "Testing with OTLP Exporter (ready for Jaeger)" -ForegroundColor Blue
docker run -d --name test-otlp `
  -p 5002:5000 `
  -e OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317 `
  -e OTEL_EXPORTER_OTLP_INSECURE=true `
  -e OTEL_SERVICE_NAME=microservice-otlp `
  -e SIM_BAD=true `
  -e ERROR_RATE=0.4 `
  -e LATENCY_SIMULATION=true `
  microservice-otel

Write-Host "   Service running at: http://localhost:5002" -ForegroundColor Green
Write-Host "   This version has SLO chaos enabled!" -ForegroundColor Red
Write-Host ""

# 3. Test calls
Write-Host "Making test requests..." -ForegroundColor Cyan
Start-Sleep 3

Write-Host "   Testing healthy service (console traces):" -ForegroundColor Yellow
try { (Invoke-WebRequest http://localhost:5001/).Content }
catch { Write-Host "Request failed: $_" -ForegroundColor Red }

try { (Invoke-WebRequest http://localhost:5001/users).Content }
catch { Write-Host "Request failed: $_" -ForegroundColor Red }

try { (Invoke-WebRequest http://localhost:5001/health).Content }
catch { Write-Host "Request failed: $_" -ForegroundColor Red }

Write-Host ""
Write-Host "   Testing chaos service (OTLP traces):" -ForegroundColor Yellow
try { (Invoke-WebRequest http://localhost:5002/).Content }
catch { Write-Host "Request failed: $_" -ForegroundColor Red }

try { (Invoke-WebRequest http://localhost:5002/slo-config).Content }
catch { Write-Host "Request failed: $_" -ForegroundColor Red }

Write-Host ""
Write-Host "   View traces:" -ForegroundColor Cyan
Write-Host "   Console traces: docker logs test-console" -ForegroundColor White
Write-Host "   OTLP traces: Need Jaeger/OTEL collector running" -ForegroundColor White
Write-Host ""
Write-Host "   Cleanup:" -ForegroundColor Cyan
Write-Host "   docker rm -f test-console test-otlp" -ForegroundColor White
Write-Host ""
Write-Host "   For full observability stack:" -ForegroundColor Cyan
Write-Host "   docker-compose up -d" -ForegroundColor White
Write-Host "   Visit Jaeger UI: http://localhost:16686" -ForegroundColor White
