#!/usr/bin/env bash
set -euo pipefail

# Build Docker images for Authelia
# This script handles building and tagging Docker images as part of the CI pipeline.

DOCKER_IMAGE="authelia/authelia"
BUILDKITE_BUILD_NUMBER="${BUILDKITE_BUILD_NUMBER:-0}"
BUILDKITE_BRANCH="${BUILDKITE_BRANCH:-master}"
BUILDKITE_COMMIT="${BUILDKITE_COMMIT:-unknown}"
BUILDKITE_TAG="${BUILDKITE_TAG:-}"

# Determine the image tag based on branch or tag
if [[ -n "${BUILDKITE_TAG}" ]]; then
  IMAGE_TAG="${BUILDKITE_TAG}"
elif [[ "${BUILDKITE_BRANCH}" == "master" ]]; then
  IMAGE_TAG="master"
else
  # Sanitize branch name for use as a Docker tag
  IMAGE_TAG=$(echo "${BUILDKITE_BRANCH}" | sed 's/[^a-zA-Z0-9._-]/-/g')
fi

PLATFORMS="linux/amd64,linux/arm64,linux/arm/v7"
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "--- :docker: Building Docker image"
echo "Image:     ${DOCKER_IMAGE}"
echo "Tag:       ${IMAGE_TAG}"
echo "Commit:    ${BUILDKITE_COMMIT}"
echo "Platforms: ${PLATFORMS}"
echo "Build Date: ${BUILD_DATE}"

# Set up Docker Buildx builder if not already configured
if ! docker buildx inspect authelia-builder > /dev/null 2>&1; then
  echo "--- :docker: Setting up Docker Buildx builder"
  docker buildx create --name authelia-builder --use --bootstrap
else
  docker buildx use authelia-builder
fi

# Build arguments
BUILD_ARGS=(
  "--build-arg" "BUILD_DATE=${BUILD_DATE}"
  "--build-arg" "BUILD_COMMIT=${BUILDKITE_COMMIT}"
  "--build-arg" "BUILD_TAG=${IMAGE_TAG}"
  "--build-arg" "BUILD_NUMBER=${BUILDKITE_BUILD_NUMBER}"
)

# Determine whether to push or just load the image
if [[ "${PUSH_IMAGE:-false}" == "true" ]]; then
  echo "--- :docker: Building and pushing multi-platform image"
  docker buildx build \
    --platform "${PLATFORMS}" \
    "${BUILD_ARGS[@]}" \
    --tag "${DOCKER_IMAGE}:${IMAGE_TAG}" \
    --tag "${DOCKER_IMAGE}:${BUILDKITE_COMMIT}" \
    --push \
    .
else
  echo "--- :docker: Building image for local use (amd64 only)"
  docker buildx build \
    --platform "linux/amd64" \
    "${BUILD_ARGS[@]}" \
    --tag "${DOCKER_IMAGE}:${IMAGE_TAG}" \
    --tag "${DOCKER_IMAGE}:${BUILDKITE_COMMIT}" \
    --load \
    .
fi

echo "--- :docker: Image build complete"
echo "Built: ${DOCKER_IMAGE}:${IMAGE_TAG}"
