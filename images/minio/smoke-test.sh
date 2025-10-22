#!/bin/bash
# MinIO Smoke Test
# This script performs basic validation that the MinIO container is functional

set -euo pipefail

IMAGE_TAG="${1:-cloudpirates/minio:test}"
CONTAINER_NAME="minio-smoke-test-$$"

echo "Running smoke test for MinIO image: $IMAGE_TAG"

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
}

trap cleanup EXIT

# Start MinIO container
echo "Starting MinIO container..."
docker run -d \
    --name "$CONTAINER_NAME" \
    -e MINIO_ROOT_USER=minioadmin \
    -e MINIO_ROOT_PASSWORD=minioadmin123 \
    -p 9000:9000 \
    -p 9001:9001 \
    "$IMAGE_TAG"

# Wait for MinIO to be ready
echo "Waiting for MinIO to start..."
RETRIES=30
until docker exec "$CONTAINER_NAME" mc alias set local http://localhost:9000 minioadmin minioadmin123 2>/dev/null; do
    RETRIES=$((RETRIES - 1))
    if [ $RETRIES -eq 0 ]; then
        echo "ERROR: MinIO failed to start within expected time"
        docker logs "$CONTAINER_NAME"
        exit 1
    fi
    echo "Waiting... ($RETRIES attempts remaining)"
    sleep 2
done

echo "MinIO is ready!"

# Test 1: Check if MinIO is responding
echo "Test 1: Checking MinIO health..."
if docker exec "$CONTAINER_NAME" mc admin info local >/dev/null 2>&1; then
    echo "✅ MinIO health check passed"
else
    echo "❌ MinIO health check failed"
    exit 1
fi

# Test 2: Create a bucket
echo "Test 2: Creating test bucket..."
if docker exec "$CONTAINER_NAME" mc mb local/test-bucket >/dev/null 2>&1; then
    echo "✅ Bucket creation passed"
else
    echo "❌ Bucket creation failed"
    exit 1
fi

# Test 3: Upload a test file
echo "Test 3: Testing file upload..."
docker exec "$CONTAINER_NAME" sh -c 'echo "test content" > /tmp/testfile.txt'
if docker exec "$CONTAINER_NAME" mc cp /tmp/testfile.txt local/test-bucket/testfile.txt >/dev/null 2>&1; then
    echo "✅ File upload passed"
else
    echo "❌ File upload failed"
    exit 1
fi

# Test 4: Download the test file
echo "Test 4: Testing file download..."
if docker exec "$CONTAINER_NAME" mc cp local/test-bucket/testfile.txt /tmp/downloaded.txt >/dev/null 2>&1; then
    CONTENT=$(docker exec "$CONTAINER_NAME" cat /tmp/downloaded.txt)
    if [ "$CONTENT" = "test content" ]; then
        echo "✅ File download passed"
    else
        echo "❌ File download failed - content mismatch"
        exit 1
    fi
else
    echo "❌ File download failed"
    exit 1
fi

# Test 5: List buckets
echo "Test 5: Testing bucket listing..."
if docker exec "$CONTAINER_NAME" mc ls local | grep -q "test-bucket"; then
    echo "✅ Bucket listing passed"
else
    echo "❌ Bucket listing failed"
    exit 1
fi

echo ""
echo "=========================================="
echo "All MinIO smoke tests passed! ✅"
echo "=========================================="
