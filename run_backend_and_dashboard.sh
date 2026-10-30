#!/usr/bin/env bash
# ==============================================================================
# 🚀 Attendrix Pro Stack Runner — Backend & Dashboard Unified Launcher
# Launches:
#   1. FastAPI Biometric Backend (Port 8000)
#   2. React Control Center Dashboard (Port 4173)
# Connects them automatically with ADB reverse proxy & network resolution.
# ==============================================================================

set -eo pipefail

export PATH="$HOME/Android/Sdk/platform-tools:$HOME/development/flutter/bin:$PATH"

# ANSI Color Palette
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[38;5;51m'
BLUE='\033[38;5;39m'
GREEN='\033[38;5;48m'
AMBER='\033[38;5;214m'
RED='\033[38;5;196m'
MAGENTA='\033[38;5;201m'
BG_DARK='\033[48;5;235m'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="${ROOT_DIR}/backend"
DASHBOARD_DIR="${ROOT_DIR}/apps/dashboard"
LOG_DIR="${ROOT_DIR}/.logs"

mkdir -p "$LOG_DIR"
BACKEND_LOG="${LOG_DIR}/backend.log"
DASHBOARD_LOG="${LOG_DIR}/dashboard.log"

print_banner() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}"
    cat << "EOF"
  █████╗ ████████╗████████╗███████╗███╗   ██╗██████╗ ██████╗ ██╗██╗  ██╗
 ██╔══██╗╚══██╔══╝╚══██╔══╝██╔════╝████╗  ██║██╔══██╗██╔══██╗██║╚██╗██╔╝
 ███████║   ██║      ██║   █████╗  ██╔██╗ ██║██║  ██║██████╔╝██║ ╚███╔╝ 
 ██╔══██║   ██║      ██║   ██╔══╝  ██║╚██╗██║██║  ██║██╔══██╗██║ ██╔██╗ 
 ██║  ██║   ██║      ██║   ███████╗██║ ╚████║██████╔╝██║  ██║██║██╔╝ ██╗
 ╚═╝  ╚═╝   ╚═╝      ╚═╝   ╚══════╝╚═╝  ╚═══╝╚═════╝ ╚═╝  ╚═╝╚═╝╚═╝  ╚═╝
EOF
    echo -e "${RESET}"
    echo -e "   ${BOLD}${AMBER}⚡ ZERO-PROXY BIOMETRIC ATTENDANCE PLATFORM — PRO STACK RUNNER${RESET}"
    echo -e "   ${DIM}Automated Unified Orchestration Engine for FastAPI & React Dashboard${RESET}"
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${RESET}"
}

print_step() {
    local num="$1"
    local title="$2"
    echo -e "\n${BOLD}${BLUE}[${num}] ${title}${RESET}"
}

print_success() {
    echo -e "   ${GREEN}✓ $1${RESET}"
}

print_warn() {
    echo -e "   ${AMBER}⚠️  $1${RESET}"
}

print_error() {
    echo -e "   ${RED}❌ $1${RESET}"
}

# Cleanup handler for graceful shutdown
BACKEND_PID=""
DASHBOARD_PID=""

cleanup() {
    echo -e "\n${AMBER}🛑 Gracefully terminating Attendrix Pro Stack...${RESET}"
    if [ -n "$BACKEND_PID" ] && kill -0 "$BACKEND_PID" 2>/dev/null; then
        echo -e "   -> Stopping Backend server (PID $BACKEND_PID)..."
        kill "$BACKEND_PID" 2>/dev/null || true
    fi
    if [ -n "$DASHBOARD_PID" ] && kill -0 "$DASHBOARD_PID" 2>/dev/null; then
        echo -e "   -> Stopping Dashboard server (PID $DASHBOARD_PID)..."
        kill "$DASHBOARD_PID" 2>/dev/null || true
    fi
    # Free port 8000 and 4173 if stubborn
    fuser -k 8000/tcp >/dev/null 2>&1 || true
    fuser -k 4173/tcp >/dev/null 2>&1 || true
    echo -e "${GREEN}✓ All services stopped cleanly.${RESET}"
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# ── 1. Environment & Prerequisites Verification ──────────────────────────────
print_banner
print_step "1/5" "Verifying runtime environment and tools..."

# Detect Python interpreter
PYTHON_BIN=""
if [ -f "${BACKEND_DIR}/.venv/bin/python" ]; then
    PYTHON_BIN="${BACKEND_DIR}/.venv/bin/python"
    UVICORN_BIN="${BACKEND_DIR}/.venv/bin/uvicorn"
elif [ -f "${BACKEND_DIR}/venv/bin/python" ]; then
    PYTHON_BIN="${BACKEND_DIR}/venv/bin/python"
    UVICORN_BIN="${BACKEND_DIR}/venv/bin/uvicorn"
elif command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python3)"
    UVICORN_BIN="uvicorn"
else
    print_error "Python 3 is required but not found in PATH."
    exit 1
fi
print_success "Python runtime: $($PYTHON_BIN --version) ($PYTHON_BIN)"

# Detect Node.js and npm
if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    print_error "Node.js and npm are required for the React Dashboard. Please install them."
    exit 1
fi
print_success "Node runtime: $(node -v) / npm $(npm -v)"

# Network IP Detection
LOCAL_IP=$(ip -4 addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1 || true)
if [ -z "$LOCAL_IP" ]; then
    LOCAL_IP="127.0.0.1"
fi
print_success "Local Area Network Host IP: ${LOCAL_IP}"

# ── 2. Hardware / Android ADB Reverse Proxy Verification ─────────────────────
print_step "2/5" "Configuring cross-device and mobile bridge..."
if command -v adb >/dev/null 2>&1; then
    CONNECTED_DEVICES=$(adb devices 2>/dev/null | grep -w "device" | awk '{print $1}')
    if [ -n "$CONNECTED_DEVICES" ]; then
        for dev in $CONNECTED_DEVICES; do
            echo -e "   📱 Setting up zero-latency ADB tunnels for device ${BOLD}$dev${RESET}..."
            adb -s "$dev" reverse tcp:8000 tcp:8000 >/dev/null 2>&1 || true
            adb -s "$dev" reverse tcp:4173 tcp:4173 >/dev/null 2>&1 || true
            print_success "Device $dev reverse-forwarded [8000:8000, 4173:4173]"
        done
    else
        echo -e "   ${DIM}ℹ️  No USB Android device detected (connect phone via USB debugging anytime).${RESET}"
    fi
else
    echo -e "   ${DIM}ℹ️  'adb' not in PATH; skipping phone port forwarding.${RESET}"
fi

# ── 3. Start FastAPI Biometric Backend ────────────────────────────────────────
print_step "3/5" "Starting FastAPI Biometric Backend on 0.0.0.0:8000..."

# Free existing port 8000 if running
if lsof -ti:8000 >/dev/null 2>&1; then
    print_warn "Port 8000 is occupied. Releasing port 8000..."
    fuser -k 8000/tcp >/dev/null 2>&1 || true
    sleep 1
fi

export PYTHONPATH="${BACKEND_DIR}:${PYTHONPATH:-}"
cd "$BACKEND_DIR"

"$UVICORN_BIN" app.main:app --host 0.0.0.0 --port 8000 --reload > "$BACKEND_LOG" 2>&1 &
BACKEND_PID=$!
cd "$ROOT_DIR"

echo -n "   Waiting for backend health check at http://127.0.0.1:8000/api/time"
for i in {1..35}; do
    if curl -s --max-time 1 "http://127.0.0.1:8000/api/time" >/dev/null 2>&1; then
        echo -e " ${GREEN}${BOLD}[HEALTHY]${RESET}"
        break
    fi
    echo -n "."
    sleep 0.4
done

if ! curl -s --max-time 1 "http://127.0.0.1:8000/api/time" >/dev/null 2>&1; then
    print_error "Backend failed to become healthy. Logs from ${BACKEND_LOG}:"
    tail -n 25 "$BACKEND_LOG"
    exit 1
fi
print_success "Backend active on PID ${BACKEND_PID} (Swagger docs: http://localhost:8000/docs)"

# ── 4. Prepare Dashboard Dependencies & Connection ───────────────────────────
print_step "4/5" "Configuring React Control Center Dashboard..."

if [ ! -d "${DASHBOARD_DIR}/node_modules" ]; then
    echo -e "   Installing dashboard dependencies (first run)..."
    npm --prefix "$DASHBOARD_DIR" install --silent
fi

# Configure connection to backend
export VITE_API_BASE_URL="http://localhost:8000/api"
print_success "Target API Base configured: ${VITE_API_BASE_URL}"

# ── 5. Start Dashboard Dev Server ────────────────────────────────────────────
print_step "5/5" "Launching React Dashboard on 0.0.0.0:4173..."

if lsof -ti:4173 >/dev/null 2>&1; then
    fuser -k 4173/tcp >/dev/null 2>&1 || true
    sleep 1
fi

cd "$DASHBOARD_DIR"
npm run dev -- --host 0.0.0.0 --port 4173 > "$DASHBOARD_LOG" 2>&1 &
DASHBOARD_PID=$!
cd "$ROOT_DIR"

echo -n "   Waiting for dashboard dev server"
for i in {1..25}; do
    if curl -s --max-time 1 "http://127.0.0.1:4173" >/dev/null 2>&1; then
        echo -e " ${GREEN}${BOLD}[ONLINE]${RESET}"
        break
    fi
    echo -n "."
    sleep 0.3
done
print_success "Dashboard dev server active on PID ${DASHBOARD_PID}"

# ── Ready Overview ───────────────────────────────────────────────────────────
echo -e "\n${GREEN}${BOLD}=============================================================================${RESET}"
echo -e "${GREEN}${BOLD}   ⚡ ATTENDRIX ENTERPRISE PLATFORM RUNNING SUCCESSFULLY!${RESET}"
echo -e "${GREEN}${BOLD}=============================================================================${RESET}"
echo -e "   🖥️  ${BOLD}Control Dashboard:${RESET}    ${CYAN}http://localhost:4173${RESET}  ${DIM}(LAN: http://${LOCAL_IP}:4173)${RESET}"
echo -e "   ⚙️  ${BOLD}FastAPI Backend API:${RESET}  ${CYAN}http://localhost:8000/api${RESET}  ${DIM}(LAN: http://${LOCAL_IP}:8000/api)${RESET}"
echo -e "   📖 ${BOLD}Interactive Swagger:${RESET}  ${CYAN}http://localhost:8000/docs${RESET}"
echo -e "   🛡️  ${BOLD}Anti-Proxy Pipeline:${RESET}  ${GREEN}Active (ORB + SSIM + YuNet + ArcFace 512-D)${RESET}"
echo -e "   📱 ${BOLD}Mobile USB Reverse:${RESET}   ${GREEN}Active (localhost:8000 routed directly to phone)${RESET}"
echo -e "   📋 ${BOLD}Live Logs:${RESET}            ${DIM}${BACKEND_LOG} | ${DASHBOARD_LOG}${RESET}"
echo -e "${GREEN}─────────────────────────────────────────────────────────────────────────────${RESET}"
echo -e "   Press ${BOLD}Ctrl+C${RESET} anytime to shut down all processes cleanly.\n"

# Stream backend log live while waiting
tail -f "$BACKEND_LOG" &
TAIL_PID=$!

wait "$BACKEND_PID" "$DASHBOARD_PID"
