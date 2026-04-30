@echo off
setlocal enabledelayedexpansion

echo ========================================
echo  Starting FastAPI + React + Postgres app
echo ========================================

REM ---- prerequisite checks ----
where python >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Python is not installed or not in PATH.
    pause
    exit /b 1
)

where node >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Node.js is not installed or not in PATH.
    pause
    exit /b 1
)

set ROOT=%~dp0

REM ---- backend setup ----
echo.
echo [1/4] Setting up backend virtualenv...
if not exist "%ROOT%backend\.venv\Scripts\python.exe" (
    pushd "%ROOT%backend"
    python -m venv .venv
    call .venv\Scripts\activate.bat
    pip install --upgrade pip
    pip install -r requirements.txt
    popd
) else (
    echo Backend venv already exists, skipping install.
)

REM ---- frontend setup ----
echo.
echo [2/4] Installing frontend dependencies...
if not exist "%ROOT%frontend\node_modules" (
    pushd "%ROOT%frontend"
    call npm install
    popd
) else (
    echo Frontend node_modules already exists, skipping install.
)

REM ---- start backend ----
echo.
echo [3/4] Starting FastAPI backend on http://localhost:8000 ...
start "FastAPI Backend" cmd /k "cd /d %ROOT%backend && call .venv\Scripts\activate.bat && uvicorn app.main:app --reload --host 0.0.0.0 --port 8000"

REM ---- start frontend ----
echo.
echo [4/4] Starting React frontend on http://localhost:3000 ...
start "React Frontend" cmd /k "cd /d %ROOT%frontend && npm start"

REM ---- wait and open browser ----
timeout /t 8 /nobreak >nul
start "" "http://localhost:3000"
start "" "http://localhost:8000/docs"

echo.
echo ========================================
echo  App is running:
echo    Frontend : http://localhost:3000
echo    API docs : http://localhost:8000/docs
echo.
echo  Make sure Postgres is running at localhost:5432
echo  with database 'itemsdb' (user/pass: postgres/postgres)
echo  or update backend\.env DATABASE_URL.
echo.
echo  Close the two opened terminal windows to stop.
echo ========================================
echo.
pause
