#!/usr/bin/env bash
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "========================================"
echo " Starting FastAPI + React + Postgres app"
echo "========================================"

command -v python3 >/dev/null 2>&1 || { echo "[ERROR] python3 not found"; exit 1; }
command -v node    >/dev/null 2>&1 || { echo "[ERROR] node not found";    exit 1; }

# Backend
if [ ! -d "$ROOT/backend/.venv" ]; then
  echo "[1/4] Creating backend venv + installing requirements..."
  python3 -m venv "$ROOT/backend/.venv"
  "$ROOT/backend/.venv/bin/pip" install --upgrade pip
  "$ROOT/backend/.venv/bin/pip" install -r "$ROOT/backend/requirements.txt"
fi

# Frontend
if [ ! -d "$ROOT/frontend/node_modules" ]; then
  echo "[2/4] Installing frontend dependencies..."
  (cd "$ROOT/frontend" && npm install)
fi

echo "[3/4] Starting FastAPI..."
(cd "$ROOT/backend" && .venv/bin/uvicorn app.main:app --reload --host 0.0.0.0 --port 8000) &
BACKEND_PID=$!

echo "[4/4] Starting React..."
(cd "$ROOT/frontend" && npm start) &
FRONTEND_PID=$!

sleep 8
case "$(uname -s)" in
  Darwin)               open "http://localhost:3000"; open "http://localhost:8000/docs" ;;
  Linux)                xdg-open "http://localhost:3000" >/dev/null 2>&1 || true ;;
  MINGW*|MSYS*|CYGWIN*) start "" "http://localhost:3000"; start "" "http://localhost:8000/docs" ;;
esac

echo
echo " Frontend : http://localhost:3000"
echo " API docs : http://localhost:8000/docs"
echo " Postgres expected at localhost:5432 (db itemsdb, user/pass postgres)"
echo " Press Ctrl+C to stop both processes."

trap "kill $BACKEND_PID $FRONTEND_PID 2>/dev/null" EXIT
wait
