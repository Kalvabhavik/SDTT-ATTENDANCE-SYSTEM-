#!/usr/bin/env bash
# ==============================================================================
# Attendrix Enterprise — Complete Full-Stack Runner
# Starts both FastAPI Backend (port 8000) and React Dashboard (port 5173)
# ==============================================================================

set -e

# ANSI Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

echo -e "${CYAN}${BOLD}"
echo "================================================================="
echo "   ATTENDRIX ENTERPRISE — CAMPUS ATTENDANCE PLATFORM"
echo "   Launching Backend API & Classroom Dashboard..."
echo "================================================================="
echo -e "${NC}"

# Find script directory (repo root)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

# 1. Check Python
echo -e "${YELLOW}[1/4] Checking Python environment...${NC}"
if command -v python3 &>/dev/null; then
    PYTHON_CMD="python3"
elif command -v python &>/dev/null; then
    PYTHON_CMD="python"
elif command -v py &>/dev/null; then
    PYTHON_CMD="py"
else
    echo -e "${RED}Error: Python is not installed or not in PATH.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Found: $($PYTHON_CMD --version)${NC}"

# 2. Check Node & npm
echo -e "${YELLOW}[2/4] Checking Node.js & npm...${NC}"
if ! command -v node &>/dev/null || ! command -v npm &>/dev/null; then
    echo -e "${RED}Error: Node.js or npm is not installed or not in PATH.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Found: Node $(node -v) / npm $(npm -v)${NC}"

# 3. Setup Backend Environment
echo -e "${YELLOW}[3/4] Preparing Backend...${NC}"
if [ ! -f "backend/.env" ] && [ -f "backend/.env.example" ]; then
    echo "Creating backend/.env from .env.example..."
    cp "backend/.env.example" "backend/.env"
fi

# Ensure frontend dependencies
if [ ! -d "apps/dashboard/node_modules" ]; then
    echo -e "${YELLOW}Installing dashboard dependencies...${NC}"
    npm --prefix apps/dashboard install
fi

# Set PYTHONPATH so app module resolves cleanly
export PYTHONPATH="${ROOT_DIR}/backend:${PYTHONPATH:-}"

# Trap to kill both processes on Ctrl+C or script exit
cleanup() {
    echo -e "\n${YELLOW}Shutting down Attendrix servers...${NC}"
    if [ -n "${BACKEND_PID:-}" ] && kill -0 "$BACKEND_PID" 2>/dev/null; then
        kill "$BACKEND_PID" 2>/dev/null || true
    fi
    if [ -n "${FRONTEND_PID:-}" ] && kill -0 "$FRONTEND_PID" 2>/dev/null; then
        kill "$FRONTEND_PID" 2>/dev/null || true
    fi
    echo -e "${GREEN}All servers stopped.${NC}"
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# 4. Start Backend
echo -e "${YELLOW}[4/4] Starting FastAPI backend on http://127.0.0.1:8000...${NC}"
$PYTHON_CMD -m uvicorn app.main:app --app-dir "${ROOT_DIR}/backend" --host 127.0.0.1 --port 8000 --reload &
BACKEND_PID=$!

# Wait briefly for backend to initialize
sleep 2

# Start Frontend
echo -e "${YELLOW}Starting React Dashboard on http://localhost:5173...${NC}"
npm --prefix apps/dashboard run dev -- --host 127.0.0.1 --port 5173 &
FRONTEND_PID=$!

echo -e "\n${GREEN}${BOLD}=================================================================${NC}"
echo -e "${GREEN}${BOLD}   ✓ ATTENDRIX STACK RUNNING SUCCESSFULLY!${NC}"
echo -e "${GREEN}${BOLD}=================================================================${NC}"
echo -e "   🖥️  ${BOLD}Dashboard UI:${NC}    ${CYAN}http://localhost:5173${NC}"
echo -e "   ⚙️  ${BOLD}Backend API:${NC}     ${CYAN}http://127.0.0.1:8000${NC}"
echo -e "   📖 ${BOLD}API Swagger Docs:${NC} ${CYAN}http://127.0.0.1:8000/docs${NC}"
echo -e "   Press ${BOLD}Ctrl+C${NC} anytime to stop both services gracefully."
echo -e "${GREEN}${BOLD}=================================================================${NC}\n"

# Wait for both processes
wait $BACKEND_PID $FRONTEND_PID
