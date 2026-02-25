# Async Service: Python Library Pattern

Use the Python library pattern when processing time exceeds 1 minute per message, you need direct queue consumption control, or you want custom acknowledgment patterns. Requires Python.

## Step 1: Install the Library

```bash
pip install truefoundry[async]
```

## Step 2: Implement the Handler

```python
# worker.py
from truefoundry.async_service import AsyncHandler, Message

class MyHandler(AsyncHandler):
    def __init__(self):
        # Initialize models, connections, etc.
        pass

    async def process(self, message: Message) -> dict:
        """Process a single message from the queue."""
        payload = message.body
        # Your processing logic here (can take minutes)
        result = {"status": "processed", "output": payload}
        return result

handler = MyHandler()
```

## Step 3: Deploy

Use the same `deploy.py` approach as the sidecar pattern but replace `SidecarPattern` with `PythonLibraryPattern` configuration in the SDK, or set `"pattern": "python-library"` in the API manifest. The entry command should point to your worker script.
