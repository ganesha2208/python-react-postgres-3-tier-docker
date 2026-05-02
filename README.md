# 3-Tier CRUD App — FastAPI · React · Postgres

A production-style 3-tier CRUD application for managing inventory items, deployed end-to-end with Docker, AWS ECR, and GitHub Actions CI/CD.

> **Live demo:** http://65.2.168.104/  *(replace with your URL when forking)*

---

## Architecture

```
                       Internet  (HTTP :80)
                            │
                            ▼
                   ┌─────────────────┐
                   │ Caddy (reverse  │
                   │     proxy)      │
                   └─┬───────────┬───┘
                /api/*           │ /
                     ▼           ▼
               ┌──────────┐  ┌──────────┐
               │ FastAPI  │  │  React   │
               │ backend  │  │ (nginx)  │
               │  :8000   │  │   :80    │
               └────┬─────┘  └──────────┘
                    │
                    ▼
              ┌──────────┐
              │ Postgres │
              │  :5432   │
              └──────────┘

Caddy is the only container exposed to the public internet.
Backend, frontend, and database are reachable only through Docker's internal network.
```

### CI/CD flow

```
git push origin main
        │
        ▼
GitHub Actions runner
   1. Build backend image      ─┐
   2. Build frontend image      ├─►  Push to AWS ECR
                                 │   (tagged with commit SHA)
                                ─┘
                                 │
                                 ▼
   3. SSH into EC2 with deploy key
   4. docker compose pull
   5. docker compose up -d --remove-orphans
   6. docker image prune

Total time per deploy: ~90s with cache.
```

---

## Tech stack

| Layer       | Tech                              | Why                                                        |
| ----------- | --------------------------------- | ---------------------------------------------------------- |
| Frontend    | React 18 (Vite) + Axios           | Modern toolchain, fast HMR, small production bundle        |
| Backend     | FastAPI + SQLAlchemy + Pydantic   | Type-safe, auto OpenAPI docs at `/docs`                    |
| Database    | Postgres 16 (alpine)              | Industry standard, ACID, healthcheck-friendly              |
| Reverse proxy | Caddy 2                         | Automatic HTTPS via Let's Encrypt with one-line config     |
| Containers  | Docker + Compose v2               | Reproducible local + prod environments                     |
| Image registry | AWS ECR                        | Private registry, integrates with EC2 IAM                  |
| CI/CD       | GitHub Actions                    | Free, in-platform, no extra service to manage              |
| Host        | AWS EC2 (Ubuntu 24.04)            | Cheapest viable single-host deployment                     |

---

## Project structure

```
fast-api-project/
├── backend/
│   ├── app/
│   │   ├── main.py            # FastAPI app + CORS
│   │   ├── database.py        # SQLAlchemy engine/session
│   │   ├── models.py          # ORM models (Item)
│   │   ├── schemas.py         # Pydantic request/response schemas
│   │   ├── crud.py            # DB operations
│   │   └── routes/items.py    # /items endpoints
│   ├── requirements.txt
│   └── Dockerfile             # Python 3.11-slim, single-stage
├── frontend/
│   ├── src/
│   │   ├── App.jsx            # CRUD UI
│   │   ├── api.js             # Axios client; calls relative /api
│   │   ├── main.jsx
│   │   └── styles.css
│   ├── nginx.conf             # SPA fallback for React Router
│   ├── package.json
│   └── Dockerfile             # multi-stage: node build → nginx serve
├── Caddyfile                  # /api/* → backend, / → frontend
├── docker-compose.yml         # local dev: builds images
├── docker-compose.prod.yml    # production: pulls from ECR
├── .env.example               # template for prod env vars
└── .github/workflows/
    └── deploy.yml             # CI: build → push to ECR → SSH redeploy
```

---

## Run locally

Requirements: Docker Desktop (or Docker Engine + Compose v2).

```bash
docker compose up --build
```

Open:
- App: http://localhost:3000
- API docs: http://localhost:8000/docs *(only exposed in dev compose)*
- Postgres: `localhost:5432` (`postgres`/`postgres`/`itemsdb`)

Stop: `docker compose down`. Reset DB: `docker compose down -v`.

---

## Deploy to AWS EC2

### One-time AWS setup

1. **Two ECR repos:** `items-backend`, `items-frontend` (private, scan-on-push enabled).
2. **IAM policy** allowing `ecr:GetAuthorizationToken` (resource `*`) plus push/pull actions scoped to those two repo ARNs.
3. **IAM user** with that policy attached; generate access keys.
4. **EC2 instance** (Ubuntu 24.04, t3.micro is enough); install Docker, Compose v2, AWS CLI v2.
5. **Security group** inbound: 80 (HTTP), 443 (HTTPS), 22 (SSH from your IP only).

### One-time GitHub setup

Repo → Settings → Secrets and variables → Actions, add:

| Secret                    | Value                                                          |
| ------------------------- | -------------------------------------------------------------- |
| `AWS_ACCESS_KEY_ID`       | IAM user access key                                            |
| `AWS_SECRET_ACCESS_KEY`   | IAM user secret                                                |
| `EC2_HOST`                | EC2 public IP                                                  |
| `EC2_SSH_KEY`             | Private key authorized in EC2's `~/.ssh/authorized_keys` (use a dedicated CI key, not your main `.pem`) |

### One-time EC2 prep

```bash
git clone <repo-url>
cd python-react-postgres-3-tier-docker
cp .env.example .env
# edit .env: set ECR_REGISTRY=<acct>.dkr.ecr.<region>.amazonaws.com
```

### Deploy

```bash
git push origin main
```

Actions tab shows the run. ~90s later the new version is live. Roll back by setting `TAG=<old-short-sha>` in `.env` on EC2 and running `docker compose -f docker-compose.prod.yml up -d`.

---

## Design decisions

### Frontend uses a relative `/api` path
Build-time hardcoding of API URLs (`VITE_API_URL=http://1.2.3.4:8000`) ties the image to a specific host and breaks under HTTPS (mixed-content). A relative `/api` lets Caddy own routing — same image runs on any host.

### Caddy as the only public service
Backend and frontend are bound to Docker's internal network only (no `ports:` mapping). Eliminates the "is port 8000 supposed to be open?" class of mistake and gives a single ingress to reason about.

### Pinned image tags, no `:latest`
Every deploy uses the **commit SHA** as the tag. You can answer "what's running in prod?" by looking at one container's image. Rollback is changing one env var. ECR tag immutability is compatible with this.

### Dedicated CI deploy key
GitHub Actions SSHes in with a key that isn't the EC2 `.pem`. If the secret leaks, revoke that single line in `authorized_keys` — the master key stays safe.

### Layer caching for fast builds
GitHub Actions uses `type=gha` cache scoped per service. First build ~3 min; subsequent builds ~30s if only one service changed.

### `.env` is gitignored, `.env.example` is committed
Standard 12-factor — secrets out of source, but the schema is documented.

---

## API reference

Auto-generated OpenAPI docs at `/docs` (Swagger) and `/redoc`.

| Method | Path           | Description    |
| ------ | -------------- | -------------- |
| GET    | `/items/`      | List all items |
| GET    | `/items/{id}`  | Get one item   |
| POST   | `/items/`      | Create an item |
| PUT    | `/items/{id}`  | Update an item |
| DELETE | `/items/{id}`  | Delete an item |

Example payload:

```json
{
  "name": "Notebook",
  "description": "A5 hardcover",
  "price": 9.99,
  "quantity": 25
}
```

---

## Possible improvements

- **HTTPS via DuckDNS + Let's Encrypt** — Caddy already wired; just set `SITE_ADDRESS=<subdomain>.duckdns.org` in `.env`.
- **OIDC trust between GitHub and AWS** — replace long-lived access keys with short-lived role assumption.
- **Tests in CI** — pytest for backend, Vitest for frontend, run before the build job.
- **Separate dev/staging/prod environments** — protected branches + per-environment workflows.
- **Database backups** — `pg_dump` to S3 on a cron, or RDS instead of containerized Postgres.
- **Observability** — structured logs to CloudWatch, healthcheck endpoint, basic metrics.
