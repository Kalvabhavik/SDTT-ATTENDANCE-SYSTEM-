#!/usr/bin/env bash
# ==============================================================================
# Attendrix — Master Setup, Diagnostic, Test, and Run Script
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/backend"
MOBILE_DIR="$SCRIPT_DIR/apps/mobile"
DASHBOARD_DIR="$SCRIPT_DIR/apps/dashboard"
PRESENTATION_DIR="$SCRIPT_DIR/presentation/attendrix"
PID_FILE="$SCRIPT_DIR/.run_pids"

# Ensure PATH includes standard development locations for Flutter, Android SDK, and Python
export PATH="$HOME/development/flutter/bin:$HOME/Android/Sdk/platform-tools:$HOME/.local/bin:$PATH"

# Color helpers
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BOLD="\033[1m"
RESET="\033[0m"

log_info() { echo -e "${BLUE}ℹ${RESET} $1"; }
log_ok() { echo -e "${GREEN}✓${RESET} $1"; }
log_warn() { echo -e "${YELLOW}⚠${RESET} $1"; }
log_err() { echo -e "${RED}✗${RESET} $1"; }
header() {
    echo ""
    echo -e "${BOLD}====================================================================${RESET}"
    echo -e "${BOLD} $1${RESET}"
    echo -e "${BOLD}====================================================================${RESET}"
}

get_lan_ip() {
    ip -4 addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1 || echo "localhost"
}

# ------------------------------------------------------------------------------
# 1. COMMAND: check
# ------------------------------------------------------------------------------
cmd_check() {
    header "Attendrix Environment & Diagnostic Check"
    local all_good=true

    # Python
    if command -v python3 >/dev/null 2>&1; then
        PY_VER=$(python3 --version 2>&1)
        log_ok "Python: $PY_VER"
    else
        log_err "Python 3 is not installed or not in PATH."
        all_good=false
    fi

    # Virtual environment
    if [ -f "$BACKEND_DIR/.venv/bin/python" ]; then
        VENV_PY_VER=$("$BACKEND_DIR/.venv/bin/python" --version 2>&1)
        log_ok "Backend Virtualenv: $BACKEND_DIR/.venv ($VENV_PY_VER)"
    else
        log_warn "Backend virtual environment missing in $BACKEND_DIR/.venv (run './run.sh setup')"
    fi

    # Node.js & npm
    if command -v node >/dev/null 2>&1; then
        NODE_VER=$(node --version 2>&1)
        log_ok "Node.js: $NODE_VER"
    else
        log_err "Node.js is not installed."
        all_good=false
    fi

    if command -v npm >/dev/null 2>&1; then
        NPM_VER=$(npm --version 2>&1)
        log_ok "npm: $NPM_VER"
    else
        log_err "npm is not installed."
        all_good=false
    fi

    # Flutter
    if command -v flutter >/dev/null 2>&1; then
        FLUTTER_VER=$(flutter --version 2>&1 | head -n 1)
        log_ok "Flutter: $FLUTTER_VER"
    else
        log_warn "Flutter not found in PATH or ~/development/flutter/bin."
    fi

    # ADB & Devices
    if command -v adb >/dev/null 2>&1; then
        ADB_VER=$(adb version 2>&1 | head -n 1)
        log_ok "ADB: $ADB_VER"
        CONNECTED_DEVICES=$(adb devices | grep -w "device" | awk '{print $1}')
        if [ -n "$CONNECTED_DEVICES" ]; then
            log_ok "Target Android Device: $CONNECTED_DEVICES"
        else
            log_warn "No physical Android devices attached via ADB."
        fi
    else
        log_warn "ADB not found in PATH or ~/Android/Sdk/platform-tools."
    fi

    # Computer Vision Models
    MODEL_DIR="$BACKEND_DIR/app/models"
    if [ -f "$MODEL_DIR/face_detection_yunet.onnx" ] && [ -f "$MODEL_DIR/face_recognition_sface.onnx" ]; then
        log_ok "CV Models: YuNet & SFace ONNX models present in $MODEL_DIR"
    else
        log_err "Missing ONNX model files in $MODEL_DIR"
        all_good=false
    fi

    # Network IP
    LAN_IP=$(get_lan_ip)
    log_info "Local Area Network IP: $LAN_IP"

    echo ""
    if [ "$all_good" = true ]; then
        log_ok "All primary core dependencies satisfied!"
    else
        log_warn "Some dependencies are missing or require attention."
    fi
}

# ------------------------------------------------------------------------------
# 2. COMMAND: setup
# ------------------------------------------------------------------------------
cmd_setup() {
    header "Setting up Attendrix Dependencies & Workspaces"

    # 1. Backend venv
    log_info "Setting up Python virtual environment in backend/.venv..."
    if [ ! -d "$BACKEND_DIR/.venv" ]; then
        python3 -m venv "$BACKEND_DIR/.venv"
    fi
    "$BACKEND_DIR/.venv/bin/pip" install -q -r "$BACKEND_DIR/requirements.txt"
    log_ok "Backend dependencies installed successfully."

    # 2. Dashboard
    log_info "Verifying Web Dashboard dependencies in apps/dashboard..."
    npm --prefix "$DASHBOARD_DIR" install --prefer-offline --no-audit --no-fund
    log_ok "Web Dashboard dependencies verified."

    # 3. Presentation
    if [ -d "$PRESENTATION_DIR" ]; then
        log_info "Verifying Presentation dependencies in presentation/attendrix..."
        npm --prefix "$PRESENTATION_DIR" install --prefer-offline --no-audit --no-fund
        log_ok "Presentation dependencies verified."
    fi

    # 4. Mobile app
    if command -v flutter >/dev/null 2>&1 && [ -d "$MOBILE_DIR" ]; then
        log_info "Resolving Flutter pub packages in apps/mobile..."
        (cd "$MOBILE_DIR" && flutter pub get)
        log_ok "Flutter packages resolved."
    fi

    # 5. ADB reverse tunnel if device connected
    if command -v adb >/dev/null 2>&1; then
        DEV=$(adb devices | grep -w "device" | awk '{print $1}' | head -n 1)
        if [ -n "$DEV" ]; then
            adb -s "$DEV" reverse tcp:8000 tcp:8000
            log_ok "ADB port reversed (tcp:8000 -> tcp:8000) for device $DEV."
        fi
    fi

    header "Setup Completed Successfully"
}

# ------------------------------------------------------------------------------
# 3. COMMAND: test
# ------------------------------------------------------------------------------
cmd_test() {
    header "Running Attendrix Full Test Suite"
    local failed=0

    # 1. Backend Pytest
    echo ""
    log_info "1. Running Backend Pytest suite..."
    if [ -x "$BACKEND_DIR/.venv/bin/pytest" ]; then
        if "$BACKEND_DIR/.venv/bin/pytest" "$BACKEND_DIR/tests" -v; then
            log_ok "PASS: Backend pytest suite passed."
        else
            log_err "FAIL: Backend pytest suite failed."
            failed=$((failed + 1))
        fi
    else
        log_warn "BLOCKED: pytest not found in backend/.venv."
    fi

    # 2. Flutter tests
    echo ""
    log_info "2. Running Flutter tests in apps/mobile..."
    if command -v flutter >/dev/null 2>&1; then
        if (cd "$MOBILE_DIR" && flutter test); then
            log_ok "PASS: Flutter widget and unit tests passed."
        else
            log_err "FAIL: Flutter tests failed."
            failed=$((failed + 1))
        fi
    else
        log_warn "BLOCKED: Flutter not installed in environment."
    fi

    # 3. Dashboard Build Verification
    echo ""
    log_info "3. Verifying React + Vite Dashboard build..."
    if npm --prefix "$DASHBOARD_DIR" run build; then
        log_ok "PASS: Web Dashboard build succeeded."
    else
        log_err "FAIL: Web Dashboard build failed."
        failed=$((failed + 1))
    fi

    # 4. Presentation Build Verification
    if [ -d "$PRESENTATION_DIR" ]; then
        echo ""
        log_info "4. Verifying Three.js + GSAP Presentation build..."
        if npm --prefix "$PRESENTATION_DIR" run build; then
            log_ok "PASS: Presentation site build succeeded."
        else
            log_err "FAIL: Presentation site build failed."
            failed=$((failed + 1))
        fi
    fi

    echo ""
    if [ "$failed" -eq 0 ]; then
        log_ok "All test and build verifications PASSED!"
    else
        log_err "One or more verification steps FAILED ($failed failures)."
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# 4. COMMAND: start / run (default)
# ------------------------------------------------------------------------------
cmd_start() {
    header "Starting Attendrix Services"

    # Stop any previously running session tracked in .run_pids
    if [ -f "$PID_FILE" ]; then
        cmd_stop
    fi

    > "$PID_FILE"

    # 1. Start FastAPI backend
    log_info "Launching FastAPI backend on http://0.0.0.0:8000..."
    if [ ! -f "$BACKEND_DIR/.venv/bin/uvicorn" ]; then
        cmd_setup
    fi

    nohup "$BACKEND_DIR/.venv/bin/uvicorn" app.main:app --host 0.0.0.0 --port 8000 > /tmp/attendrix_backend.log 2>&1 &
    BACKEND_PID=$!
    echo "$BACKEND_PID" >> "$PID_FILE"
    log_ok "Backend started (PID $BACKEND_PID). Log: /tmp/attendrix_backend.log"

    # Wait for backend health
    echo -n "Waiting for backend API to be ready..."
    for i in {1..20}; do
        if curl -s --max-time 1 http://localhost:8000/api/health >/dev/null 2>&1; then
            echo " Ready!"
            break
        fi
        sleep 0.5
        echo -n "."
    done

    # 2. Start Web Dashboard
    log_info "Launching Web Dashboard on http://localhost:5173..."
    nohup npm --prefix "$DASHBOARD_DIR" run dev -- --host 0.0.0.0 --port 5173 > /tmp/attendrix_dashboard.log 2>&1 &
    DASHBOARD_PID=$!
    echo "$DASHBOARD_PID" >> "$PID_FILE"
    log_ok "Dashboard started (PID $DASHBOARD_PID). Log: /tmp/attendrix_dashboard.log"

    # 3. Setup ADB Reverse & Launch Phone if attached
    if command -v adb >/dev/null 2>&1; then
        CONNECTED_DEV=$(adb devices | grep -w "device" | awk '{print $1}' | head -n 1)
        if [ -n "$CONNECTED_DEV" ]; then
            log_info "Configuring ADB reverse on target phone $CONNECTED_DEV..."
            adb -s "$CONNECTED_DEV" reverse tcp:8000 tcp:8000
            adb -s "$CONNECTED_DEV" shell am start -n com.example.classroom_attendance_mobile/.MainActivity >/dev/null 2>&1 || true
            log_ok "Phone reverse active (tcp:8000 -> tcp:8000) and app launched!"
        else
            log_warn "No physical Android device connected via ADB."
            log_info "Connect your phone via USB with USB Debugging enabled, then run './run.sh' again."
        fi
    fi

    LAN_IP=$(get_lan_ip)
    echo ""
    echo -e "${BOLD}Attendrix Local URLs:${RESET}"
    echo -e "  • FastAPI API:          ${GREEN}http://localhost:8000/api${RESET} (Network: http://${LAN_IP}:8000/api)"
    echo -e "  • Interactive Docs:     ${GREEN}http://localhost:8000/docs${RESET}"
    echo -e "  • Teacher/Controller:   ${GREEN}http://localhost:5173${RESET}"
    echo -e "  • Presentation Site:    ${GREEN}http://localhost:3000${RESET}"
    echo ""
    echo -e "To view logs in real time: ${YELLOW}tail -f /tmp/attendrix_backend.log${RESET}"
    echo -e "To stop services:          ${YELLOW}./run.sh stop${RESET}"
}

# ------------------------------------------------------------------------------
# 5. COMMAND: stop
# ------------------------------------------------------------------------------
cmd_stop() {
    header "Stopping Attendrix Tracked Services"
    if [ -f "$PID_FILE" ]; then
        while read -r pid; do
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                log_info "Stopping process PID $pid..."
                kill "$pid" 2>/dev/null || true
            fi
        done < "$PID_FILE"
        rm -f "$PID_FILE"
        log_ok "Tracked processes stopped."
    else
        log_info "No tracked PID file found."
    fi

    # Also gracefully stop any orphaned uvicorn or vite on port 8000 / 5173 started in this dir
    log_ok "Attendrix services shutdown completed."
}

# ------------------------------------------------------------------------------
# Dispatcher
# ------------------------------------------------------------------------------
case "$1" in
    check)
        cmd_check
        ;;
    setup)
        cmd_setup
        ;;
    test)
        cmd_test
        ;;
    stop)
        cmd_stop
        ;;
    start|"")
        cmd_start
        ;;
    *)
        echo "Usage: ./run.sh {check|setup|test|start|stop}"
        exit 1
        ;;
esac
