# Sales Leaderboard Example

A full-stack sales leaderboard application deployed on TrueFoundry, demonstrating how to compose multiple services together: a Redis cache, a FastAPI backend, and a static frontend.

## Architecture

```
                    +-------------------+
                    |     Frontend      |
                    |  (nginx, port 80) |
                    +--------+----------+
                             |
                      GET /api/leaderboard
                             |
                    +--------v----------+
                    |     Backend       |
                    | (FastAPI, :8000)  |
                    +--------+----------+
                             |
                        read/write
                             |
                    +--------v----------+
                    |      Redis        |
                    |  (Helm, :6379)    |
                    +-------------------+
```

## Prerequisites

- The `tfy` CLI installed and logged in (`pip install truefoundry && tfy login`)
- `envsubst` available (included in most systems via `gettext`)
- Environment variables set:

```bash
export TFY_WORKSPACE_FQN=org:cluster:workspace
```

## Quick Start (CLI)

Deploy everything at once:

```bash
./deploy-all.sh
```

This applies the manifests for Redis, then the backend, then the frontend -- in that order.

## API Fallback

If the `tfy` CLI is not available, use the REST API approach. Each component has a `deploy-api.sh` script:

```bash
export TFY_BASE_URL=https://your-org.truefoundry.com
export TFY_API_KEY=tfy-xxxxx
export TFY_WORKSPACE_FQN=org:cluster:workspace

cd redis && bash deploy-api.sh && cd ..
cd backend && bash deploy-api.sh && cd ..
cd frontend && bash deploy-api.sh && cd ..
```

## Individual Components

### Redis

```bash
cd redis && bash deploy.sh
```

Deploys a Redis instance via the Bitnami Helm chart (`oci://registry-1.docker.io/bitnamicharts/redis` v20.6.2). Single master, no replicas. Password defaults to `changeme` -- override with `REDIS_PASSWORD` env var.

### Backend

```bash
cd backend && bash deploy.sh
```

A FastAPI service with:

- `GET /health` -- health check (reports Redis connectivity)
- `GET /api/leaderboard` -- returns ranked sales data
- `POST /api/leaderboard/refresh` -- refreshes the Redis cache

Falls back to in-memory data if Redis is unavailable.

### Frontend

```bash
cd frontend && bash deploy.sh
```

A single-page dashboard served by nginx. Fetches leaderboard data from the backend API, displays summary cards and a ranked table.

## Customization

- **Redis password**: `export REDIS_PASSWORD=your-password` before deploying
- **Redis host**: The backend defaults to `example-redis-master.<namespace>.svc.cluster.local`. Override with `REDIS_HOST`
- **Backend URL for frontend**: Set `BACKEND_URL` env var. If frontend and backend share a domain (via path-based routing), leave it empty
- **Sample data**: Edit `backend/main.py` `SAMPLE_DATA` to change the leaderboard entries

## Project Structure

```
sales-leaderboard/
  deploy-all.sh              # Master deploy script (CLI)
  redis/
    manifest.yaml            # Redis Helm chart manifest
    deploy.sh                # CLI deploy (tfy apply)
    deploy-api.sh            # API fallback deploy
  backend/
    manifest.yaml            # Backend service manifest
    main.py                  # FastAPI application
    requirements.txt         # Python dependencies
    Dockerfile               # Container build
    deploy.sh                # CLI deploy (tfy apply)
    deploy-api.sh            # API fallback deploy
  frontend/
    manifest.yaml            # Frontend service manifest
    index.html               # Single-page leaderboard UI
    Dockerfile               # nginx container
    deploy.sh                # CLI deploy (tfy apply)
    deploy-api.sh            # API fallback deploy
```
