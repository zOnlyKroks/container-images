#!/bin/bash
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Detect OS for sed compatibility
if [[ "$OSTYPE" == "darwin"* ]]; then
  SED_INPLACE="sed -i.bak"
  SED_CLEANUP="rm -f"
else
  SED_INPLACE="sed -i"
  SED_CLEANUP="true"
fi

# Get current version from Dockerfile
CURRENT_VERSION=$(grep "ARG RELEASE=" Dockerfile | head -1 | cut -d'=' -f2)

echo "Current version: $CURRENT_VERSION"

# Fetch latest release from GitHub
LATEST_VERSION=$(curl -s https://api.github.com/repos/minio/minio/releases/latest | jq -r '.tag_name')

echo "Latest version: $LATEST_VERSION"

# Compare versions (lexicographically since they're date-based)
if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
  echo "Already up to date!"
  [ -n "$GITHUB_OUTPUT" ] && echo "update_available=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

# Check if new version is actually newer (string comparison works for date format)
if [[ "$LATEST_VERSION" > "$CURRENT_VERSION" ]]; then
  echo "Update available: $CURRENT_VERSION -> $LATEST_VERSION"

  # Update Dockerfile
  $SED_INPLACE "s|ARG RELEASE=$CURRENT_VERSION|ARG RELEASE=$LATEST_VERSION|g" Dockerfile
  $SED_CLEANUP Dockerfile.bak 2>/dev/null || true

  # Update config.yaml - version field
  $SED_INPLACE "s|version: \"$CURRENT_VERSION\"|version: \"$LATEST_VERSION\"|g" config.yaml
  $SED_CLEANUP config.yaml.bak 2>/dev/null || true

  # Update config.yaml - build_args RELEASE field
  $SED_INPLACE "s|RELEASE: \"$CURRENT_VERSION\"|RELEASE: \"$LATEST_VERSION\"|g" config.yaml
  $SED_CLEANUP config.yaml.bak 2>/dev/null || true

  # Get release notes
  RELEASE_NOTES=$(curl -s https://api.github.com/repos/minio/minio/releases/latest | jq -r '.body' | head -20)

  # Set outputs for GitHub Action
  # shellcheck disable=SC2129
  echo "update_available=true" >> "$GITHUB_OUTPUT"
  echo "current_version=$CURRENT_VERSION" >> "$GITHUB_OUTPUT"
  echo "new_version=$LATEST_VERSION" >> "$GITHUB_OUTPUT"
  {
    echo "release_notes<<EOF"
    echo "$RELEASE_NOTES"
    echo "EOF"
  } >> "$GITHUB_OUTPUT"

  exit 0
else
  echo "Current version is newer or equal"
  echo "update_available=false" >> "$GITHUB_OUTPUT"
  exit 0
fi