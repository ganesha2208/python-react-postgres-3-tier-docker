# Interview Prep — 3-Tier CRUD on AWS with CI/CD

This file is a personal study guide. It captures (1) everything we built from scratch in plain English, (2) every error we hit and how we fixed it, and (3) a ready-to-speak script for explaining the project to an interviewer.

---

## Table of contents

1. [What we built (one-paragraph summary)](#1-what-we-built)
2. [Step-by-step in simple words](#2-step-by-step-in-simple-words)
3. [Errors I hit and how I fixed them](#3-errors-i-hit-and-how-i-fixed-them)
4. [Explain project here (interview script)](#4-explain-project-here-interview-script)
5. [Likely follow-up questions](#5-likely-follow-up-questions)

---

## 1. What we built

A small inventory app where a user can create, view, edit, and delete items. The app has three tiers: a **React** UI in the browser, a **FastAPI** backend that handles requests, and a **Postgres** database. Everything runs in **Docker** containers. The whole thing is deployed to an **AWS EC2** instance, and a **GitHub Actions** pipeline rebuilds and redeploys the app automatically every time we push code to GitHub.

Public URL during build: `http://65.2.168.104/`

---

## 2. Step-by-step in simple words

### Stage A — Get the app running on EC2

1. **Cloned the repo onto the EC2 instance** with `git clone`. This gave us the source code, a Dockerfile for each service, and a `docker-compose.yml` that ties them together.

2. **Installed Docker and Docker Compose v2 on EC2** (`sudo apt install docker.io docker-compose-v2`), enabled the Docker service to start on boot, and added the `ubuntu` user to the `docker` group so we wouldn't need `sudo` every time.

3. **Opened ports in the EC2 security group** — initially 3000 (React), 8000 (FastAPI), 22 (SSH). Postgres port 5432 was deliberately left closed to the internet.

4. **Started the stack with `docker compose up --build`.** This builds three images (frontend, backend, db), creates a Docker network, runs all three containers, and connects them.

5. **Found the EC2 public IP and tried to open the app** at `http://<EC2-IP>:3000`. The page loaded but the API calls failed with "Network Error."

### Stage B — Fix the CORS error

6. **Identified the cause.** The browser console showed an `OPTIONS /items/` request returning 400. This is a CORS preflight — when a browser is about to make a non-simple cross-origin request (POST/PUT/DELETE with JSON), it first asks "are you allowed to talk to me?" The backend's allow-list only had `localhost:3000`, so requests from `http://<EC2-IP>:3000` were rejected.

7. **Updated `backend/app/main.py`** to allow all origins (`allow_origins=["*"]`, `allow_credentials=False`). Since this app has no cookies or auth, this is safe.

### Stage C — Make the frontend portable (relative `/api`)

8. **Realised a deeper problem.** The frontend was baking the API URL into its bundle at *build time* via `VITE_API_URL`. That meant the same image only worked for one specific EC2 IP. If the IP ever changed, we'd have to rebuild.

9. **Changed `frontend/src/api.js`** so the default API URL is the relative path `/api`. The browser resolves this against the current page's host, so the same image works anywhere.

10. **Removed the `VITE_API_URL` build arg from `docker-compose.yml`** so the Dockerfile's default kicks in.

### Stage D — Add Caddy as a reverse proxy

11. **Created a `Caddyfile`** with two rules:
    - Anything starting with `/api/*` → strip the `/api` prefix → forward to the backend (`backend:8000`)
    - Everything else → forward to the frontend (`frontend:80`)

12. **Updated `docker-compose.yml`:**
    - Added a new `caddy` service publishing ports 80 and 443
    - Removed the public `ports:` mappings on backend and frontend (they're now internal-only)
    - Removed the public mapping on Postgres for safety
    - Added named volumes for Caddy's data and config (so TLS certs persist across restarts)

13. **Updated the EC2 security group** — opened 80 and 443, removed 3000 / 8000 / 5432.

14. **Result:** the only door into the EC2 is now Caddy on port 80, which routes traffic internally. Cleaner, smaller attack surface.

### Stage E — Set up AWS ECR (private image registry)

15. **Opened ECR in the AWS console** (Mumbai region, `ap-south-1`) and created two private repositories: `items-backend` and `items-frontend`. Enabled "scan on push" so AWS scans images for known CVEs.

16. **Created an IAM policy** called `GitHubActionsECRPushPolicy`. It allows:
    - `ecr:GetAuthorizationToken` on resource `*` (required by AWS)
    - Image push/pull actions scoped only to the two ECR repo ARNs (least-privilege)

17. **Attached the policy to the IAM user** (we used the existing `Ganesha_1` user — see the trade-off note in the errors section).

18. **Installed AWS CLI v2 on EC2** and ran `aws configure` with the IAM user's access key + secret + region.

19. **Tested ECR login** with `aws ecr get-login-password | docker login --password-stdin <registry>`. Saw "Login Succeeded" — confirmed the IAM permissions and credentials chain work end-to-end.

### Stage F — Build the GitHub Actions CI/CD pipeline

20. **Created a production compose file** `docker-compose.prod.yml`. Same shape as the dev compose but the `backend` and `frontend` services pull images from ECR (`${ECR_REGISTRY}/items-backend:${TAG}`) instead of building locally.

21. **Created a `.env.example`** documenting which env vars the prod compose needs (`ECR_REGISTRY`, `TAG`, `SITE_ADDRESS`, Postgres creds). Added `.env` to `.gitignore` so real secrets never get committed.

22. **Generated an SSH deploy key** on the local Windows machine with `ssh-keygen -t ed25519 -f gh-deploy-key`. Critical detail: this is a *separate* key from the EC2 `.pem`. If the deploy key ever leaks, we just remove that one line from `~/.ssh/authorized_keys` on EC2 — the master key stays safe.

23. **Added the public key** (`gh-deploy-key.pub`) to EC2's `~/.ssh/authorized_keys` and verified by SSHing in from Windows with `ssh -i gh-deploy-key ubuntu@<IP>`.

24. **Added 4 secrets in GitHub repo Settings → Secrets and variables → Actions:**
    - `AWS_ACCESS_KEY_ID`
    - `AWS_SECRET_ACCESS_KEY`
    - `EC2_HOST` (the public IP)
    - `EC2_SSH_KEY` (the full contents of the private key file)

25. **Wrote `.github/workflows/deploy.yml`** with two jobs:
    - **`build-and-push`** — checks out code, logs into AWS, builds backend image, builds frontend image, pushes both to ECR tagged with the **short commit SHA** (e.g. `a1b2c3d`).
    - **`deploy`** — SSHes into EC2 with the deploy key, runs `git pull`, sets `TAG=<sha>` in the environment, logs Docker into ECR, runs `docker compose -f docker-compose.prod.yml pull && up -d`, then prunes old images.

26. **Pushed everything to GitHub.** Watched the Actions tab. Both jobs went green. Visited `http://65.2.168.104/` — app worked.

### Stage G — Verify CI/CD end-to-end

27. **Made a visible UI change** (changed the page heading to include emojis), committed, pushed. ~90 seconds later the heading changed on the live site without us touching EC2 manually. This was the proof that the pipeline works.

### Stage H — Polish

28. **Added a `/health` endpoint** to the backend that runs `SELECT 1` against Postgres and returns `{"status":"ok","db":"ok"}`. This is the standard probe shape used by Kubernetes / load balancers.

29. **Wrote a comprehensive README** with an architecture diagram, tech stack table, deployment flow, design decisions, and a "future improvements" list. Recruiters read READMEs first.

### Stage I (optional) — HTTPS

Skipped for now. Caddy is already in place, so when ready: register a free DuckDNS subdomain pointing to the EC2 IP, set `SITE_ADDRESS=<sub>.duckdns.org` in `.env`, restart Caddy, and Let's Encrypt issues a real certificate automatically.

---

## 3. Errors I hit and how I fixed them

These are real talking points. Interviewers love hearing about debugging because anyone can copy a tutorial — but solving real errors shows actual understanding.

### Error 1 — "Network Error" in the browser

- **What happened:** Frontend loaded fine but the Create button failed.
- **Root cause:** Browser preflight (`OPTIONS`) returned 400 because the backend's CORS allow-list only contained `http://localhost:3000`. The actual origin was `http://65.2.168.104:3000`.
- **Fix:** Updated FastAPI's `CORSMiddleware` to `allow_origins=["*"]` and `allow_credentials=False` (you can't use `*` with credentials — browsers reject it).
- **Lesson:** GET worked because it's a "simple request" without preflight. POST/PUT/DELETE with JSON triggers a preflight, which is where most CORS bugs show up.

### Error 2 — Frontend still hitting `localhost:8000` after refactor

- **What happened:** Even after changing `api.js` to use `/api` and rebuilding, the bundle was still calling `http://localhost:8000`.
- **Root cause:** The `Dockerfile` defaulted `VITE_API_URL` to `http://localhost:8000`. When I removed the build arg from `docker-compose.yml`, the Dockerfile default kicked in and the JS fallback (`|| "/api"`) never ran.
- **Fix:** Changed the Dockerfile's `ARG VITE_API_URL=/api` so the default matches what we actually want.
- **Lesson:** When you have multiple layers of defaults (JS fallback, Docker ARG, compose arg), the lowest-priority one is whichever is set first. Don't assume your code-level fallback will run if a build-time value is already set.

### Error 3 — Stale image after rebuild

- **What happened:** After fixing the Dockerfile, the served bundle still had the old code.
- **Root cause:** Docker layer caching reused old layers; the running container also wasn't recreated to use the new image.
- **Fix:** `docker compose build --no-cache frontend && docker compose up -d --force-recreate frontend`.
- **Lesson:** Always force-recreate the container after a build. `up` with the same image often skips the recreate step.

### Error 4 — `awscli` package not found on Ubuntu 24.04

- **What happened:** `sudo apt install awscli` returned "Package has no installation candidate."
- **Root cause:** Ubuntu 24.04 (Noble) dropped the v1 awscli package because it was outdated.
- **Fix:** Installed AWS CLI v2 from the official zip:
  ```bash
  curl -o awscliv2.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
  unzip awscliv2.zip
  sudo ./aws/install
  ```
- **Lesson:** Don't trust apt to give you the latest version of cloud tools. Always check the vendor's recommended install method.

### Error 5 — Lost the AWS secret access key

- **What happened:** Created an IAM access key, wrote down the access key ID, but missed the secret.
- **Root cause:** AWS shows the secret access key **exactly once** at creation time. There is no "show secret again" button anywhere.
- **Fix:** Deleted the access key and created a new one. Copied both this time.
- **Lesson:** When AWS shows you a secret, copy it immediately. Use the "Download .csv" button if available.

### Error 6 — `AccessDeniedException` on ECR login

- **What happened:** `aws ecr get-login-password` returned `User: arn:aws:iam::...:user/Ganesha_1 is not authorized to perform: ecr:GetAuthorizationToken`.
- **Root cause:** `aws configure` had been set up with my personal user (`Ganesha_1`) which had no ECR permissions.
- **Fix:** Two options. The clean way is to configure with the dedicated `github-actions-ecr` service-user keys. I chose the simpler way: attached the `GitHubActionsECRPushPolicy` to `Ganesha_1`.
- **Lesson (and what I'd say in an interview):** "For a learning project I attached the policy to my personal user. In a real production setup I'd use a dedicated service user — or even better, OIDC federation between GitHub and AWS, so no long-lived keys exist at all."

### Error 7 — Wrong registry URL (used IAM identity ID, not account ID)

- **What happened:** `docker login` failed because I'd typed `AIDAYGKJ4KHWDTLJNYGNO.dkr.ecr...` as the registry.
- **Root cause:** That `AIDA…` thing is an IAM **identity ID**, not an AWS **account ID**. They look similar but they're different.
- **Fix:** The 12-digit account ID is `563332534764` — visible in the ARN of any AWS error. The correct registry URL is `563332534764.dkr.ecr.ap-south-1.amazonaws.com`.
- **Lesson:** Account ID = 12 digits, no letters. If your registry URL has letters in it, it's wrong.

### Error 8 — SSH `authorized_keys` corrupted by paste line-breaks

- **What happened:** After running `echo "ssh-ed25519 ... github-actions-deploy" >> ~/.ssh/authorized_keys`, the key got written as 3 separate lines instead of 1, breaking SSH login.
- **Root cause:** Terminal/chat copy-paste can introduce hard line breaks inside long strings. Bash treats each newline as a command terminator.
- **Fix:** Opened `~/.ssh/authorized_keys` in `vim`, deleted the 3 broken pieces, manually typed/pasted the key as one continuous line.
- **Lesson:** For SSH keys, always paste-then-verify with `tail -1`. If the output isn't one full line, fix it.

### Error 9 — PowerShell `Move-Item` broken across lines

- **What happened:** Tried to move two key files with one `Move-Item` call but the source list ended in a comma at line break, so PowerShell waited for a destination that was on the next line. Files weren't moved.
- **Fix:** Ran two separate `Move-Item` calls, one per file.
- **Lesson:** When pasting commands into PowerShell, beware of trailing commas — they tell PowerShell "more arguments coming on the next line."

### Error 10 — "The security token included in the request is invalid" in CI

- **What happened:** First GitHub Actions run failed at the AWS configure step.
- **Root cause:** When I pasted the AWS access key and secret into GitHub Secrets, an extra newline or space sneaked in.
- **Fix:** Deleted both secrets, re-copied them carefully (no quotes, no whitespace, no newline), re-added them, re-ran the workflow.
- **Lesson:** GitHub Secrets are write-only — you can't view them after creation to check for typos. Strict whitespace hygiene is required.

### Error 11 — ECR tag immutability rejected `:latest`

- **What happened:** Second CI run failed: `The image tag 'latest' already exists in the 'items-backend' repository and cannot be overwritten because the tag is immutable.`
- **Root cause:** I'd accidentally created the ECR repos with **tag immutability enabled**. The first push succeeded; subsequent pushes to the same `:latest` tag were blocked.
- **Fix:** Removed the `:latest` tag from the workflow's push step. Now we only push the **commit SHA** as the tag (`items-backend:a1b2c3d`).
- **Lesson:** This was actually a happy accident. Pinned-SHA tags are the production-correct approach — you can answer "what's running in prod" by reading one container's image, and rolling back is trivial. Immutability forced me into the right pattern.

---

## 4. Explain project here (interview script)

This is what to say when an interviewer asks "tell me about a project on your resume."

### The 60-second pitch

> "I built a small inventory CRUD app — three tiers: React frontend, FastAPI backend, Postgres database — and deployed it to AWS EC2 with a full CI/CD pipeline. Every container is Dockerized. There's a Caddy reverse proxy in front so only port 80 is exposed publicly; the backend, frontend, and database all live on Docker's internal network. The interesting part is the pipeline: when I push to `main`, GitHub Actions builds two Docker images, tags them with the commit SHA, pushes to AWS ECR, then SSHes into EC2 with a dedicated deploy key, pulls the new images, and recreates the containers. End to end it takes about 90 seconds. I went out of my way to use immutable image tags — no `:latest` — so I can always tell exactly which commit is running, and rollback is just changing one env var."

### The deeper version (3-5 minutes)

> "Let me walk through it from a `git push` and tell you what happens.
>
> When I push to `main`, GitHub Actions kicks off a workflow with two jobs. The first job, `build-and-push`, checks out the code, configures AWS credentials from secrets, logs into ECR, then uses Buildx with GitHub Actions cache to build the backend image and the frontend image. Both get tagged with the short commit SHA — for example `a1b2c3d`. They get pushed to two private ECR repos in `ap-south-1`.
>
> The second job, `deploy`, depends on the first. It uses the `appleboy/ssh-action` to SSH into the EC2 instance with a private key I'd stored in GitHub Secrets. The script does a `git pull` on the repo (so EC2 has the latest `docker-compose.prod.yml`), exports `TAG=a1b2c3d` and `ECR_REGISTRY=…`, runs `aws ecr get-login-password | docker login`, then `docker compose -f docker-compose.prod.yml pull && up -d --remove-orphans`. Compose pulls the new images and recreates only the containers whose images changed. Finally, `docker image prune -f` cleans up old layers so EC2 disk doesn't fill up over time.
>
> A few choices I made deliberately:
>
> First, the **frontend uses a relative `/api` path**. The same image works on any host because routing is handled by Caddy. If I'd hardcoded the EC2 IP at build time, every IP change would mean a rebuild.
>
> Second, **only Caddy is exposed publicly.** The backend and frontend containers don't have any host port mappings — they're only reachable through the Docker network. This makes the attack surface smaller and means I can't accidentally have ports `:8000` or `:3000` open to the internet.
>
> Third, **immutable SHA tags.** ECR has tag immutability turned on. Every deploy uses `items-backend:a1b2c3d` — the actual commit SHA — instead of `:latest`. If something breaks in production I can answer "what's running" by reading the container's image, and I can roll back by setting `TAG=<previous-sha>` in the EC2 `.env` and running `docker compose up -d`.
>
> Fourth, **dedicated deploy key, not the EC2 .pem.** I generated a separate ed25519 keypair just for CI. The public key sits in EC2's `authorized_keys`. The private key sits in GitHub Secrets. If GitHub ever gets compromised and the secret leaks, I delete that one line from `authorized_keys` — my actual EC2 master key is untouched.
>
> Fifth, **least-privilege IAM.** The policy I created is scoped to `ecr:GetAuthorizationToken` on `*` (which AWS requires) and ECR push/pull actions only on the two specific repo ARNs. The CI user can't read S3, can't touch EC2, can't even see other ECR repos.
>
> Things I'd add next: OIDC federation between GitHub and AWS so I can drop the long-lived access keys entirely; tests in CI before the build job; HTTPS via Let's Encrypt — Caddy is already in place, I just need a domain; and observability with structured logs and a real healthcheck endpoint exposed to a load balancer."

### Why each choice (one-liners to memorize)

| Choice                              | Why                                                         |
| ----------------------------------- | ----------------------------------------------------------- |
| Caddy as the only public service    | Single ingress, smaller attack surface, auto-HTTPS ready    |
| Relative `/api` path in the frontend | Image works on any host; survives IP changes                |
| Pinned commit-SHA image tags         | Traceability, easy rollback, ECR-immutability friendly      |
| Dedicated SSH deploy key             | Limits blast radius if the GitHub secret leaks              |
| Least-privilege IAM policy           | The CI user can do exactly its job — nothing else           |
| Multi-stage frontend Dockerfile      | Build with Node, serve with nginx → small final image       |
| `docker-compose.prod.yml` separate from dev | Local dev builds locally; prod pulls from ECR        |
| `.env` gitignored, `.env.example` committed | 12-factor — secrets out of source, but schema documented |

---

## 5. Likely follow-up questions

### "What happens if the EC2 instance reboots?"

> "All containers have `restart: unless-stopped`, so they come back up automatically. The Postgres data is in a named Docker volume (`db_data`) so it persists across restarts. Caddy's certs are in `caddy_data` — also persistent. The one thing that doesn't survive a stop/start is the EC2 public IP — I'd attach an Elastic IP for that, or use DuckDNS with a cron job that re-registers the IP."

### "How would you roll back a bad deploy?"

> "Two ways. The simple way: SSH to EC2, edit `.env` to set `TAG=<previous-short-sha>`, run `docker compose -f docker-compose.prod.yml up -d`. Compose pulls the older image and recreates the containers. The cleaner way: revert the bad commit in git and push — the pipeline re-deploys the previous code automatically."

### "Why didn't you use Kubernetes / ECS / Fargate?"

> "For one app on one instance, Compose is the right tool — Kubernetes would be overkill and add weeks of work. The architecture I chose maps cleanly to ECS or k8s when the app outgrows a single host: Caddy becomes an ALB or Ingress, each compose service becomes a task definition or Deployment, the named volumes become EFS or RDS."

### "Why not OIDC instead of long-lived AWS keys?"

> "I know about it — that's what I'd do for a real project. GitHub publishes an OIDC token to AWS, AWS verifies the claims, hands back a short-lived role assumption. No keys to rotate. I went with access keys here because the goal was to learn the IAM/ECR/CI loop end-to-end first. Switching to OIDC is a small change to the workflow file."

### "What does your healthcheck actually check?"

> "The `/health` endpoint runs `SELECT 1` against Postgres. So a 200 means both 'the app is up' and 'the database is reachable'. That's the shape Kubernetes liveness probes and load balancers expect — they don't care about your business logic, they just want to know if the instance should keep getting traffic."

### "How is the database backed up?"

> "Right now it isn't, which is fine for a portfolio project. In production I'd either run `pg_dump | aws s3 cp` on a cron, or stop running Postgres in a container and use RDS instead — RDS has automated daily snapshots and point-in-time recovery built in."

### "What's the bottleneck if traffic spikes?"

> "The single backend container. It's a synchronous Python process. The fix at small scale is to run multiple replicas behind Caddy — Compose lets you scale a service with `docker compose up --scale backend=3` and Caddy can load-balance between them. At larger scale you move to ECS/k8s with auto-scaling. The database becomes the next bottleneck — at that point I'd switch to RDS with read replicas."

### "Why FastAPI over Flask or Django?"

> "FastAPI gives me type-safe request validation via Pydantic, automatic OpenAPI docs at `/docs`, and async support — all built in. Flask is more bare-bones; you'd add Marshmallow, flask-restx, etc. and end up with the same thing more painfully. Django is great when you need its admin and ORM ecosystem but it's heavy for a small REST API."

### "Walk me through what `docker compose up` actually does."

> "Compose reads the YAML, figures out what services exist and what they depend on, and brings them up in dependency order. For each service: if there's a `build:`, it builds the image; if there's an `image:` and the image isn't local, it pulls it. It creates a default network so containers can resolve each other by service name. It creates volumes that don't exist yet. Then it starts containers in the right order, respecting `depends_on` and healthchecks. With `-d` it detaches; without, it tails the logs."

### "What's the difference between `EXPOSE` and `ports:` in compose?"

> "`EXPOSE` in a Dockerfile is documentation — it tells humans which ports the container listens on, but it doesn't actually publish them anywhere. `ports:` in compose maps a container port to a host port — that's what makes it reachable from outside the Docker network. In my prod compose, only Caddy has `ports:`. Backend and frontend have `expose:` (compose's metadata version of EXPOSE) so they're internal-only."
