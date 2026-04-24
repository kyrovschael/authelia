#!/usr/bin/env bash
set -euo pipefail

# test-unit.sh - Run unit tests for Authelia
# This script handles running Go unit tests with coverage reporting
# and optional race condition detection.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../../ && pwd)"

cd "${DIR}"

echo "--- :go: Setting up Go environment"
export GOPATH="${HOME}/go"
export PATH="${GOPATH}/bin:${PATH}"

# Default values
COVERAGE=${COVERAGE:-true}
RACE=${RACE:-true}
TIMEOUT=${TIMEOUT:-"5m"}
OUTPUT_DIR="${DIR}/coverage"
COVERAGE_FILE="${OUTPUT_DIR}/coverage.txt"
COVERAGE_HTML="${OUTPUT_DIR}/coverage.html"

# Packages to test (default to all packages)
PACKAGES=${PACKAGES:-"./..."}

mkdir -p "${OUTPUT_DIR}"

echo "--- :go: Running Go unit tests"

GO_TEST_ARGS=(
  "-v"
  "-timeout" "${TIMEOUT}"
)

if [[ "${RACE}" == "true" ]]; then
  echo "Race condition detection: enabled"
  GO_TEST_ARGS+=("-race")
fi

if [[ "${COVERAGE}" == "true" ]]; then
  echo "Coverage reporting: enabled"
  GO_TEST_ARGS+=(
    "-coverprofile=${COVERAGE_FILE}"
    "-covermode=atomic"
  )
fi

go test "${GO_TEST_ARGS[@]}" ${PACKAGES} 2>&1 | tee "${OUTPUT_DIR}/test-output.log"
TEST_EXIT_CODE=${PIPESTATUS[0]}

if [[ "${COVERAGE}" == "true" ]] && [[ -f "${COVERAGE_FILE}" ]]; then
  echo "--- :bar_chart: Generating coverage report"
  go tool cover "-html=${COVERAGE_FILE}" "-o=${COVERAGE_HTML}"

  echo "+++ :bar_chart: Coverage Summary"
  go tool cover "-func=${COVERAGE_FILE}" | tail -n 1
fi

if [[ ${TEST_EXIT_CODE} -ne 0 ]]; then
  echo "^^^ +++"
  echo "--- :x: Unit tests failed with exit code ${TEST_EXIT_CODE}"
  exit ${TEST_EXIT_CODE}
fi

echo "--- :white_check_mark: Unit tests passed successfully"
