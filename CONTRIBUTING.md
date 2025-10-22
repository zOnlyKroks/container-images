# Contributing to CloudPirates Container Images

## Directory Structure

Each container image lives in its own directory under `images/`:

```
images/
├── my-app/
│   ├── config.yaml          # Required: Image configuration
│   ├── Dockerfile           # Optional: Custom Dockerfile
│   ├── setup.sh            # Optional: Setup script for auto-generated Dockerfile
```

## Configuration File (config.yaml)

Every image **must** have a `config.yaml`:

```yaml
# Required: Base image to build from
base_image: "alpine:3.19"

# Required: Version of your image
version: "1.0.0"

# Optional: Description
description: "My application container"

# Optional: Target platforms (default: linux/amd64,linux/arm64)
platforms: "linux/amd64,linux/arm64"

# Optional: Build arguments
build_args:
  APP_VERSION: "1.0.0"
```

## Build Methods

### Method 1: Auto-Generated Dockerfile with setup.sh

The simplest approach. Create `config.yaml` and optionally `setup.sh`:

**setup.sh:**
```bash
#!/bin/bash
set -euo pipefail

apt-get update
apt-get install -y myapp
apt-get clean
rm -rf /var/lib/apt/lists/*
```

The workflow will generate a Dockerfile that:
1. Uses your `base_image`
2. Applies any patches
3. Runs your `setup.sh`

### Method 2: Custom Dockerfile

For complex builds, create your own `Dockerfile`:

```dockerfile
# Build stage (optional) - for multi-stage builds
FROM ubuntu:22.04 AS builder

# Build dependencies here
RUN apt-get update && apt-get install -y build-essential

# Runtime stage
FROM ubuntu:22.04

LABEL org.opencontainers.image.source="https://github.com/CloudPirates-io/container-images"
LABEL org.opencontainers.image.description="My app"
LABEL org.opencontainers.image.version="1.0.0"

# Install only runtime dependencies
RUN apt-get update && \
    apt-get install -y myapp && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

EXPOSE 8080

# Add health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

CMD ["myapp"]
```

## Best Practices

### Multi-Stage Builds

Use multi-stage builds to reduce image size:

```dockerfile
# Build stage - contains build tools
FROM alpine:3.21 AS builder
RUN apk add --no-cache build-tools
# ... build steps

# Runtime stage - minimal dependencies
FROM alpine:3.21
COPY --from=builder /app/binary /usr/bin/
# Only install runtime deps, not build tools
```

**Benefits:**
- Smaller final image (no build tools)
- Faster deployments
- Reduced attack surface
- Better layer caching

### Health Checks

Always add HEALTHCHECK to Dockerfiles for production use:

```dockerfile
# For HTTP services
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# For database services
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD pg_isready -U postgres || exit 1

# For LDAP services
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ldapsearch -x -H ldap://localhost -b "" -s base || exit 1
```

**Health Check Parameters:**
- `--interval`: How often to check (default: 30s)
- `--timeout`: Max time for check to complete (default: 30s)
- `--start-period`: Grace period before checks start (default: 0s)
- `--retries`: Consecutive failures before unhealthy (default: 3)

**Benefits:**
- Container orchestrators (Docker Compose, Kubernetes) use health checks
- Automatic restart of unhealthy containers
- Better rolling updates and zero-downtime deployments
- Monitoring and alerting integration

## Versioning

Follow [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking changes
- **MINOR**: New features (backwards compatible)
- **PATCH**: Bug fixes

Update the `version` field in `config.yaml`.

## CI/CD Pipeline

The GitHub Actions workflow automatically:

1. **Detects Changes**: Identifies modified images
2. **Builds**: Multi-platform build (amd64, arm64)
3. **Publishes**: Pushes to Docker Hub and GHCR
4. **Signs**: Uses Cosign to sign images
5. **Tags**: Creates both versioned and `latest` tags

### Triggers

- **Push to main**: Builds and publishes changed images
- **Pull Request**: Builds for testing (no publish)
- **Manual**: `workflow_dispatch` to build specific image

## Testing Locally

### Quick Test Build

```bash
# Build for your platform (auto-detected: arm64 on Apple Silicon, amd64 on Intel)
./test-build.sh minio

# Build for specific platform
./test-build.sh --platform linux/amd64 minio

# Build for multiple platforms (requires buildx)
./test-build.sh --platform linux/amd64,linux/arm64 minio

# Build and run smoke test
./test-build.sh --smoke-test minio
```

### Running Smoke Tests

Smoke tests validate that the container is functional after building:

```bash
# Run smoke test for specific image
./run-smoke-tests.sh minio

# Run smoke tests for all images
./run-smoke-tests.sh --all

# Test specific tag
./run-smoke-tests.sh --tag latest minio
```

### Manual Build

```bash
cd images/my-app

# Build
docker build -t my-app:test .

# Test
docker run --rm my-app:test

# Multi-platform build (requires buildx)
docker buildx build --platform linux/amd64,linux/arm64 -t my-app:test .
```

### Running Images

Example for MinIO:
```bash
# Run with proper credentials
docker run --rm -p 9000:9000 -p 9001:9001 \
  -e MINIO_ROOT_USER=admin \
  -e MINIO_ROOT_PASSWORD=SecurePassword123 \
  cloudpirates/minio:test server /data --console-address ":9001"

# Access the console at http://localhost:9001
```

## Automated Dependency Updates

### Checking for Updates

Run the update checker script:
```bash
./scripts/check-updates.sh
```

This will check all images for newer versions and provide update commands.

### Automated Updates

The repository uses automated version checking:

**Version Check Workflow** (`.github/workflows/check-versions.yaml`)
- Runs weekly (Monday at 6 AM UTC)
- **Automatically discovers** all images with `check-version.sh`
- Checks for new releases and creates PRs automatically
- No manual configuration needed - just add your `check-version.sh` file!

### Manual Updates

To update an image version:
```bash
# Update MinIO example
yq eval '.version = "RELEASE.2025-01-15T12-00-00Z"' -i images/minio/config.yaml
yq eval '.build_args.RELEASE = "RELEASE.2025-01-15T12-00-00Z"' -i images/minio/config.yaml
sed -i '' 's/^ARG RELEASE=.*/ARG RELEASE=RELEASE.2025-01-15T12-00-00Z/' images/minio/Dockerfile
```

## Platform Configuration

The `config.yaml` supports platform specification:

```yaml
# Single platform (faster for local development)
platforms: "linux/arm64"

# Multi-platform (for production)
platforms: "linux/amd64,linux/arm64"
```

The `test-build.sh` script auto-detects your platform:
- Apple Silicon (M1/M2/M3): `linux/arm64`
- Intel/AMD: `linux/amd64`

Override with: `./test-build.sh --platform linux/amd64 minio`

## Creating Smoke Tests

Each image should have a `smoke-test.sh` script that validates basic functionality:

**smoke-test.sh:**
```bash
#!/bin/bash
set -euo pipefail

IMAGE_TAG="${1:-cloudpirates/myapp:test}"
CONTAINER_NAME="myapp-smoke-test-$$"

echo "Running smoke test for: $IMAGE_TAG"

# Cleanup function
cleanup() {
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
}
trap cleanup EXIT

# Start container
docker run -d --name "$CONTAINER_NAME" "$IMAGE_TAG"

# Wait for service to be ready
# Add your health check here

# Run tests
echo "Test 1: Basic functionality..."
if docker exec "$CONTAINER_NAME" your-test-command; then
    echo "✅ Test passed"
else
    echo "❌ Test failed"
    exit 1
fi

echo "All smoke tests passed! ✅"
```

Smoke tests run automatically in CI/CD and can be run locally with `./run-smoke-tests.sh`.

## Security & Supply Chain

The CI/CD pipeline automatically:

1. **Generates SBOM** - Software Bill of Materials for dependency tracking
2. **Creates Provenance** - Build attestations for supply chain security
3. **Scans Vulnerabilities** - Trivy scans for CRITICAL and HIGH severity issues
4. **Uploads to Security Tab** - Results visible in GitHub Security dashboard

## Pull Request Process

1. Create feature branch
2. Add/modify image in `images/` directory
3. Update `version` in `config.yaml`
4. Create or update `smoke-test.sh` for your image
5. Test locally with `./test-build.sh --smoke-test <image-name>`
6. Submit PR - CI will build, scan, and validate
7. On merge to main: automatic publish and signing
