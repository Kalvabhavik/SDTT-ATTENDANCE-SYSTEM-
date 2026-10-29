@echo off
setlocal enabledelayedexpansion
title Attendrix Enterprise Full-Stack Runner

echo =================================================================
echo    ATTENDRIX ENTERPRISE - CAMPUS ATTENDANCE PLATFORM
echo    Launching Backend API & Classroom Dashboard...
echo =================================================================
echo.

cd /d "%~dp0"

echo [1/3] Setting up environment...
set PYTHONPATH=%~dp0backend;%PYTHONPATH%

if not exist "backend\.env" (
    if exist "backend\.env.example" (
        echo Creating backend\.env from template...
        copy "backend\.env.example" "backend\.env" >nul
    )
)

if not exist "apps\dashboard\node_modules" (
    echo Installing dashboard dependencies...
    call npm --prefix apps/dashboard install
)

echo [2/3] Starting FastAPI Backend on http://127.0.0.1:8000...
start "Attendrix Backend API (FastAPI)" cmd /c "python -m uvicorn app.main:app --app-dir backend --host 127.0.0.1 --port 8000 --reload"

timeout /t 2 /nobreak >nul

echo [3/3] Starting Classroom Dashboard on http://localhost:5173...
start "Attendrix Classroom Dashboard (Vite)" cmd /c "npm --prefix apps/dashboard run dev -- --host 127.0.0.1 --port 5173"

echo.
echo =================================================================
echo    ATTENDRIX STACK RUNNING!
echo =================================================================
echo    Dashboard UI:    http://localhost:5173
echo    Backend API:     http://127.0.0.1:8000
echo    API Docs:        http://127.0.0.1:8000/docs
echo =================================================================
echo.
pause
