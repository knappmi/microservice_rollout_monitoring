from flask import Flask
from threading import Thread
from prometheus_client import start_http_server, Summary, Counter, Gauge, Histogram

# Get ENV variables for SLO simulation
import os
import random
import time

SIM_BAD = os.getenv("SIM_BAD", "false").lower() == "true"
ERROR_RATE = float(os.getenv("ERROR_RATE", "0.2"))  # Default 20% error rate when SIM_BAD is true
LATENCY_SIMULATION = os.getenv("LATENCY_SIMULATION", "false").lower() == "true"
MAX_LATENCY = float(os.getenv("MAX_LATENCY", "2.0"))  # Default 2 seconds max latency
OUTAGE_SIMULATION = os.getenv("OUTAGE_SIMULATION", "false").lower() == "true"

# Basic flask app to test canary deployment
app = Flask("python-web-app")

# Define root route
@app.route("/")
def root():
    # Simulate latency
    latency = simulate_latency()
    
    # Check if service should fail
    if not health_sim():
        return "Service Unavailable", 503
    
    return f"Application is running! (Response time: {latency:.2f}s)"

# K8s health endpoint
@app.route("/health")
def health():
    # Simulate health check with randomizer
    is_healthy = health_sim()
    if is_healthy:
        return "OK", 200
    else:
        return "ERROR", 500

# Promtheus metrics
@app.route("/metrics")
def metrics():
    return "# HELP flask_requests_total Total number of requests\n# TYPE flask_requests_total counter\nflask_requests_total 0\n"

# SLO Configuration endpoint
@app.route("/slo-config")
def slo_config():
    """Returns current SLO simulation configuration"""
    config = {
        "slo_simulation": {
            "sim_bad": SIM_BAD,
            "error_rate": ERROR_RATE,
            "latency_simulation": LATENCY_SIMULATION,
            "max_latency": MAX_LATENCY,
            "outage_simulation": OUTAGE_SIMULATION
        },
        "description": {
            "sim_bad": "Master switch for all bad SLO simulations",
            "error_rate": "Probability of returning errors (0.0-1.0)",
            "latency_simulation": "Enable artificial latency delays",
            "max_latency": "Maximum latency in seconds",
            "outage_simulation": "Enable complete service outages (5% chance)"
        }
    }
    return config

# Users endpoint to return test data
@app.route("/users")
def users():
    # Simulate latency
    latency = simulate_latency()
    
    # Check health before processing
    if not health_sim():
        return "Service Unavailable", 503
    
    users_data = {"users": [
        {"id": 1, "name": "John Doe", "email": "john@example.com"},
        {"id": 2, "name": "Jane Smith", "email": "jane@example.com"},
        {"id": 3, "name": "Bob Johnson", "email": "bob@example.com"}
    ], "response_time": f"{latency:.2f}s"}
    return users_data


# SLO Simulation Functions
def simulate_latency():
    """Simulate network latency issues"""
    if LATENCY_SIMULATION and SIM_BAD:
        latency = random.uniform(0.1, MAX_LATENCY)
        time.sleep(latency)
        return latency
    return 0

def simulate_error_rate():
    """Simulate error rate based on ERROR_RATE environment variable"""
    if SIM_BAD:
        return random.random() < ERROR_RATE
    return False

def simulate_outage():
    """Simulate complete service outage"""
    if OUTAGE_SIMULATION and SIM_BAD:
        # 5% chance of complete outage when outage simulation is enabled
        return random.random() < 0.05
    return False

def health_sim():
    """
    Comprehensive health simulation that checks for:
    - Complete outages
    - Error rate simulation
    - Returns False if any failure condition is met
    """
    # Check for complete outage first
    if simulate_outage():
        return False
    
    # Check for error rate simulation
    if simulate_error_rate():
        return False
    
    return True

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000, debug=False)