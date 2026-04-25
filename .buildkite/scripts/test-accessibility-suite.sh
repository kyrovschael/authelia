#!/usr/bin/env bash
# test-accessibility-suite.sh - Run a specific accessibility test suite in Buildkite
# This script handles setup, execution, and artifact collection for accessibility suites.

set -euo pipefail

# -------------------------------------------------------
# Variables
# -------------------------------------------------------
SUITE=${1:-""}
BROWSER=${BROWSER:-"chromium"}
HEADLESS=${HEADLESS:-"true"}
RETRY_COUNT=${RETRY_COUNT:-2}
ARTIFACT_DIR="test/accessibility/results"
SCREENSHOT_DIR="test/accessibility/screenshots"
LOG_DIR="test/accessibility/logs"

# -------------------------------------------------------
# Validate inputs
# -------------------------------------------------------
if [[ -z "${SUITE}" ]]; then
  echo "--- :x: Error: No accessibility suite specified"
  echo "Usage: $0 <suite-name>"
  exit 1
fi

echo "--- :wheelchair: Accessibility Suite: ${SUITE}"
echo "Browser: ${BROWSER}"
echo "Headless: ${HEADLESS}"

# -------------------------------------------------------
# Prepare directories
# -------------------------------------------------------
echo "--- :file_folder: Preparing output directories"
mkdir -p "${ARTIFACT_DIR}" "${SCREENSHOT_DIR}" "${LOG_DIR}"

# -------------------------------------------------------
# Wait for services to be healthy
# -------------------------------------------------------
echo "--- :hourglass: Waiting for services to be ready"
if [[ -f ".buildkite/scripts/wait-for-services.sh" ]]; then
  bash .buildkite/scripts/wait-for-services.sh
else
  echo "No wait-for-services script found, sleeping 10s as fallback"
  sleep 10
fi

# -------------------------------------------------------
# Run the accessibility suite
# -------------------------------------------------------
echo "+++ :axe: Running accessibility suite: ${SUITE}"

RETRY=0
EXIT_CODE=0

while [[ ${RETRY} -le ${RETRY_COUNT} ]]; do
  if [[ ${RETRY} -gt 0 ]]; then
    echo "--- :repeat: Retry attempt ${RETRY}/${RETRY_COUNT} for suite: ${SUITE}"
  fi

  set +e
  HEADLESS="${HEADLESS}" BROWSER="${BROWSER}" \
    npx jest \
      --testPathPattern="accessibility/${SUITE}" \
      --reporters=default \
      --reporters=jest-junit \
      --outputFile="${ARTIFACT_DIR}/${SUITE}-results.xml" \
      2>&1 | tee "${LOG_DIR}/${SUITE}.log"
  EXIT_CODE=$?
  set -e

  if [[ ${EXIT_CODE} -eq 0 ]]; then
    break
  fi

  RETRY=$((RETRY + 1))
done

# -------------------------------------------------------
# Collect artifacts
# -------------------------------------------------------
echo "--- :paperclip: Collecting artifacts"

if compgen -G "${SCREENSHOT_DIR}/*.png" > /dev/null 2>&1; then
  echo "Uploading screenshots..."
  buildkite-agent artifact upload "${SCREENSHOT_DIR}/**/*.png" || true
fi

if compgen -G "${ARTIFACT_DIR}/*.xml" > /dev/null 2>&1; then
  echo "Uploading test results..."
  buildkite-agent artifact upload "${ARTIFACT_DIR}/**/*.xml" || true
fi

if compgen -G "${LOG_DIR}/*.log" > /dev/null 2>&1; then
  echo "Uploading logs..."
  buildkite-agent artifact upload "${LOG_DIR}/**/*.log" || true
fi

# -------------------------------------------------------
# Final status
# -------------------------------------------------------
if [[ ${EXIT_CODE} -ne 0 ]]; then
  echo "--- :x: Accessibility suite '${SUITE}' failed after ${RETRY_COUNT} retries"
  exit ${EXIT_CODE}
fi

echo "--- :white_check_mark: Accessibility suite '${SUITE}' passed"
exit 0
