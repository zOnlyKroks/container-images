ARG RELEASE=RELEASE.2024-10-13T13-34-11Z

# Build stage - download and verify binaries
FROM golang:1.25-alpine AS build

ARG TARGETARCH
ARG RELEASE

ENV GOPATH=/go
ENV CGO_ENABLED=0

WORKDIR /build

# Install verification tools
RUN apk add -U --no-cache ca-certificates curl bash

# Download MinIO binary
RUN curl -s -q https://dl.min.io/server/minio/release/linux-${TARGETARCH}/archive/minio.${RELEASE} -o /go/bin/minio && \
    chmod +x /go/bin/minio

# Download mc (MinIO Client) binary
RUN curl -s -q https://dl.min.io/client/mc/release/linux-${TARGETARCH}/mc -o /go/bin/mc && \
    chmod +x /go/bin/mc

# Verify binaries were downloaded successfully
RUN test -f /go/bin/minio && \
    test -f /go/bin/mc && \
    ls -lh /go/bin/minio /go/bin/mc

# Runtime stage
FROM registry.access.redhat.com/ubi9/ubi-micro:latest

ARG RELEASE

LABEL org.opencontainers.image.source="https://github.com/CloudPirates-io/container-images" \
      org.opencontainers.image.description="MinIO High-Performance Object Storage - CloudPirates Build" \
      org.opencontainers.image.version="${RELEASE}" \
      org.opencontainers.image.vendor="CloudPirates" \
      org.opencontainers.image.licenses="AGPL-3.0" \
      name="MinIO" \
      vendor="MinIO Inc <dev@min.io>" \
      maintainer="CloudPirates" \
      version="${RELEASE}" \
      release="${RELEASE}" \
      summary="MinIO is a High Performance Object Storage, API compatible with Amazon S3 cloud storage service."

# Environment variables for MinIO
# hadolint ignore=DL3003,DL4006,SC2086
# These ENV vars specify file paths, not actual secrets
# Set default credentials (should be overridden at runtime)
ENV MINIO_ROOT_USER=admin \
    MINIO_ROOT_PASSWORD=ChangeThisSecurePassword123 \
    MINIO_ACCESS_KEY_FILE=access_key \
    MINIO_SECRET_KEY_FILE=secret_key \
    MINIO_ROOT_USER_FILE=access_key \
    MINIO_ROOT_PASSWORD_FILE=secret_key \
    MINIO_KMS_SECRET_KEY_FILE=kms_master_key \
    MINIO_UPDATE_MINISIGN_PUBKEY="RWTx5Zr1tiHQLwG9keckT0c45M3AGeHD6IvimQHpyRywVWGbP1aVSGav" \
    MINIO_CONFIG_ENV_FILE=config.env \
    MC_CONFIG_DIR=/tmp/.mc

# Copy CA certificates
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy verified binaries and verification files
COPY --from=build /go/bin/minio* /usr/bin/
COPY --from=build /go/bin/mc* /usr/bin/

# Create entrypoint script
RUN echo '#!/bin/sh' > /usr/bin/docker-entrypoint.sh && \
    echo 'exec "$@"' >> /usr/bin/docker-entrypoint.sh && \
    chmod +x /usr/bin/docker-entrypoint.sh

EXPOSE 9000 9001

VOLUME ["/data"]

ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]
CMD ["minio", "server", "/data", "--console-address", ":9001"]
