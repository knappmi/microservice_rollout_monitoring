# Structured Telemetry Data Generator

This script generates structured logs and metrics from various operational scenarios to provide rich observability data that can be easily consumed by monitoring systems, log aggregators, and analysis tools.

## 🎯 Purpose

Generate structured telemetry data including:

- **Structured HTTP Request Logs**: JSON-formatted request/response data
- **Performance Metrics**: Response times, health scores, and percentiles  
- **Operational Context**: Scenario-based categorization and tagging
- **Real-time Metrics**: Aggregated statistics and reliability scores

## 🚀 Quick Start

### 1. Deploy the Microservice

```bash
cd scripts

# Simple deployment (recommended)
.\deploy-microservice.ps1

# Or use the full-featured script
.\multi-env-canary.ps1 -Environment local -Action deploy

# Wait for deployment, then set up port forwarding
kubectl port-forward -n microservice-canary svc/microservice-lb 5000:5000
```

### 2. Generate Structured Telemetry Data

```bash
cd scripts

# Install requirements
pip install requests

# Generate full telemetry dataset
python chatbot_training_generator.py

# Or run specific scenario
python chatbot_training_generator.py --scenario performance_degradation

# Custom microservice URL and output file
python chatbot_training_generator.py --url http://localhost:5000 --output my_telemetry.jsonl
```

### 3. Monitor Data Generation

```bash
# Watch the output file grow
tail -f telemetry_data.jsonl

# Monitor logs
tail -f telemetry_generator.log
```

## 📊 Telemetry Scenarios

### 1. **Baseline Operations** (10 minutes)
- Normal operation patterns
- Steady-state performance metrics
- Baseline error rates and response times

### 2. **Performance Degradation** (15 minutes)
- Gradual performance decline
- Increasing response times
- Memory pressure indicators

### 3. **Intermittent Failures** (20 minutes)
- Sporadic service failures
- Timeout errors and retries
- Connection issues

### 4. **High Load Scenario** (12 minutes)
- High traffic volume
- Stress testing patterns
- Resource utilization spikes

### 5. **Partial Outage** (18 minutes)
- Selective endpoint failures
- Mixed success/failure patterns
- Service degradation events

## 📈 Structured Output Format

Each line contains a JSON object with standardized fields for easy processing:

### HTTP Request Telemetry
```json
{
  "timestamp": "2025-07-31T19:45:00.123456",
  "log_level": "INFO",
  "event_type": "http_request",
  "request_id": "req_1722463500123456",
  "scenario": {
    "name": "performance_degradation",
    "description": "Gradual performance decline",
    "tags": ["performance", "degradation", "slow"]
  },
  "http": {
    "method": "GET",
    "url": "http://localhost:5000/health",
    "endpoint": "/health",
    "status_code": 200,
    "response_time_ms": 2341.5,
    "response_size_bytes": 156
  },
  "metrics": {
    "response_time_seconds": 2.3415,
    "response_time_category": "slow",
    "success": true,
    "client_error": false,
    "server_error": false,
    "health_score": 65
  },
  "service": {
    "name": "observability-demo-app",
    "version": "v1.0.0-stable",
    "environment": "local"
  }
}
```

### Scenario Metrics Summary
```json
{
  "timestamp": "2025-07-31T19:50:00.654321",
  "log_level": "INFO",
  "event_type": "scenario_metrics",
  "scenario": { "..." },
  "metrics": {
    "total_requests": 180,
    "error_count": 23,
    "error_rate": 0.1278,
    "slow_requests": 45,
    "slow_rate": 0.25,
    "average_response_time_seconds": 1.8234,
    "average_health_score": 72.3,
    "response_time_percentiles": {
      "p50_seconds": 1.2345,
      "p95_seconds": 4.5678,
      "p99_seconds": 8.9012
    }
  },
  "operational_summary": {
    "scenario_health": "degraded",
    "performance_category": "slow", 
    "reliability_score": 87.22
  }
}
```

## 🔧 Easy Data Consumption

The structured output is designed for easy integration with:

### Log Aggregation Systems
- **ELK Stack**: Direct ingestion into Elasticsearch
- **Splunk**: Structured JSON parsing
- **Fluentd/Fluent Bit**: Log forwarding and enrichment
- **Prometheus**: Convert metrics to time series

### Analysis Tools
- **Pandas**: Direct JSON Lines reading
- **Apache Spark**: Structured data processing
- **ClickHouse**: High-performance analytics
- **Grafana**: Dashboard visualization

### Example Usage Patterns

```bash
# Filter by scenario type
jq 'select(.scenario.name == "performance_degradation")' telemetry_data.jsonl

# Extract response time metrics
jq '.metrics.response_time_seconds' telemetry_data.jsonl | grep -v null

# Get error events only
jq 'select(.event_type == "http_request_error")' telemetry_data.jsonl

# Calculate average health score per scenario
jq -r 'select(.event_type == "scenario_metrics") | "\(.scenario.name): \(.metrics.average_health_score)"' telemetry_data.jsonl
```

## 📝 Customization

### Add New Scenarios
Edit the `load_scenarios()` method:

```python
{
    "name": "custom_scenario",
    "description": "Your custom scenario description", 
    "duration_minutes": 15,
    "requests_per_minute": 10,
    "tags": ["custom", "test", "scenario"]
}
```

### Modify Telemetry Fields
Update `capture_request_telemetry()` to add custom fields or modify the structure.

### Adjust Request Patterns
Modify endpoints list and request frequency to match your specific use case.

## 🎯 Expected Output

A complete telemetry session generates:

- **~1,500 structured request records** across all scenarios
- **5 aggregated metrics summaries** with operational insights
- **Session metadata** for tracking and correlation
- **Real-time streaming data** suitable for live monitoring

Perfect for feeding into monitoring systems, dashboards, and analysis pipelines! 📊
