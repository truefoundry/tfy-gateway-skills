from fastapi import FastAPI
from fastapi.responses import HTMLResponse

app = FastAPI(title="FastAPI Demo", version="1.0.0")


@app.get("/", response_class=HTMLResponse)
def root():
    return """
    <html>
      <head><title>FastAPI on TrueFoundry</title></head>
      <body>
        <h1>FastAPI Demo App</h1>
        <p>Running on TrueFoundry!</p>
        <ul>
          <li><a href="/health">/health</a></li>
          <li><a href="/items/1">/items/1</a></li>
          <li><a href="/docs">/docs</a> (Swagger UI)</li>
        </ul>
      </body>
    </html>
    """


@app.get("/health")
def health():
    return {"status": "healthy"}


@app.get("/items/{item_id}")
def get_item(item_id: int):
    return {
        "item_id": item_id,
        "name": f"Item {item_id}",
        "description": f"This is item {item_id}",
    }


@app.get("/api/hello")
def hello():
    return {"message": "Hello from TrueFoundry!"}
