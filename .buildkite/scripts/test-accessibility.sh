#!/usr/bin/env bash
set -euo pipefail

# test-accessibility.sh - Run accessibility tests for Authelia
# This script handles running axe-core based accessibility checks
# against the Authelia web UI components.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../../ && pwd)"

echo "--- :accessibility: Setting up accessibility test environment"

cd "${DIR}"

# Ensure required tools are available
if ! command -v node &>/dev/null; then
  echo "Error: node is not installed or not in PATH" >&2
  exit 1
fi

if ! command -v npm &>/dev/null; then
  echo "Error: npm is not installed or not in PATH" >&2
  exit 1
fi

# Default configuration
AUTHELIA_URL=${AUTHELIA_URL:-"http://localhost:9091"}
REPORT_DIR=${REPORT_DIR:-"${DIR}/accessibility-reports"}
TIMEOUT=${TIMEOUT:-30000}
VIOLATION_THRESHOLD=${VIOLATION_THRESHOLD:-0}

# Create report directory if it doesn't exist
mkdir -p "${REPORT_DIR}"

echo "+++ :npm: Installing accessibility test dependencies"
cd "${DIR}/web"
npm ci --prefer-offline 2>&1 | tail -5

echo "--- :mag: Waiting for Authelia to be ready at ${AUTHELIA_URL}"
MAX_RETRIES=30
RETRY_COUNT=0
until curl --silent --fail "${AUTHELIA_URL}/api/health" &>/dev/null; do
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [[ ${RETRY_COUNT} -ge ${MAX_RETRIES} ]]; then
    echo "Error: Authelia did not become ready within the timeout period" >&2
    exit 1
  fi
  echo "Waiting for Authelia... attempt ${RETRY_COUNT}/${MAX_RETRIES}"
  sleep 2
done
echo "Authelia is ready."

echo "+++ :white_check_mark: Running accessibility tests"

ACCESSIBILITY_VIOLATIONS=0

# Run axe accessibility tests against key pages
PAGES=(
  "/"
  "/login"
  "/reset-password"
  "/consent"
)

for PAGE in "${PAGES[@]}"; do
  echo "--- :mag: Testing page: ${AUTHELIA_URL}${PAGE}"
  set +e
  node "${DIR}/web/scripts/accessibility-check.js" \
    --url "${AUTHELIA_URL}${PAGE}" \
    --timeout "${TIMEOUT}" \
    --output "${REPORT_DIR}/report-$(echo "${PAGE}" | tr '/' '-' | sed 's/^-//').json" \
    2>&1
  EXIT_CODE=$?
  set -e

  if [[ ${EXIT_CODE} -ne 0 ]]; then
    echo "Accessibility violations found on page: ${PAGE}"
    ACCESSIBILITY_VIOLATIONS=$((ACCESSIBILITY_VIOLATIONS + 1))
  fi
done

echo "--- :bar_chart: Accessibility test summary"
echo "Pages tested: ${#PAGES[@]}"
echo "Pages with violations: ${ACCESSIBILITY_VIOLATIONS}"

# Upload reports as artifacts
if compgen -G "${REPORT_DIR}/*.json" &>/dev/null; then
  echo "--- :file_folder: Accessibility reports available in ${REPORT_DIR}"
fi

if [[ ${ACCESSIBILITY_VIOLATIONS} -gt ${VIOLATION_THRESHOLD} ]]; then
  echo "Error: Accessibility violations exceed threshold (${ACCESSIBILITY_VIOLATIONS} > ${VIOLATION_THRESHOLD})" >&2
  exit 1
fi

echo "All accessibility checks passed."
