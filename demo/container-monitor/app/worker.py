import logging
import os
import time

from redis import Redis


logging.basicConfig(level=logging.INFO, format="%(asctime)s checkout-worker %(levelname)s %(message)s")
redis = Redis(host=os.getenv("REDIS_HOST", "redis"), decode_responses=True, socket_timeout=5)

while True:
    try:
        now = time.time()
        redis.set("checkout:worker:heartbeat", str(now), ex=15)
        item = redis.blpop("checkout:orders", timeout=1)
        if item:
            logging.info("processed order=%s", item[1])
    except Exception as exc:
        logging.error("queue operation failed: %s", exc)
        time.sleep(2)
