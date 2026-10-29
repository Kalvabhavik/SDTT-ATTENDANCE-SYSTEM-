# ==============================================================================
# Attendrix Enterprise — Complete Full-Stack Runner (PowerShell)
# Starts both FastAPI Backend (port 8000) and React Dashboard (port 5173)
# ==============================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "Attendrix Full-Stack Runner"

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "   ATTENDRIX ENTERPRISE — CAMPUS ATTENDANCE PLATFORM" -ForegroundColor Cyan
Write-Host "   Launching Backend API & Classroom Dashboard..." -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RootDir

# 1. Check Python
Write-Host "`n[1/4] Checking Python environment..." -ForegroundColor Yellow
$PythonCmd = if (Get-Command "python" -ErrorAction SilentlyContinue) { "python" }
             elseif (Get-Command "py" -ErrorAction SilentlyContinue) { "py" }
             else { $null }

if (-not $PythonCmd) {
    Write-Host "Error: Python is not installed or not in PATH." -ForegroundColor Red
    Exit 1
}
$PyVer = & $PythonCmd --version 2>&1
Write-Host "✓ Found: $PyVer" -ForegroundColor Green

# 2. Check Node & npm
Write-Host "`n[2/4] Checking Node.js & npm..." -ForegroundColor Yellow
if (-not (Get-Command "node" -ErrorAction SilentlyContinue) -or -not (Get-Command "npm" -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Node.js or npm is not installed or not in PATH." -ForegroundColor Red
    Exit 1
}
$NodeVer = node -v
$NpmVer = npm -v
Write-Host "✓ Found: Node $NodeVer / npm $NpmVer" -ForegroundColor Green

# 3. Environment & Dependencies Setup
Write-Host "`n[3/4] Preparing Backend & Dependencies..." -ForegroundColor Yellow
if (-not (Test-Path "backend/.env") -and (Test-Path "backend/.env.example")) {
    Write-Host "Creating backend/.env from .env.example..." -ForegroundColor Gray
    Copy-Item "backend/.env.example" "backend/.env"
}

if (-not (Test-Path "apps/dashboard/node_modules")) {
    Write-Host "Installing dashboard npm dependencies..." -ForegroundColor Yellow
    npm --prefix apps/dashboard install
}

$env:PYTHONPATH = "$RootDir\backend;$env:PYTHONPATH"

# Function to kill child processes on exit
$backendProcess = $null
$frontendProcess = $null

function Cleanup {
    Write-Host "`n`nShutting down Attendrix servers..." -ForegroundColor Yellow
    if ($backendProcess -and -not $backendProcess.HasExited) {
        Stop-Process -Id $backendProcess.Id -Force -ErrorAction SilentlyContinue
    }
    if ($frontendProcess -and -not $frontendProcess.HasExited) {
        Stop-Process -Id $frontendProcess.Id -Force -ErrorAction SilentlyContinue
    }
    # Also clean up any lingering uvicorn or vite on ports 8000 / 5173
    Get-Process -Name "node", "python" -ErrorAction SilentlyContinue | Where-Object {
        $id = $_.Id
        Get-NetTCPConnection -OwningProcess $id -LocalPort 8000, 5173 -ErrorAction SilentlyContinue
    } | Stop-Process -Force -ErrorAction SilentlyContinue

    Write-Host "All Attendrix servers stopped cleanly." -ForegroundColor Green
}

# Register Ctrl+C handler
[Console]::TreatControlCAsInput = $false

# 4. Start Backend
Write-Host "`n[4/4] Starting FastAPI backend on http://127.0.0.1:8000..." -ForegroundColor Yellow
$backendProcess = Start-Process -FilePath $PythonCmd `
    -ArgumentList "-m uvicorn app.main:app --app-dir `"$RootDir\backend`" --host 127.0.0.1 --port 8000 --reload" `
    -WorkingDirectory $RootDir `
    -PassThru

Start-Sleep -Seconds 2

# Start Frontend
Write-Host "Starting React Dashboard on http://localhost:5173..." -ForegroundColor Yellow
$frontendProcess = Start-Process -FilePath "npm" `
    -ArgumentList "--prefix apps/dashboard run dev -- --host 127.0.0.1 --port 5173" `
    -WorkingDirectory $RootDir `
    -PassThru

Write-Host "`n=================================================================" -ForegroundColor Green
Write-Host "   ✓ ATTENDRIX STACK RUNNING SUCCESSFULLY!" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Green
Write-Host "   🖥️  Dashboard UI:    http://localhost:5173" -ForegroundColor Cyan
Write-Host "   ⚙️  Backend API:     http://127.0.0.1:8000" -ForegroundColor Cyan
Write-Host "   📖 API Swagger Docs: http://127.0.0.1:8000/docs" -ForegroundColor Cyan
Write-Host "   Press Ctrl+C anytime to stop both services gracefully." -ForegroundColor Gray
Write-Host "=================================================================`n" -ForegroundColor Green

try {
    while (-not $backendProcess.HasExited -and -not $frontendProcess.HasExited) {
        Start-Sleep -Seconds 1
    }
}
finally {
    Cleanup
}
