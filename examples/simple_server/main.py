from fastapi import FastAPI

app = FastAPI(title="Simple Server")


@app.get("/health")
def health():
    return {"status": "ok"}
