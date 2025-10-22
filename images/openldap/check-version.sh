#!/bin/bash
set -e

# Get current version from Dockerfile
CURRENT_VERSION=$(grep "ARG OPENLDAP_VERSION=" Dockerfile | head -1 | cut -d'=' -f2)

echo "Current version: $CURRENT_VERSION"

# Fetch latest LTS version from OpenLDAP website
# The download page lists the current LTS version
LATEST_VERSION=$(curl -s https://www.openldap.org/software/download/ | \
  grep -oP 'OpenLDAP-\K[0-9]+\.[0-9]+\.[0-9]+' | head -1)

echo "Latest version: $LATEST_VERSION"

# Compare versions
if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
  echo "Already up to date!"
  echo "update_available=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

# Simple version comparison (assumes X.Y.Z format)
# Convert versions to comparable numbers
current_num=$(echo "$CURRENT_VERSION" | awk -F. '{ printf("%d%03d%03d\n", $1,$2,$3); }')
latest_num=$(echo "$LATEST_VERSION" | awk -F. '{ printf("%d%03d%03d\n", $1,$2,$3); }')

if [ "$latest_num" -gt "$current_num" ]; then
  echo "Update available: $CURRENT_VERSION -> $LATEST_VERSION"

  # Update Dockerfile
  sed -i "s|ARG OPENLDAP_VERSION=$CURRENT_VERSION|ARG OPENLDAP_VERSION=$LATEST_VERSION|g" Dockerfile

  # Update config.yaml - version field
  sed -i "s|version: \"$CURRENT_VERSION\"|version: \"$LATEST_VERSION\"|g" config.yaml

  # Update config.yaml - build_args OPENLDAP_VERSION field
  sed -i "s|OPENLDAP_VERSION: \"$CURRENT_VERSION\"|OPENLDAP_VERSION: \"$LATEST_VERSION\"|g" config.yaml

  # Get release notes (OpenLDAP doesn't have a simple API, so provide a link)
  RELEASE_NOTES="New version $LATEST_VERSION available. See release notes at: https://www.openldap.org/software/release/changes_lts.html"

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