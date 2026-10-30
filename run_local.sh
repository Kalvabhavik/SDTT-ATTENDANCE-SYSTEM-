#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
DASHBOARD_DIR="$ROOT_DIR/apps/dashboard"
MOBILE_DIR="$ROOT_DIR/apps/mobile"
BACKEND_PID=""
DASHBOARD_PID=""

export PATH="$HOME/development/flutter/bin:$HOME/Android/Sdk/platform-tools:$HOME/Android/Sdk/cmdline-tools/latest/bin:$PATH"

log() { printf '\n[run-local] %s\n' "$*"; }
die() { printf '[run-local] ERROR: %s\n' "$*" >&2; exit 1; }

cleanup() {
  local exit_code=$?
  trap - EXIT INT TERM
  for pid in "$DASHBOARD_PID" "$BACKEND_PID"; do
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi
  done
  [[ -z "$DASHBOARD_PID" ]] || wait "$DASHBOARD_PID" 2>/dev/null || true
  [[ -z "$BACKEND_PID" ]] || wait "$BACKEND_PID" 2>/dev/null || true
  exit "$exit_code"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'HELP'
Usage: ./run_local.sh

Starts the local FastAPI backend and dashboard, then runs the Flutter app.
An attached Android device uses adb reverse so the app can reach the backend at
http://localhost:8000/api. Ctrl+C stops the backend and dashboard processes.

Requirements: Python 3, Node.js/npm, Flutter; adb is required for Android devices.
HELP
  exit 0
fi

command -v python3 >/dev/null 2>&1 || die "Python 3 is required."
command -v npm >/dev/null 2>&1 || die "Node.js and npm are required."
command -v flutter >/dev/null 2>&1 || die "Flutter was not found in PATH or ~/development/flutter/bin."
[[ -f "$BACKEND_DIR/requirements.txt" ]] || die "Backend requirements file not found."
[[ -f "$DASHBOARD_DIR/package.json" ]] || die "Dashboard package.json not found."
[[ -f "$MOBILE_DIR/pubspec.yaml" ]] || die "Flutter app pubspec.yaml not found."

if [[ ! -x "$BACKEND_DIR/.venv/bin/python" ]]; then
  log "Creating backend virtual environment and installing Python dependencies"
  python3 -m venv "$BACKEND_DIR/.venv"
fi
if [[ ! -x "$BACKEND_DIR/.venv/bin/uvicorn" ]]; then
  log "Installing backend Python dependencies"
  "$BACKEND_DIR/.venv/bin/python" -m pip install -r "$BACKEND_DIR/requirements.txt"
fi

if [[ ! -d "$DASHBOARD_DIR/node_modules" ]]; then
  log "Installing dashboard dependencies"
  npm --prefix "$DASHBOARD_DIR" install
fi

log "Resolving Flutter dependencies"
(cd "$MOBILE_DIR" && flutter pub get)

DEVICE_ID="${DEVICE_ID:-}"
if [[ -z "$DEVICE_ID" ]] && command -v adb >/dev/null 2>&1; then
  DEVICE_ID="$(adb devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')"
fi

if [[ -n "$DEVICE_ID" ]]; then
  command -v adb >/dev/null 2>&1 || die "DEVICE_ID was set but adb is unavailable."
  log "Using Android device $DEVICE_ID and forwarding backend port 8000"
  adb -s "$DEVICE_ID" reverse tcp:8000 tcp:8000
fi

log "Starting FastAPI backend on 0.0.0.0:8000"
"$BACKEND_DIR/.venv/bin/python" -m uvicorn app.main:app \
  --app-dir "$BACKEND_DIR" --host 0.0.0.0 --port 8000 \
  > "$ROOT_DIR/backend-local.log" 2>&1 &
BACKEND_PID=$!

log "Waiting for backend health endpoint"
backend_ready=false
for _ in {1..40}; do
  if curl -fsS --max-time 1 http://127.0.0.1:8000/api/time >/dev/null 2>&1; then
    backend_ready=true
    break
  fi
  if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
    cat "$ROOT_DIR/backend-local.log" >&2
    die "Backend exited before becoming ready."
  fi
  sleep 0.5
done
if [[ "$backend_ready" != true ]]; then
  cat "$ROOT_DIR/backend-local.log" >&2
  die "Backend did not become ready at http://localhost:8000/api/time."
fi

log "Starting dashboard on http://localhost:5173"
"$DASHBOARD_DIR/node_modules/.bin/vite" --host 0.0.0.0 --port 5173 --strictPort \
  > "$ROOT_DIR/dashboard-local.log" 2>&1 &
DASHBOARD_PID=$!

log "Backend:   http://localhost:8000/api"
log "API docs:  http://localhost:8000/docs"
log "Dashboard: http://localhost:5173"
log "Starting Flutter app against http://localhost:8000/api"
if [[ -n "$DEVICE_ID" ]]; then
  (cd "$MOBILE_DIR" && flutter run -d "$DEVICE_ID" --dart-define=API_BASE_URL=http://localhost:8000/api)
else
  (cd "$MOBILE_DIR" && flutter run --dart-define=API_BASE_URL=http://localhost:8000/api)
fi
