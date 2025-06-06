"""
Python Event Grid Listener Template
- Listens for Event Grid events (HTTP POST)
- Parses payload, writes JSON to Redis
- Uses environment variables for config
- Run: pip install flask azure-eventgrid redis
"""
import os
import json
from flask import Flask, request, abort
import redis

app = Flask(__name__)

# Config from environment
REDIS_HOST = os.environ.get("REDIS_HOST")
REDIS_KEY = os.environ.get("REDIS_KEY")
REDIS_PORT = int(os.environ.get("REDIS_PORT", 6380))
REDIS_SSL = True

# Connect to Redis
r = redis.StrictRedis(host=REDIS_HOST, port=REDIS_PORT, password=REDIS_KEY, ssl=REDIS_SSL)

@app.route("/eventgrid", methods=["POST"])
def eventgrid_listener():
    try:
        events = request.get_json()
        if not isinstance(events, list):
            events = [events]
        for event in events:
            data = event.get("data", {})
            # Example: store by userId
            user_id = data.get("userId", "unknown")
            r.set(f"token-usage:{user_id}", json.dumps(data))
        return "OK", 200
    except Exception as e:
        print(f"Error: {e}")
        abort(400)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
