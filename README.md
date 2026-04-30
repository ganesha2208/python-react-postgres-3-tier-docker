# 3-Tier FastAPI + React + Postgres CRUD App

A simple 3-tier application demonstrating create / read / update / delete on an `items` table.

```
frontend (React)  --->  backend (FastAPI)  --->  database (Postgres)
   :3000                    :8000                    :5432
```

## Project layout

```
fast-api-project/
├── backend/
│   ├── app/
│   │   ├── main.py          # FastAPI app + CORS
│   │   ├── database.py      # SQLAlchemy engine/session
│   │   ├── models.py        # ORM models
│   │   ├── schemas.py       # Pydantic schemas
│   │   ├── crud.py          # DB operations
│   │   └── routes/items.py  # /items endpoints
│   ├── requirements.txt
│   ├── .env
│   └── Dockerfile
├── frontend/
│   ├── public/index.html
│   ├── src/
│   │   ├── App.js           # CRUD UI
│   │   ├── api.js           # axios client
│   │   ├── index.js
│   │   └── styles.css
│   ├── package.json
│   └── Dockerfile
└── docker-compose.yml
```

## Run with Docker (recommended)

```bash
docker compose up --build
```

Then open:

- Frontend: http://localhost:3000
- API docs: http://localhost:8000/docs
- Postgres: `localhost:5432` (user `postgres` / pass `postgres` / db `itemsdb`)

## Run locally without Docker

### 1. Postgres

Start Postgres yourself and create the `itemsdb` database, or run just the db service:

```bash
docker compose up db
```

### 2. Backend

```bash
cd backend
python -m venv .venv
# Windows: .venv\Scripts\activate
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

### 3. Frontend

```bash
cd frontend
npm install
npm start
```

## API endpoints

| Method | Path              | Description       |
| ------ | ----------------- | ----------------- |
| GET    | `/items/`         | List all items    |
| GET    | `/items/{id}`     | Get one item      |
| POST   | `/items/`         | Create an item    |
| PUT    | `/items/{id}`     | Update an item    |
| DELETE | `/items/{id}`     | Delete an item    |

### Example payload

```json
{
  "name": "Notebook",
  "description": "A5 hardcover",
  "price": 9.99,
  "quantity": 25
}
```
