#!/bin/bash
# OpenLDAP Smoke Test
# This script performs basic validation that the OpenLDAP container is functional

set -euo pipefail

IMAGE_TAG="${1:-cloudpirates/openldap:test}"
CONTAINER_NAME="openldap-smoke-test-$$"

echo "Running smoke test for OpenLDAP image: $IMAGE_TAG"

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
}

trap cleanup EXIT

# Start OpenLDAP container
echo "Starting OpenLDAP container..."
docker run -d \
    --name "$CONTAINER_NAME" \
    -p 389:389 \
    -p 636:636 \
    "$IMAGE_TAG"

# Wait for OpenLDAP to be ready
echo "Waiting for OpenLDAP to start..."
RETRIES=30
until docker exec "$CONTAINER_NAME" ldapsearch -x -H ldap://localhost -b "" -s base "(objectclass=*)" namingContexts >/dev/null 2>&1; do
    RETRIES=$((RETRIES - 1))
    if [ $RETRIES -eq 0 ]; then
        echo "ERROR: OpenLDAP failed to start within expected time"
        docker logs "$CONTAINER_NAME"
        exit 1
    fi
    echo "Waiting... ($RETRIES attempts remaining)"
    sleep 2
done

echo "OpenLDAP is ready!"

# Test 1: Check if OpenLDAP is responding
echo "Test 1: Checking OpenLDAP connection..."
if docker exec "$CONTAINER_NAME" ldapsearch -x -H ldap://localhost -b "" -s base "(objectclass=*)" namingContexts >/dev/null 2>&1; then
    echo "✅ OpenLDAP connection check passed"
else
    echo "❌ OpenLDAP connection check failed"
    exit 1
fi

# Test 2: Check slapd process is running
echo "Test 2: Checking slapd process..."
if docker exec "$CONTAINER_NAME" sh -c 'ps aux | grep -v grep | grep -q slapd'; then
    echo "✅ slapd process check passed"
else
    echo "❌ slapd process check failed"
    exit 1
fi

# Test 3: Check slapd version
echo "Test 3: Checking OpenLDAP version..."
if docker exec "$CONTAINER_NAME" slapd -V 2>&1 | grep -q "slapd"; then
    VERSION=$(docker exec "$CONTAINER_NAME" slapd -V 2>&1 | head -1)
    echo "✅ Version check passed: $VERSION"
else
    echo "❌ Version check failed"
    exit 1
fi

# Test 4: Verify container health
echo "Test 4: Checking container health..."
HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "no-healthcheck")
if [ "$HEALTH_STATUS" = "healthy" ] || [ "$HEALTH_STATUS" = "no-healthcheck" ] || [ "$HEALTH_STATUS" = "starting" ]; then
    echo "✅ Container health check passed (status: $HEALTH_STATUS)"
else
    echo "⚠️  Container health status: $HEALTH_STATUS"
fi

echo ""
echo "=========================================="
echo "All OpenLDAP smoke tests passed! ✅"
echo "=========================================="
