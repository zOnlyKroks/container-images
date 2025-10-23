ARG RELEASE=RELEASE.2025-10-15T17-29-55Z

# Build stage - download and verify binaries
FROM golang:1.23-alpine AS build

ARG TARGETARCH
ARG RELEASE

ENV GOPATH=/go
ENV CGO_ENABLED=0

WORKDIR /build

# Install build tools
RUN apk add -U --no-cache ca-certificates curl bash

# Download MinIO binary from official source
RUN curl -s -q https://dl.min.io/server/minio/release/linux-${TARGETARCH}/archive/minio.${RELEASE} -o /go/bin/minio && \
    chmod +x /go/bin/minio

# Download mc (MinIO Client) binary from official source
RUN curl -s -q https://dl.min.io/client/mc/release/linux-${TARGETARCH}/mc -o /go/bin/mc && \
    chmod +x /go/bin/mc

# Final verification that binaries exist and are executable
RUN test -x /go/bin/minio && \
    test -x /go/bin/mc && \
    echo "Binary verification complete:" && \
    ls -lh /go/bin/minio /go/bin/mc

# Runtime stage
FROM registry.access.redhat.com/ubi9/ubi-micro:latest

ARG RELEASE

LABEL org.opencontainers.image.source="https://github.com/zOnlyKroks/container-images" \
      org.opencontainers.image.description="MinIO High-Performance Object Storage - zOnlyKroks Build" \
      org.opencontainers.image.version="${RELEASE}" \
      org.opencontainers.image.vendor="zOnlyKroks" \
      org.opencontainers.image.licenses="AGPL-3.0" \
      name="MinIO" \
      vendor="MinIO Inc <dev@min.io>" \
      maintainer="zOnlyKroks" \
      version="${RELEASE}" \
      release="${RELEASE}" \
      summary="MinIO is a High Performance Object Storage, API compatible with Amazon S3 cloud storage service."

# Environment variables for MinIO
# hadolint ignore=DL3003,DL4006,SC2086
# IMPORTANT: MINIO_ROOT_USER and MINIO_ROOT_PASSWORD must be set at runtime
# MinIO will not start without credentials. Set them via:
#   docker run -e MINIO_ROOT_USER=myadmin -e MINIO_ROOT_PASSWORD=mysecretpassword ...
# Or use Docker secrets/Kubernetes secrets in production

# File-based credential paths (for Docker/Kubernetes secrets)
ENV MINIO_ACCESS_KEY_FILE=access_key \
    MINIO_SECRET_KEY_FILE=secret_key \
    MINIO_ROOT_USER_FILE=access_key \
    MINIO_ROOT_PASSWORD_FILE=secret_key \
    MINIO_KMS_SECRET_KEY_FILE=kms_master_key \
    MINIO_UPDATE_MINISIGN_PUBKEY="RWTx5Zr1tiHQLwG9keckT0c45M3AGeHD6IvimQHpyRywVWGbP1aVSGav" \
    MINIO_CONFIG_ENV_FILE=config.env \
    MC_CONFIG_DIR=/tmp/.mc

# Copy CA certificates
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy verified binaries (explicit names to avoid wildcards)
COPY --from=build /go/bin/minio /usr/bin/minio
COPY --from=build /go/bin/mc /usr/bin/mc

# Ensure binaries are executable
RUN chmod +x /usr/bin/minio /usr/bin/mc

# Create entrypoint script
RUN echo '#!/bin/sh' > /usr/bin/docker-entrypoint.sh && \
    echo 'exec "$@"' >> /usr/bin/docker-entrypoint.sh && \
    chmod +x /usr/bin/docker-entrypoint.sh

EXPOSE 9000 9001

VOLUME ["/data"]

# Health check - verify MinIO is responding
# Check every 30s, timeout 10s, start checking after 5s, 3 retries before unhealthy
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD ["/usr/bin/mc", "ready", "local", "--quiet"] || exit 1

ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]
CMD ["minio", "server", "/data", "--console-address", ":9001"]
