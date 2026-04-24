#!/usr/bin/env bash
set -euo pipefail

# test-integration-suite.sh - Run a specific integration test suite
# Usage: ./test-integration-suite.sh <suite_name> [options]
#
# This script handles running individual integration test suites with
# proper setup, teardown, and artifact collection.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT_DIR="$(cd "${DIR}/../.." && pwd)"

# Source common utilities if available
if [[ -f "${DIR}/common.sh" ]]; then
  # shellcheck source=scripts/common.sh
  source "${DIR}/common.sh"
fi

SUITE_NAME="${1:-}"
TIMEOUT="${SUITE_TIMEOUT:-300}"
RETRY_COUNT="${SUITE_RETRY:-2}"
ARTIFACT_DIR="${ROOT_DIR}/artifacts/integration"
LOG_DIR="${ARTIFACT_DIR}/logs"

if [[ -z "${SUITE_NAME}" ]]; then
  echo "Error: Suite name is required"
  echo "Usage: $0 <suite_name>"
  exit 1
fi

echo "--- :test_tube: Running integration suite: ${SUITE_NAME}"
echo "Timeout: ${TIMEOUT}s | Retries: ${RETRY_COUNT}"

# Create artifact directories
mkdir -p "${LOG_DIR}/${SUITE_NAME}"

# Ensure docker-compose is available
if ! command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null 2>&1; then
  echo "Error: docker-compose or docker compose plugin is required"
  exit 1
fi

# Determine docker compose command
DOCKER_COMPOSE_CMD="docker-compose"
if ! command -v docker-compose &>/dev/null; then
  DOCKER_COMPOSE_CMD="docker compose"
fi

cleanup() {
  local exit_code=$?
  echo "--- :broom: Cleaning up suite: ${SUITE_NAME}"

  # Collect logs before teardown
  if [[ -d "${ROOT_DIR}/internal/suites/${SUITE_NAME}" ]]; then
    echo "Collecting container logs..."
    ${DOCKER_COMPOSE_CMD} \
      -f "${ROOT_DIR}/internal/suites/${SUITE_NAME}/docker-compose.yml" \
      logs --no-color 2>/dev/null > "${LOG_DIR}/${SUITE_NAME}/docker-compose.log" || true
  fi

  # Stop and remove containers
  ${DOCKER_COMPOSE_CMD} \
    -f "${ROOT_DIR}/internal/suites/${SUITE_NAME}/docker-compose.yml" \
    down --volumes --remove-orphans 2>/dev/null || true

  echo "Cleanup complete for suite: ${SUITE_NAME}"
  exit "${exit_code}"
}

trap cleanup EXIT INT TERM

# Run the suite with retry logic
run_suite() {
  local attempt=1
  local max_attempts=$((RETRY_COUNT + 1))

  while [[ ${attempt} -le ${max_attempts} ]]; do
    echo "--- :arrow_forward: Attempt ${attempt}/${max_attempts} for suite: ${SUITE_NAME}"

    if timeout "${TIMEOUT}" go test \
      -v \
      -timeout "${TIMEOUT}s" \
      -run "^TestRunSuite$/^${SUITE_NAME}$" \
      ./internal/suites/... \
      2>&1 | tee "${LOG_DIR}/${SUITE_NAME}/test-attempt-${attempt}.log"; then
      echo "+++ :white_check_mark: Suite ${SUITE_NAME} passed on attempt ${attempt}"
      return 0
    fi

    local exit_code=$?
    echo "Suite ${SUITE_NAME} failed on attempt ${attempt} with exit code ${exit_code}"

    if [[ ${attempt} -lt ${max_attempts} ]]; then
      echo "Retrying in 10 seconds..."
      sleep 10
    fi

    ((attempt++))
  done

  echo "+++ :x: Suite ${SUITE_NAME} failed after ${max_attempts} attempt(s)"
  return 1
}

run_suite
