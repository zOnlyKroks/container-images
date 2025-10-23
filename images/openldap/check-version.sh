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
CURRENT_VERSION=$(grep "ARG OPENLDAP_VERSION=" Dockerfile | head -1 | cut -d'=' -f2)

echo "Current version: $CURRENT_VERSION"

# Fetch latest release from OpenLDAP download page
# OpenLDAP uses semantic versioning (2.6.10, etc.)
LATEST_VERSION=$(curl -s https://www.openldap.org/software/download/ | \
    grep -oP 'openldap-\K[0-9]+\.[0-9]+\.[0-9]+' | \
    head -1)

echo "Latest version: $LATEST_VERSION"

# Compare versions
if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
  echo "Already up to date!"
  [ -n "$GITHUB_OUTPUT" ] && echo "update_available=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

# Check if new version is actually newer
if [ "$(printf '%s\n' "$LATEST_VERSION" "$CURRENT_VERSION" | sort -V | head -n1)" != "$LATEST_VERSION" ]; then
  echo "Update available: $CURRENT_VERSION -> $LATEST_VERSION"

  # Update Dockerfile
  $SED_INPLACE "s|ARG OPENLDAP_VERSION=$CURRENT_VERSION|ARG OPENLDAP_VERSION=$LATEST_VERSION|g" Dockerfile
  $SED_CLEANUP Dockerfile.bak 2>/dev/null || true

  # Update config.yaml - version field
  $SED_INPLACE "s|version: \"$CURRENT_VERSION\"|version: \"$LATEST_VERSION\"|g" config.yaml
  $SED_CLEANUP config.yaml.bak 2>/dev/null || true

  # Update config.yaml - build_args OPENLDAP_VERSION field
  $SED_INPLACE "s|OPENLDAP_VERSION: \"$CURRENT_VERSION\"|OPENLDAP_VERSION: \"$LATEST_VERSION\"|g" config.yaml
  $SED_CLEANUP config.yaml.bak 2>/dev/null || true

  # Set outputs for GitHub Action (only if running in GitHub Actions)
  if [ -n "$GITHUB_OUTPUT" ]; then
    # shellcheck disable=SC2129
    echo "update_available=true" >> "$GITHUB_OUTPUT"
    echo "current_version=$CURRENT_VERSION" >> "$GITHUB_OUTPUT"
    echo "new_version=$LATEST_VERSION" >> "$GITHUB_OUTPUT"
    echo "release_notes=OpenLDAP $LATEST_VERSION released. Check https://www.openldap.org/software/download/ for details." >> "$GITHUB_OUTPUT"
  fi

  exit 0
else
  echo "Current version is newer or equal"
  [ -n "$GITHUB_OUTPUT" ] && echo "update_available=false" >> "$GITHUB_OUTPUT"
  exit 0
fi
