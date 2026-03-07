# Multi-Service Error Handling

## Partial Deployment Failure
```
Component {name} failed to deploy. Other components are running.

Deployed successfully: db, redis, backend
Failed: frontend (Build error -- check Dockerfile)
Not attempted: (none -- frontend was last)

Options:
1. Fix the Dockerfile and redeploy just frontend
2. Check build logs: Use `logs` skill
3. Already-deployed components are still running
```

## Circular Dependencies
```
Detected circular dependency: service-a -> service-b -> service-a

This cannot be deployed in sequence. Options:
1. Break the cycle -- make one service start without the other (add retry logic)
2. Use async communication (message queue) instead of direct HTTP
3. Merge the tightly coupled services
```

## Cross-Service Connection Failed
```
Service {name} can't connect to {dependency}.
Check:
1. Is {dependency} running? (Use `applications` skill)
2. DNS correct? Expected: {name}.{namespace}.svc.cluster.local:{port}
3. Port correct? Check the dependency's port configuration
4. Credentials match? Verify env vars match infrastructure passwords
5. Any unresolved compose hostname left? (`db`, `redis`, `backend`, etc.)
```

## docker-compose Feature Not Supported
```
Your docker-compose.yml uses {feature} which doesn't have a direct
TrueFoundry equivalent.

Workaround: {suggested workaround}

Want to proceed without this feature, or adjust the approach?
```
