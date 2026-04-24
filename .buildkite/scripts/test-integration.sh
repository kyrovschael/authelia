#!/usr/bin/env bash
# Integration test runner script for Authelia CI/CD pipeline.
# Handles setup, execution, and teardown of integration test suites.
set -euo pipefail

# -------------------------------------------------------
# Environment & Defaults
# -------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

SUITE="${SUITE:-}"
BROWSER="${BROWSER:-chromium}"
HEADLESS="${HEADLESS:-true}"
LOG_LEVEL="${LOG_LEVEL:-info}"
TIMEOUT="${TIMEOUT:-60000}"
RETRIES="${RETRIES:-1}"
COVERAGE="${COVERAGE:-false}"

# -------------------------------------------------------
# Helper Functions
# -------------------------------------------------------
log() {
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $*"
}

error() {
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] ERROR: $*" >&2
}

cleanup() {
  local exit_code=$?
  log "Running cleanup (exit code: ${exit_code})..."

  if [[ -f "${PROJECT_ROOT}/docker-compose.yml" ]]; then
    log "Stopping docker-compose services..."
    docker compose -f "${PROJECT_ROOT}/docker-compose.yml" down --remove-orphans --volumes 2>/dev/null || true
  fi

  log "Cleanup complete."
  exit "${exit_code}"
}

trap cleanup EXIT INT TERM

# -------------------------------------------------------
# Validate Inputs
# -------------------------------------------------------
if [[ -z "${SUITE}" ]]; then
  error "SUITE environment variable must be set."
  error "Available suites can be found in internal/suites/suite_*.go"
  exit 1
fi

log "Starting integration test suite: ${SUITE}"
log "Browser: ${BROWSER} | Headless: ${HEADLESS} | Retries: ${RETRIES}"

# -------------------------------------------------------
# Pre-flight Checks
# -------------------------------------------------------
for cmd in docker go node; do
  if ! command -v "${cmd}" &>/dev/null; then
    error "Required command not found: ${cmd}"
    exit 1
  fi
done

cd "${PROJECT_ROOT}"

# -------------------------------------------------------
# Build Authelia Binary (if not already built)
# -------------------------------------------------------
if [[ ! -f "${PROJECT_ROOT}/authelia" ]]; then
  log "Building Authelia binary..."
  go build -o authelia ./cmd/authelia/ 2>&1
  log "Build complete."
else
  log "Using existing Authelia binary."
fi

# -------------------------------------------------------
# Setup Test Environment
# -------------------------------------------------------
log "Setting up test environment for suite: ${SUITE}..."

export AUTHELIA_SUITE="${SUITE}"
export BROWSER
export HEADLESS
export TIMEOUT

# Install Node dependencies if needed
if [[ -f "${PROJECT_ROOT}/web/package.json" ]] && [[ ! -d "${PROJECT_ROOT}/web/node_modules" ]]; then
  log "Installing Node.js dependencies..."
  pushd "${PROJECT_ROOT}/web" > /dev/null
  npm ci --silent
  popd > /dev/null
fi

# -------------------------------------------------------
# Run Integration Tests
# -------------------------------------------------------
log "Executing integration tests..."

TEST_ARGS=(
  "-v"
  "-timeout" "15m"
  "-count" "1"
  "-run" "Test${SUITE}"
)

if [[ "${COVERAGE}" == "true" ]]; then
  TEST_ARGS+=("-coverprofile" "coverage-integration-${SUITE}.out" "-covermode" "atomic")
  log "Coverage reporting enabled: coverage-integration-${SUITE}.out"
fi

go test "${TEST_ARGS[@]}" ./internal/suites/ 2>&1

log "Integration test suite '${SUITE}' completed successfully."
