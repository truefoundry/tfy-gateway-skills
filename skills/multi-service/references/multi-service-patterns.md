# Compound AI Application Patterns

For AI-powered applications with multiple components (LLM + vector DB + API + frontend), follow these patterns.

## RAG Application (Retrieval-Augmented Generation)

```
Dependency Graph:
  frontend -> backend -> llm
                      -> vectordb
                      -> db
```

**Deploy order:** db, vectordb -> llm -> backend -> frontend

**Backend env wiring:**
```python
env = {
    "DATABASE_URL": "postgresql://postgres:{password}@{name}-db-postgresql.{ns}.svc.cluster.local:5432/ragdb",
    "QDRANT_URL": "http://{name}-vectordb-qdrant.{ns}.svc.cluster.local:6333",
    "LLM_BASE_URL": "http://{name}-llm.{ns}.svc.cluster.local:8000/v1",
    "LLM_MODEL_NAME": "{served-model-name}",
}
```

## AI Agent with Tools

```
Dependency Graph:
  agent-api -> llm
            -> tool-server
            -> db
```

**Deploy order:** db -> tool-server, llm (parallel) -> agent-api

## Full-Stack SaaS with AI

```
Dependency Graph:
  frontend -> backend -> db
                      -> redis
                      -> llm
                      -> worker -> db
                                -> redis
                                -> rabbitmq
```

**Deploy order:** db, redis, rabbitmq (parallel) -> llm -> worker, backend (parallel) -> frontend

## Monorepo Support

For monorepos with multiple services:

1. **Detect structure** -- look for directories with their own Dockerfile, package.json, or requirements.txt
2. **Each service gets its own deployment** -- separate manifest or deploy.py per service
3. **Shared code** -- if services share code, each Dockerfile should COPY the shared directory
4. **Build context** -- set `build_context_path` to the repo root if services reference parent directories

```
monorepo/
├── services/
│   ├── api/
│   │   ├── Dockerfile
│   │   └── main.py
│   ├── worker/
│   │   ├── Dockerfile
│   │   └── worker.py
│   └── frontend/
│       ├── Dockerfile
│       └── package.json
├── shared/
│   └── models.py
└── docker-compose.yml
```
