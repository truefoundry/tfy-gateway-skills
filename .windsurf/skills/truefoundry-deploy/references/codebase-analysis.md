# Codebase Analysis for Deployment

Scan the project to determine framework, app type, and compute indicators before suggesting resources.

## 1. Framework & Runtime Detection

Look at dependency files and entrypoints:

- `requirements.txt`, `pyproject.toml`, `setup.py` -> Python (check for FastAPI, Flask, Django, Celery, etc.)
- `package.json` -> Node.js (check for Express, Next.js, NestJS, etc.)
- `go.mod` -> Go
- `Dockerfile` -> check `FROM` image and `CMD`/`ENTRYPOINT`

## 2. Application Type Categorization

- **Web API / HTTP service** -- REST/GraphQL endpoint (FastAPI, Express, Django, etc.)
- **ML inference** -- Model serving (vLLM, TGI, Triton, transformers, torch, etc.)
- **Worker / queue consumer** -- Background processing (Celery, Bull, etc.)
- **Static site / frontend** -- Next.js SSR, React SPA, etc.
- **Data pipeline** -- Batch processing (Spark, pandas, etc.)

## 3. Compute Indicators

Check for signals that affect resource needs:

- ML libraries (`torch`, `transformers`, `vllm`, `tensorflow`) -> likely needs GPU + high memory
- Image/video processing (`Pillow`, `opencv`, `ffmpeg`) -> CPU-intensive
- In-memory caching or large datasets (`redis`, `pandas` with large files) -> memory-intensive
- Async/concurrent patterns (`asyncio`, `uvicorn workers`, `gunicorn`) -> can handle more load per CPU
- Database connections (`sqlalchemy`, `prisma`, `mongoose`) -> connection pooling matters

## 4. Load Questions by App Type

### For Web APIs / HTTP services

```
To suggest the right resources, I need to understand your expected load:

1. Expected requests per second (TPS)?
   - Low (< 10 TPS) -- internal tool, dev/testing
   - Medium (10-100 TPS) -- production API with moderate traffic
   - High (100-1000 TPS) -- high-traffic production service
   - Very high (1000+ TPS) -- needs autoscaling

2. Expected concurrent users?
   - Few (< 50) -- internal team
   - Moderate (50-500) -- typical B2B SaaS
   - Many (500+) -- consumer-facing

3. Average response time target?
   - < 100ms (real-time APIs)
   - < 500ms (standard web)
   - < 5s (batch/processing endpoints)

4. Is this for dev/staging or production?
```

### For ML inference services

```
To suggest the right resources:

1. What model are you serving? (model name + parameter count)
2. Expected inference requests per second?
   - Low (< 1 TPS) -- development/testing
   - Medium (1-10 TPS) -- production inference
   - High (10+ TPS) -- high-throughput serving
3. Max acceptable latency per request?
   - < 1s (real-time)
   - < 10s (near real-time)
   - < 60s (batch-style)
4. Batch size? (1 for online, higher for throughput)
```

### For workers / background processors

```
To suggest the right resources:

1. What kind of tasks? (data processing, image generation, email sending, etc.)
2. How many concurrent tasks should it handle?
3. Average task duration?
4. Peak task queue depth?
```

## 5. Resource Suggestion Presentation

Present a comparison table with defaults, suggested values, and let the user choose:

```
Based on your app (FastAPI web API, ~50 TPS, production):

| Resource      | Default (min) | Suggested    | Notes                              |
|---------------|---------------|--------------|-------------------------------------|
| CPU request   | 0.25 cores    | 1.0 cores    | 50 TPS with async needs ~1 core    |
| CPU limit     | 0.5 cores     | 2.0 cores    | Headroom for traffic spikes         |
| Memory request| 256 MB        | 512 MB       | FastAPI + dependencies baseline     |
| Memory limit  | 512 MB        | 1024 MB      | 2x request for safety margin        |
| Replicas (min)| 1             | 2            | HA for production                   |
| Replicas (max)| 1             | 4            | Autoscale for peak traffic          |
| GPU           | None          | None         | Not needed for this workload        |

Do you want to use the suggested values, or customize any of them?
```

Key rules:
- Always show the suggestion table -- don't pick values silently
- Let users override -- suggestions are starting points
- Mention trade-offs -- more resources = higher cost, fewer = risk of OOM/throttling
- Factor in environment -- dev gets minimal defaults, production gets HA suggestions
- Reference cluster capabilities -- only suggest GPU types actually available
