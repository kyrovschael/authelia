#!/usr/bin/env bash
# Script to run the test suite in Buildkite CI environment.
# Handles unit tests, integration tests, and coverage reporting.

set -euo pipefail

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.."; pwd)"

# Default values
TEST_TYPE="${1:-unit}"
COVERAGE_DIR="${PROJECT_ROOT}/coverage"
TEST_TIMEOUT="${TEST_TIMEOUT:-10m}"
PARALLEL_JOBS="${PARALLEL_JOBS:-4}"

echo "--- :go: Running ${TEST_TYPE} tests"
echo "Project root: ${PROJECT_ROOT}"
echo "Test timeout: ${TEST_TIMEOUT}"
echo "Parallel jobs: ${PARALLEL_JOBS}"

# Ensure coverage directory exists
mkdir -p "${COVERAGE_DIR}"

cd "${PROJECT_ROOT}"

run_unit_tests() {
  echo "+++ :go: Running unit tests with coverage"
  go test \
    -v \
    -timeout "${TEST_TIMEOUT}" \
    -parallel "${PARALLEL_JOBS}" \
    -coverprofile="${COVERAGE_DIR}/coverage.out" \
    -covermode=atomic \
    ./...

  echo "--- :bar_chart: Generating coverage report"
  go tool cover -html="${COVERAGE_DIR}/coverage.out" -o "${COVERAGE_DIR}/coverage.html"
  go tool cover -func="${COVERAGE_DIR}/coverage.out" | tail -1
}

run_integration_tests() {
  echo "+++ :docker: Running integration tests"
  if [[ -z "${SUITE:-}" ]]; then
    echo "No SUITE specified, running all integration suites"
    go test \
      -v \
      -timeout "${TEST_TIMEOUT}" \
      -tags integration \
      ./internal/suites/...
  else
    echo "Running integration suite: ${SUITE}"
    go test \
      -v \
      -timeout "${TEST_TIMEOUT}" \
      -tags integration \
      -run "Test${SUITE}Suite" \
      ./internal/suites/...
  fi
}

run_lint() {
  echo "+++ :lint-roller: Running linters"
  if command -v golangci-lint &>/dev/null; then
    golangci-lint run --timeout 5m ./...
  else
    echo "golangci-lint not found, skipping"
    exit 1
  fi
}

run_race_tests() {
  echo "+++ :racing_car: Running race condition tests"
  go test \
    -v \
    -race \
    -timeout "${TEST_TIMEOUT}" \
    -parallel "${PARALLEL_JOBS}" \
    ./...
}

case "${TEST_TYPE}" in
  unit)
    run_unit_tests
    ;;
  integration)
    run_integration_tests
    ;;
  lint)
    run_lint
    ;;
  race)
    run_race_tests
    ;;
  all)
    run_unit_tests
    run_lint
    ;;
  *)
    echo "Unknown test type: ${TEST_TYPE}"
    echo "Usage: $0 [unit|integration|lint|race|all]"
    exit 1
    ;;
esac

echo "--- :white_check_mark: Tests completed successfully"
