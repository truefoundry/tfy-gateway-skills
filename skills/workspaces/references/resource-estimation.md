# Resource Estimation

## CPU Estimation by Framework

| Framework | CPU per TPS | Notes |
|-----------|-------------|-------|
| Python async (FastAPI/uvicorn) | ~0.5 cores / 50 TPS | Simple CRUD |
| Python sync (Flask/Django) | ~1 core / 20 TPS | Thread-per-request |
| Node.js (Express) | ~0.5 cores / 100 TPS | Event loop |
| Go | ~0.25 cores / 200 TPS | Goroutines |
| ML inference (CPU-only) | 2-4 cores per instance | Model-dependent |

Add 50% buffer for CPU limit vs request.

## Memory Estimation by App Type

| App Type | Memory Range | Notes |
|----------|-------------|-------|
| Base Python app | 128-256 MB | No ML dependencies |
| Python + ML libraries | 2-8 GB | torch, transformers, etc. |
| Node.js app | 128-512 MB | Depends on data handled |
| Go app | 64-128 MB | Statically compiled |

Memory limit should be 1.5-2x request. Add memory for loaded models, connection pools, caches, request payloads.

## GPU Estimation

See `gpu-reference.md` for GPU sizing by model parameters.

## Replica Estimation

| Environment | Min Replicas | Max Replicas | Notes |
|-------------|-------------|-------------|-------|
| Dev/testing | 1 | 1 | No HA needed |
| Staging | 1 | 3 | Test scaling behavior |
| Production | 2 | 10 | Min 2 for high availability |
| High-traffic | 3 | 20+ | Based on load testing |
