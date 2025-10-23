ARG OPENLDAP_VERSION=2.6.10

# Build stage - compile OpenLDAP from source
FROM registry.access.redhat.com/ubi9/ubi:latest AS build

ARG TARGETARCH
ARG OPENLDAP_VERSION

WORKDIR /tmp/build

# Install build dependencies
RUN dnf install -y \
    gcc \
    make \
    openssl-devel \
    cyrus-sasl-devel \
    libevent-devel \
    tar \
    gzip \
    wget \
    && dnf clean all

# Download OpenLDAP source
RUN wget -q "https://www.openldap.org/software/download/OpenLDAP/openldap-release/openldap-${OPENLDAP_VERSION}.tgz" && \
    tar -xzf openldap-${OPENLDAP_VERSION}.tgz && \
    rm openldap-${OPENLDAP_VERSION}.tgz

WORKDIR /tmp/build/openldap-${OPENLDAP_VERSION}

# Configure and compile OpenLDAP
RUN ./configure \
    --prefix=/usr/local/openldap \
    --enable-slapd \
    --enable-modules \
    --enable-backends=mod \
    --enable-overlays=mod \
    --with-cyrus-sasl \
    --with-tls=openssl \
    && make -j$(nproc) \
    && make install

# Runtime stage
FROM registry.access.redhat.com/ubi9/ubi-micro:latest

ARG OPENLDAP_VERSION

LABEL org.opencontainers.image.source="https://github.com/zOnlyKroks/container-images" \
      org.opencontainers.image.description="OpenLDAP - Open Source LDAP Directory Server" \
      org.opencontainers.image.version="${OPENLDAP_VERSION}" \
      org.opencontainers.image.vendor="zOnlyKroks" \
      org.opencontainers.image.licenses="OpenLDAP Public License" \
      name="OpenLDAP" \
      vendor="OpenLDAP Foundation" \
      maintainer="zOnlyKroks" \
      version="${OPENLDAP_VERSION}" \
      release="${OPENLDAP_VERSION}" \
      summary="OpenLDAP is an open source LDAP directory server"

# Install runtime dependencies
COPY --from=build /usr/lib64/libsasl2.so* /usr/lib64/
COPY --from=build /usr/lib64/libssl.so* /usr/lib64/
COPY --from=build /usr/lib64/libcrypto.so* /usr/lib64/
COPY --from=build /usr/lib64/libevent* /usr/lib64/

# Copy compiled OpenLDAP
COPY --from=build /usr/local/openldap /usr/local/openldap

# Add to PATH
ENV PATH="/usr/local/openldap/bin:/usr/local/openldap/sbin:${PATH}"

# Create simple entrypoint
RUN echo '#!/bin/sh' > /usr/bin/docker-entrypoint.sh && \
    echo 'exec "$@"' >> /usr/bin/docker-entrypoint.sh && \
    chmod +x /usr/bin/docker-entrypoint.sh

EXPOSE 389 636

VOLUME ["/var/lib/ldap", "/usr/local/openldap/etc/openldap/slapd.d"]

# Health check - verify slapd binary exists and is executable
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD ["/usr/local/openldap/libexec/slapd", "-VV"] || exit 1

ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]
CMD ["slapd", "-d", "256", "-h", "ldap:/// ldaps:///"]
