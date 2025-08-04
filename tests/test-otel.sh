#!/bin/bash

echo "OpenTelemetry Microservice Testing Script"
echo "============================================="

# Build the image
echo "Building Docker image..."
docker build -t microservice-otel .

# Test different configurations
echo ""
echo "Testing OpenTelemetry Auto-Instrumentation"
echo ""

# 1. Test with console exporter (traces to stdout)
echo "Testing with Console Exporter (traces to stdout)"
docker run -d --name test-console \
  -p 5001:5000 \
  -e OTEL_TRACES_EXPORTER=console \
  -e OTEL_LOGS_EXPORTER=console \
  -e OTEL_SERVICE_NAME=microservice-console \
  microservice-otel

echo "    Service running at: http://localhost:5001"
echo "    Check docker logs test-console to see traces"
echo ""

# 2. Test with OTLP exporter (for Jaeger/observability platforms)
echo "Testing with OTLP Exporter (ready for Jaeger)"
docker run -d --name test-otlp \
  -p 5002:5000 \
  -e OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317 \
  -e OTEL_EXPORTER_OTLP_INSECURE=true \
  -e OTEL_SERVICE_NAME=microservice-otlp \
  -e SIM_BAD=true \
  -e ERROR_RATE=0.4 \
  -e LATENCY_SIMULATION=true \
  microservice-otel

echo "    Service running at: http://localhost:5002"
echo "    This version has SLO chaos enabled!"
echo ""

# 3. Test calls
echo "Making test requests..."
sleep 3

echo "   Testing healthy service (console traces):"
curl -s http://localhost:5001/ && echo ""
curl -s http://localhost:5001/users && echo ""
curl -s http://localhost:5001/health && echo ""

echo ""
echo "   Testing chaos service (OTLP traces):"
curl -s http://localhost:5002/ && echo ""
curl -s http://localhost:5002/users && echo ""
curl -s http://localhost:5002/slo-config && echo ""

echo ""
echo "   View traces:"
echo "   Console traces: docker logs test-console"
echo "   OTLP traces: Need Jaeger/OTEL collector running"
echo ""
echo "   Cleanup:"
echo "   docker rm -f test-console test-otlp"
echo ""
echo "   For full observability stack:"
echo "   docker-compose up -d"
echo "   Visit Jaeger UI: http://localhost:16686"
