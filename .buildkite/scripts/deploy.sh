#!/usr/bin/env bash
# deploy.sh - Handles deployment of Authelia images to container registries
# and triggers downstream deployment pipelines.

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
REGISTRY_GHCR="ghcr.io/authelia"
REGISTRY_DOCKER="docker.io/authelia"
IMAGE_NAME="authelia"

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------
log() {
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $*"
}

die() {
  echo "[ERROR] $*" >&2
  exit 1
}

require_env() {
  local var="$1"
  [[ -n "${!var:-}" ]] || die "Required environment variable '${var}' is not set."
}

# ---------------------------------------------------------------------------
# Validate required environment variables
# ---------------------------------------------------------------------------
require_env BUILDKITE_TAG
require_env GHCR_TOKEN
require_env DOCKER_TOKEN
require_env DOCKER_USERNAME

VERSION="${BUILDKITE_TAG#v}"

if [[ -z "${VERSION}" ]]; then
  die "Could not determine version from BUILDKITE_TAG='${BUILDKITE_TAG}'."
fi

log "Deploying Authelia version: ${VERSION}"

# ---------------------------------------------------------------------------
# Login to container registries
# ---------------------------------------------------------------------------
log "Authenticating with GitHub Container Registry..."
echo "${GHCR_TOKEN}" | docker login ghcr.io \
  --username "${GITHUB_ACTOR:-authelia-bot}" \
  --password-stdin

log "Authenticating with Docker Hub..."
echo "${DOCKER_TOKEN}" | docker login docker.io \
  --username "${DOCKER_USERNAME}" \
  --password-stdin

# ---------------------------------------------------------------------------
# Determine tags to push
# ---------------------------------------------------------------------------
TAGS=()
TAGS+=("${VERSION}")

# Tag as 'latest' only for non-pre-release versions (no hyphen in version)
if [[ "${VERSION}" != *"-"* ]]; then
  TAGS+=("latest")
  log "Version '${VERSION}' is a stable release; will also tag as 'latest'."
else
  log "Version '${VERSION}' appears to be a pre-release; skipping 'latest' tag."
fi

# ---------------------------------------------------------------------------
# Push images to each registry
# ---------------------------------------------------------------------------
for REGISTRY in "${REGISTRY_GHCR}" "${REGISTRY_DOCKER}"; do
  for TAG in "${TAGS[@]}"; do
    SOURCE_IMAGE="${REGISTRY_GHCR}/${IMAGE_NAME}:${VERSION}"
    TARGET_IMAGE="${REGISTRY}/${IMAGE_NAME}:${TAG}"

    if [[ "${SOURCE_IMAGE}" != "${TARGET_IMAGE}" ]]; then
      log "Tagging '${SOURCE_IMAGE}' -> '${TARGET_IMAGE}'..."
      docker tag "${SOURCE_IMAGE}" "${TARGET_IMAGE}"
    fi

    log "Pushing '${TARGET_IMAGE}'..."
    docker push "${TARGET_IMAGE}"
  done
done

log "Deployment of Authelia ${VERSION} completed successfully."
