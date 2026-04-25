#!/usr/bin/env bash
set -euo pipefail

# End-to-end test runner script for Authelia
# Runs Playwright-based E2E tests against a live Authelia instance

RANDOM_PORT=$((RANDOM % 1000 + 9000))
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}"" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

AUTHELIA_HOST="${AUTHELIA_HOST:-localhost}"
AUTHELIA_PORT="${AUTHELIA_PORT:-${RANDOM_PORT}}"
AUTHELIA_BASE_URL="${AUTHELIA_BASE_URL:-http://${AUTHELIA_HOST}:${AUTHELIA_PORT}}"
TEST_SUITE="${TEST_SUITE:-}"
TEST_TIMEOUT="${TEST_TIMEOUT:-120000}"
RETRY_COUNT="${RETRY_COUNT:-2}"
PARALLEL_WORKERS="${PARALLEL_WORKERS:-4}"
ARTIFACT_DIR="${ARTIFACT_DIR:-${ROOT_DIR}/test/e2e/artifacts}"
VIDEO_ON_FAILURE="${VIDEO_ON_FAILURE:-true}"
SCREENSHOT_ON_FAILURE="${SCREENSHOT_ON_FAILURE:-true}"

echo "--- :playwright: Configuring E2E test environment"
echo "Authelia Base URL: ${AUTHELIA_BASE_URL}"
echo "Test Suite: ${TEST_SUITE:-all}"
echo "Timeout: ${TEST_TIMEOUT}ms"
echo "Retry Count: ${RETRY_COUNT}"
echo "Parallel Workers: ${PARALLEL_WORKERS}"

# Ensure artifact directory exists
mkdir -p "${ARTIFACT_DIR}"
mkdir -p "${ARTIFACT_DIR}/screenshots"
mkdir -p "${ARTIFACT_DIR}/videos"
mkdir -p "${ARTIFACT_DIR}/traces"

# Install Playwright browsers if not already cached
echo "--- :playwright: Installing Playwright browsers"
cd "${ROOT_DIR}/web"
if ! npx playwright install --dry-run > /dev/null 2>&1; then
  npx playwright install --with-deps chromium firefox
else
  echo "Playwright browsers already installed, skipping."
fi

# Wait for Authelia to be ready
echo "--- :hourglass: Waiting for Authelia to be ready at ${AUTHELIA_BASE_URL}"
MAX_WAIT=60
ELAPSED=0
until curl --silent --fail "${AUTHELIA_BASE_URL}/api/health" > /dev/null 2>&1; do
  if [ "${ELAPSED}" -ge "${MAX_WAIT}" ]; then
    echo "ERROR: Authelia did not become ready within ${MAX_WAIT} seconds."
    exit 1
  fi
  echo "Waiting for Authelia... (${ELAPSED}s elapsed)"
  sleep 2
  ELAPSED=$((ELAPSED + 2))
done
echo "Authelia is ready."

# Build Playwright test arguments
PLAYWRIGHT_ARGS=(
  "--timeout=${TEST_TIMEOUT}"
  "--retries=${RETRY_COUNT}"
  "--workers=${PARALLEL_WORKERS}"
  "--output=${ARTIFACT_DIR}"
  "--reporter=list,html"
)

if [ -n "${TEST_SUITE}" ]; then
  PLAYWRIGHT_ARGS+=("--grep=${TEST_SUITE}")
fi

if [ "${VIDEO_ON_FAILURE}" = "true" ]; then
  PLAYWRIGHT_ARGS+=("--video=retain-on-failure")
fi

if [ "${SCREENSHOT_ON_FAILURE}" = "true" ]; then
  PLAYWRIGHT_ARGS+=("--screenshot=only-on-failure")
fi

# Export environment variables for Playwright config
export AUTHELIA_BASE_URL
export PLAYWRIGHT_HTML_REPORT="${ARTIFACT_DIR}/playwright-report"

echo "+++ :playwright: Running E2E tests"
set +e
npx playwright test "${PLAYWRIGHT_ARGS[@]}" 2>&1
TEST_EXIT_CODE=$?
set -e

# Collect and report results
echo "--- :bar_chart: E2E test results"
if [ ${TEST_EXIT_CODE} -eq 0 ]; then
  echo "All E2E tests passed!"
else
  echo "E2E tests failed with exit code: ${TEST_EXIT_CODE}"
  echo "Artifacts available at: ${ARTIFACT_DIR}"
fi

exit ${TEST_EXIT_CODE}
