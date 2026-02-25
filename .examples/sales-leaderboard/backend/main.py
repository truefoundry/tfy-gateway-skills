import json
import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Sales Leaderboard API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

REDIS_HOST = os.getenv("REDIS_HOST", "example-redis-master.default.svc.cluster.local")
REDIS_PASSWORD = os.getenv("REDIS_PASSWORD", "")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))

LEADERBOARD_KEY = "sales:leaderboard"

SAMPLE_DATA = [
    {"name": "Sarah Chen", "region": "West", "sales": 487500, "deals": 47},
    {"name": "Marcus Johnson", "region": "East", "sales": 412300, "deals": 38},
    {"name": "Priya Patel", "region": "Central", "sales": 389000, "deals": 42},
    {"name": "James O'Brien", "region": "South", "sales": 356700, "deals": 31},
    {"name": "Elena Rodriguez", "region": "West", "sales": 298400, "deals": 28},
    {"name": "David Kim", "region": "East", "sales": 275900, "deals": 25},
    {"name": "Aisha Mohammed", "region": "Central", "sales": 234100, "deals": 22},
    {"name": "Ryan Cooper", "region": "South", "sales": 198600, "deals": 19},
    {"name": "Lisa Nakamura", "region": "West", "sales": 156200, "deals": 14},
    {"name": "Tom Bradley", "region": "East", "sales": 89500, "deals": 8},
]


def _get_redis():
    """Return a Redis client or None if unavailable."""
    try:
        import redis

        client = redis.Redis(
            host=REDIS_HOST,
            port=REDIS_PORT,
            password=REDIS_PASSWORD or None,
            decode_responses=True,
            socket_connect_timeout=2,
        )
        client.ping()
        return client
    except Exception:
        return None


def _build_leaderboard(data: list[dict]) -> list[dict]:
    """Sort by sales descending and assign ranks."""
    ranked = sorted(data, key=lambda x: x["sales"], reverse=True)
    for i, entry in enumerate(ranked, 1):
        entry["rank"] = i
    return ranked


@app.get("/health")
def health():
    redis_ok = _get_redis() is not None
    return {"status": "healthy", "redis_connected": redis_ok}


@app.get("/api/leaderboard")
def get_leaderboard():
    r = _get_redis()
    if r:
        cached = r.get(LEADERBOARD_KEY)
        if cached:
            return _build_leaderboard(json.loads(cached))
        # Seed cache on first read
        r.set(LEADERBOARD_KEY, json.dumps(SAMPLE_DATA), ex=3600)
    return _build_leaderboard(SAMPLE_DATA)


@app.post("/api/leaderboard/refresh")
def refresh_leaderboard():
    r = _get_redis()
    if r:
        r.set(LEADERBOARD_KEY, json.dumps(SAMPLE_DATA), ex=3600)
        return {"status": "refreshed", "source": "redis"}
    return {"status": "refreshed", "source": "memory"}
