from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .database import Base, engine
from .routes import items

Base.metadata.create_all(bind=engine)

app = FastAPI(title="Items API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(items.router)


@app.get("/")
def root():
    return {"status": "ok", "service": "items-api"}
