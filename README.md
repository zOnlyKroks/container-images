# Container Images

Custom container images built and maintained by CloudPirates. These images are built from official sources with security scanning, signing, and provenance attestations.

## Available Images

### MinIO
High-Performance Object Storage compatible with Amazon S3.

- **Docker Hub:** `zonlykroks/minio`
- **GHCR:** `ghcr.io/zonlykroks/container-images/minio`
- **Base Image:** Red Hat UBI9 Micro
- **Platforms:** `linux/amd64`, `linux/arm64`

#### Quick Start

```bash
# Pull the image
docker pull zonlykroks/minio:latest

# Run MinIO (credentials REQUIRED)
docker run -p 9000:9000 -p 9001:9001 \
  -e MINIO_ROOT_USER=myadmin \
  -e MINIO_ROOT_PASSWORD=minio-secret-key-change-me \
  -v /data:/data \
  zonlykroks/minio:latest server /data --console-address ":9001"
```

**Important:** MinIO requires `MINIO_ROOT_USER` and `MINIO_ROOT_PASSWORD` to be set. The image has no default credentials for security.

Access the MinIO Console at: http://localhost:9001

## Features

- ✅ **Security Scanning:** All images scanned with Trivy
- ✅ **Image Signing:** Signed with Cosign (when enabled)
- ✅ **SBOM Generation:** Software Bill of Materials included
- ✅ **Multi-platform:** Support for amd64 and arm64
- ✅ **Health Checks:** Built-in container health checks

## Building Images

Images are built using GitHub Actions with a manual workflow trigger.

### Manual Build

Go to **Actions → Build and Publish Container Images → Run workflow**

Options:
- **Images:** Comma-separated list or `all`
- **Push to Docker Hub:** Enable/disable Docker Hub push
- **Push to GHCR:** Enable/disable GitHub Container Registry push
- **Sign Images:** Enable/disable Cosign signing
- **Run Security Scan:** Enable/disable Trivy scanning
- **Platforms:** Override target platforms (optional)
- **Tag Suffix:** Add suffix like `rc1` or `beta` (optional)

### Local Build

```bash
cd images/minio
docker build -t minio:local .
```

## Repository Structure

```
.
├── .github/workflows/        # GitHub Actions workflows
│   └── build-and-publish.yaml
├── images/                   # Image definitions
│   └── minio/
│       ├── Dockerfile
│       ├── config.yaml       # Image configuration
│       └── check-version.sh  # Version checking script
└── README.md
```

## Image Configuration

Each image has a `config.yaml` with:

```yaml
base_image: "registry.access.redhat.com/ubi9/ubi-micro:latest"
version: "RELEASE.2025-10-15T17-29-55Z"
description: "MinIO High-Performance Object Storage"
platforms: "linux/amd64,linux/arm64"
build_args:
  RELEASE: "RELEASE.2025-10-15T17-29-55Z"
```

## Security

### Credentials

**Never use default credentials in production.** All images require credentials to be explicitly set via:
- Environment variables
- Docker secrets
- Kubernetes secrets

### Image Verification

Images are signed with Cosign. Verify signatures:

```bash
# Verify Docker Hub image (requires cosign key)
cosign verify --key cosign.pub zonlykroks/minio:latest

# Verify GHCR image
cosign verify --key cosign.pub ghcr.io/cloudpirates/container-images/minio:latest
```

### Vulnerability Scanning

All images are scanned with Trivy during the build process. Check the **Security** tab in GitHub for results.

## Contributing

1. Create a new directory under `images/` with the image name
2. Add `Dockerfile` and `config.yaml`
3. Optionally add `check-version.sh` for automated version checking
4. Test locally
5. Submit a pull request

## License

See individual image directories for licensing information. MinIO is licensed under AGPL-3.0.

## Support

For issues or questions:
- Open an issue in this repository
