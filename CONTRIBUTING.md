# Contributing to CloudPirates Container Images

## Directory Structure

Each container image lives in its own directory under `images/`:

```
images/
├── my-app/
│   ├── config.yaml          # Required: Image configuration
│   ├── Dockerfile           # Optional: Custom Dockerfile
│   ├── setup.sh            # Optional: Setup script for auto-generated Dockerfile
│   └── patches/            # Optional: Patches to apply
│       └── *.patch
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
FROM ubuntu:22.04

LABEL org.opencontainers.image.source="https://github.com/CloudPirates-io/container-images"
LABEL org.opencontainers.image.description="My app"
LABEL org.opencontainers.image.version="1.0.0"

RUN apt-get update && \
    apt-get install -y myapp && \
    apt-get clean

EXPOSE 8080
CMD ["myapp"]
```

## Applying Patches

Place `.patch` files in `images/my-app/patches/`:

```bash
# Create a patch
diff -Naur /original/file /modified/file > images/my-app/patches/001-fix-config.patch
```

Patches are applied automatically during build.

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

The repository uses two systems for dependency updates:

1. **GitHub Actions Workflow** (`.github/workflows/update-dependencies.yaml`)
   - Runs daily at 6 AM UTC
   - Checks for new MinIO releases
   - Creates PRs automatically

2. **Renovate Bot** (`renovate.json`)
   - Monitors Dockerfile base images
   - Updates GitHub Actions versions
   - Auto-merges minor/patch updates

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

## Pull Request Process

1. Create feature branch
2. Add/modify image in `images/` directory
3. Update `version` in `config.yaml`
4. Test locally with `./test-build.sh <image-name>`
5. Submit PR - CI will build and validate
6. On merge to main: automatic publish and signing
