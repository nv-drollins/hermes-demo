import os
import time
import uuid

from flask import Flask, jsonify, request
from redis import Redis


app = Flask(__name__)
redis = Redis(host=os.getenv("REDIS_HOST", "redis"), decode_responses=True, socket_timeout=1)
heartbeat_max_age = int(os.getenv("WORKER_HEARTBEAT_MAX_AGE", "8"))


def dependency_status():
    status = {"redis": "down", "worker": "down"}
    try:
        if redis.ping():
            status["redis"] = "up"
            heartbeat = redis.get("checkout:worker:heartbeat")
            if heartbeat and time.time() - float(heartbeat) <= heartbeat_max_age:
                status["worker"] = "up"
    except Exception as exc:
        app.logger.error("redis dependency check failed: %s", exc)
    return status


@app.get("/health")
def health():
    return jsonify({"service": "checkout-api", "status": "up"})


@app.get("/ready")
def ready():
    dependencies = dependency_status()
    ready_now = all(value == "up" for value in dependencies.values())
    code = 200 if ready_now else 503
    if not ready_now:
        app.logger.error("readiness failed: %s", dependencies)
    return jsonify({"service": "checkout-api", "ready": ready_now, "dependencies": dependencies}), code


@app.post("/orders")
def create_order():
    payload = request.get_json(silent=True) or {}
    order_id = str(uuid.uuid4())
    try:
        redis.rpush("checkout:orders", order_id)
    except Exception as exc:
        app.logger.error("order enqueue failed: %s", exc)
        return jsonify({"error": "queue unavailable"}), 503
    return jsonify({"id": order_id, "item": payload.get("item", "demo-item"), "status": "queued"}), 202


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
