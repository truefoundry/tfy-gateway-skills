# Load Analysis Question Templates

Ask targeted questions based on the detected application type to suggest appropriate resources.

## For Web APIs / HTTP Services

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

## For ML Inference Services

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

## For Workers / Background Processors

```
To suggest the right resources:

1. What kind of tasks? (data processing, image generation, email sending, etc.)
2. How many concurrent tasks should it handle?
3. Average task duration?
4. Peak task queue depth?
```
