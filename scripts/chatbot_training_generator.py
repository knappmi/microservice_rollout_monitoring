#!/usr/bin/env python3
"""
Structured Telemetry Data Generator
Generates structured logs and metrics for observability and analysis
"""

import requests
import json
import time
import random
import logging
from datetime import datetime, timedelta
from concurrent.futures import ThreadPoolExecutor
import argparse

class StructuredTelemetryGenerator:
    def __init__(self, base_url="http://localhost:5000", output_file="telemetry_data.jsonl"):
        self.base_url = base_url
        self.output_file = output_file
        self.scenarios = []
        self.current_scenario = None
        
        # Setup logging for structured output
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('telemetry_generator.log'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)
    
    def load_scenarios(self):
        """Load predefined operational scenarios for telemetry generation"""
        self.scenarios = [
            {
                "name": "baseline_operations",
                "description": "Normal operation patterns",
                "duration_minutes": 10,
                "requests_per_minute": 12,
                "tags": ["baseline", "normal", "steady-state"]
            },
            {
                "name": "performance_degradation",
                "description": "Gradual performance decline",
                "duration_minutes": 15,
                "requests_per_minute": 15,
                "tags": ["performance", "degradation", "slow"]
            },
            {
                "name": "intermittent_failures",
                "description": "Sporadic service failures",
                "duration_minutes": 20,
                "requests_per_minute": 10,
                "tags": ["failures", "intermittent", "errors"]
            },
            {
                "name": "high_load_scenario",
                "description": "High traffic load testing",
                "duration_minutes": 12,
                "requests_per_minute": 30,
                "tags": ["load", "traffic", "stress"]
            },
            {
                "name": "partial_outage",
                "description": "Selective service unavailability",
                "duration_minutes": 18,
                "requests_per_minute": 8,
                "tags": ["outage", "partial", "selective"]
            }
        ]
    
    def generate_operational_context(self, scenario):
        """Generate operational context for structured logging"""
        context_patterns = {
            "baseline_operations": [
                "Regular system monitoring",
                "Scheduled health checks",
                "Normal user traffic patterns"
            ],
            "performance_degradation": [
                "System performance declining over time",
                "Response times increasing gradually",
                "Resource utilization trending upward"
            ],
            "intermittent_failures": [
                "Sporadic error responses",
                "Connection timeouts occurring",
                "Service availability fluctuating"
            ],
            "high_load_scenario": [
                "Traffic volume significantly elevated",
                "System under load testing",
                "Concurrent user activity high"
            ],
            "partial_outage": [
                "Some endpoints not responding",
                "Mixed success/failure patterns",
                "Service degradation in progress"
            ]
        }
        return random.choice(context_patterns.get(scenario["name"], ["Standard operational context"]))
    
    def capture_request_telemetry(self, endpoint, scenario_context):
        """Capture structured telemetry data for each request"""
        start_time = time.time()
        request_id = f"req_{int(start_time * 1000000)}"
        
        try:
            response = requests.get(f"{self.base_url}{endpoint}", timeout=10)
            duration = time.time() - start_time
            
            # Generate structured telemetry record
            telemetry_data = {
                "timestamp": datetime.now().isoformat(),
                "log_level": "INFO",
                "event_type": "http_request",
                "request_id": request_id,
                "scenario": {
                    "name": scenario_context["name"],
                    "description": scenario_context["description"],
                    "tags": scenario_context.get("tags", [])
                },
                "http": {
                    "method": "GET",
                    "url": f"{self.base_url}{endpoint}",
                    "endpoint": endpoint,
                    "status_code": response.status_code,
                    "response_time_ms": round(duration * 1000, 2),
                    "response_size_bytes": len(response.content),
                    "user_agent": response.request.headers.get("User-Agent", "telemetry-generator/1.0")
                },
                "metrics": {
                    "response_time_seconds": round(duration, 4),
                    "response_time_category": self.categorize_response_time(duration),
                    "success": response.status_code < 400,
                    "client_error": 400 <= response.status_code < 500,
                    "server_error": response.status_code >= 500,
                    "health_score": self.calculate_health_score(response.status_code, duration)
                },
                "service": {
                    "name": "observability-demo-app",
                    "version": "unknown",
                    "environment": "local"
                }
            }
            
            # Add response content if it's JSON (for structured analysis)
            try:
                if response.headers.get('content-type', '').startswith('application/json'):
                    json_content = response.json()
                    telemetry_data["response_data"] = json_content
                    
                    # Extract service metadata if available
                    if "version" in json_content:
                        telemetry_data["service"]["version"] = json_content.get("version", "unknown")
                    if "label" in json_content:
                        telemetry_data["service"]["label"] = json_content.get("label", "unknown")
                        
            except Exception:
                # If JSON parsing fails, just store a preview
                telemetry_data["response_preview"] = response.text[:200]
            
            return telemetry_data
            
        except requests.exceptions.RequestException as e:
            duration = time.time() - start_time
            
            # Generate error telemetry record
            return {
                "timestamp": datetime.now().isoformat(),
                "log_level": "ERROR",
                "event_type": "http_request_error",
                "request_id": request_id,
                "scenario": {
                    "name": scenario_context["name"],
                    "description": scenario_context["description"],
                    "tags": scenario_context.get("tags", [])
                },
                "http": {
                    "method": "GET",
                    "url": f"{self.base_url}{endpoint}",
                    "endpoint": endpoint,
                    "error_type": type(e).__name__,
                    "error_message": str(e),
                    "response_time_ms": round(duration * 1000, 2)
                },
                "metrics": {
                    "response_time_seconds": round(duration, 4),
                    "success": False,
                    "timeout": isinstance(e, requests.exceptions.Timeout),
                    "connection_error": isinstance(e, requests.exceptions.ConnectionError),
                    "health_score": 0
                },
                "service": {
                    "name": "observability-demo-app",
                    "version": "unknown",
                    "environment": "local"
                }
            }
    
    def categorize_response_time(self, duration):
        """Categorize response time for easier analysis"""
        if duration < 0.1:
            return "excellent"
        elif duration < 0.5:
            return "good"
        elif duration < 1.0:
            return "acceptable"
        elif duration < 3.0:
            return "slow"
        else:
            return "unacceptable"
    
    def calculate_health_score(self, status_code, duration):
        """Calculate a simple health score (0-100)"""
        score = 100
        
        # Deduct points for errors
        if status_code >= 500:
            score -= 50
        elif status_code >= 400:
            score -= 30
        
        # Deduct points for slow responses
        if duration > 3.0:
            score -= 30
        elif duration > 1.0:
            score -= 15
        elif duration > 0.5:
            score -= 5
        
        return max(0, score)
    
    def run_scenario(self, scenario):
        """Run a telemetry collection scenario"""
        self.logger.info(f"Starting telemetry collection for scenario: {scenario['name']}")
        self.current_scenario = scenario
        
        # Generate operational context
        operational_context = self.generate_operational_context(scenario)
        
        scenario_context = {
            "name": scenario["name"],
            "description": scenario["description"],
            "operational_context": operational_context,
            "tags": scenario.get("tags", []),
            "start_time": datetime.now().isoformat(),
            "duration_minutes": scenario["duration_minutes"]
        }
        
        # Log scenario start
        scenario_start_log = {
            "timestamp": datetime.now().isoformat(),
            "log_level": "INFO",
            "event_type": "scenario_start",
            "scenario": scenario_context,
            "message": f"Starting telemetry collection: {scenario['name']}"
        }
        
        with open(self.output_file, 'a') as f:
            f.write(json.dumps(scenario_start_log) + '\n')
        
        endpoints = ["/", "/health", "/users", "/version", "/slo-config"]
        end_time = datetime.now() + timedelta(minutes=scenario["duration_minutes"])
        
        collected_data = []
        
        while datetime.now() < end_time:
            # Generate requests at the specified rate
            requests_this_minute = scenario["requests_per_minute"]
            
            for _ in range(requests_this_minute):
                endpoint = random.choice(endpoints)
                telemetry_data = self.capture_request_telemetry(endpoint, scenario_context)
                collected_data.append(telemetry_data)
                
                # Write telemetry data immediately for real-time processing
                with open(self.output_file, 'a') as f:
                    f.write(json.dumps(telemetry_data) + '\n')
                
                # Sleep between requests to maintain rate
                time.sleep(60 / requests_this_minute)
        
        # Generate scenario summary metrics
        summary = self.generate_scenario_metrics(collected_data, scenario_context)
        with open(self.output_file, 'a') as f:
            f.write(json.dumps(summary) + '\n')
        
        self.logger.info(f"Completed telemetry collection for scenario: {scenario['name']}")
        return collected_data
    
    def generate_scenario_metrics(self, collected_data, scenario_context):
        """Generate aggregated metrics for the scenario"""
        total_requests = len(collected_data)
        error_count = sum(1 for req in collected_data if not req.get("metrics", {}).get("success", True))
        slow_count = sum(1 for req in collected_data if req.get("metrics", {}).get("response_time_seconds", 0) > 2.0)
        
        avg_response_time = sum(req.get("metrics", {}).get("response_time_seconds", 0) for req in collected_data) / max(1, total_requests)
        avg_health_score = sum(req.get("metrics", {}).get("health_score", 0) for req in collected_data) / max(1, total_requests)
        
        # Calculate response time percentiles
        response_times = [req.get("metrics", {}).get("response_time_seconds", 0) for req in collected_data]
        response_times.sort()
        
        p50 = response_times[int(len(response_times) * 0.5)] if response_times else 0
        p95 = response_times[int(len(response_times) * 0.95)] if response_times else 0
        p99 = response_times[int(len(response_times) * 0.99)] if response_times else 0
        
        return {
            "timestamp": datetime.now().isoformat(),
            "log_level": "INFO",
            "event_type": "scenario_metrics",
            "scenario": scenario_context,
            "metrics": {
                "total_requests": total_requests,
                "error_count": error_count,
                "error_rate": round(error_count / max(1, total_requests), 4),
                "slow_requests": slow_count,
                "slow_rate": round(slow_count / max(1, total_requests), 4),
                "average_response_time_seconds": round(avg_response_time, 4),
                "average_health_score": round(avg_health_score, 2),
                "response_time_percentiles": {
                    "p50_seconds": round(p50, 4),
                    "p95_seconds": round(p95, 4),
                    "p99_seconds": round(p99, 4)
                }
            },
            "operational_summary": {
                "scenario_health": "healthy" if avg_health_score > 80 else "degraded" if avg_health_score > 50 else "unhealthy",
                "performance_category": self.categorize_response_time(avg_response_time),
                "reliability_score": round((1 - (error_count / max(1, total_requests))) * 100, 2)
            }
        }
    
    def run_full_telemetry_session(self):
        """Run all scenarios to generate comprehensive structured telemetry data"""
        self.load_scenarios()
        
        # Clear output file and add session header
        with open(self.output_file, 'w') as f:
            session_start = {
                "timestamp": datetime.now().isoformat(),
                "log_level": "INFO",
                "event_type": "session_start",
                "message": "Starting structured telemetry data collection session",
                "session_config": {
                    "total_scenarios": len(self.scenarios),
                    "base_url": self.base_url,
                    "output_file": self.output_file
                }
            }
            f.write(json.dumps(session_start) + '\n')
        
        self.logger.info("Starting structured telemetry data collection session")
        
        for scenario in self.scenarios:
            self.run_scenario(scenario)
            
            # Brief pause between scenarios
            time.sleep(30)
        
        # Add session completion log
        with open(self.output_file, 'a') as f:
            session_end = {
                "timestamp": datetime.now().isoformat(),
                "log_level": "INFO",
                "event_type": "session_complete",
                "message": "Structured telemetry data collection session completed",
                "output_file": self.output_file
            }
            f.write(json.dumps(session_end) + '\n')
        
        self.logger.info(f"Telemetry data collection complete. Output written to {self.output_file}")

def main():
    parser = argparse.ArgumentParser(description="Generate structured telemetry data from microservice scenarios")
    parser.add_argument("--url", default="http://localhost:5000", help="Base URL of the microservice")
    parser.add_argument("--output", default="telemetry_data.jsonl", help="Output file for telemetry data")
    parser.add_argument("--scenario", help="Run specific scenario only")
    
    args = parser.parse_args()
    
    generator = StructuredTelemetryGenerator(args.url, args.output)
    
    if args.scenario:
        generator.load_scenarios()
        scenario = next((s for s in generator.scenarios if s["name"] == args.scenario), None)
        if scenario:
            generator.run_scenario(scenario)
        else:
            print(f"Scenario '{args.scenario}' not found")
    else:
        generator.run_full_telemetry_session()

if __name__ == "__main__":
    main()
