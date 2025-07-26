from flask import Flask
from threading import Thread
from prometheus_client import start_http_server, Summary, Counter, Gauge, Histogram

# Basic flask app to test canary deployment
app = Flask("python-web-app")

# Define root route
@app.route("/")
def root():
    return "Application is running!"

# K8s health endpoint
@app.route("/health")
def health():
    is_healthy = health_check()
    if is_healthy:
        return "OK", 200
    else:
        return "ERROR", 500

# Promtheus metrics
@app.route("/metrics")
def metrics():
    return "# HELP flask_requests_total Total number of requests\n# TYPE flask_requests_total counter\nflask_requests_total 0\n"

# Users endpoint to return test data
@app.route("/users")
def users():
    users = {"users": [
        {"id": 1, "name": "John Doe", "email": "john@example.com"},
        {"id": 2, "name": "Jane Smith", "email": "jane@example.com"},
        {"id": 3, "name": "Bob Johnson", "email": "bob@example.com"}
    ]}
    return users

def health_check():
    # Placeholder for health check logic
    return True

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000, debug=False)