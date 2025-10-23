ARG OPENLDAP_VERSION=2.6.10

# Build stage - download pre-built packages
FROM registry.access.redhat.com/ubi9/ubi:latest AS build

ARG TARGETARCH
ARG OPENLDAP_VERSION

WORKDIR /build

# Install OpenLDAP packages
RUN dnf install -y \
    openldap \
    openldap-servers \
    openldap-clients \
    && dnf clean all

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

# Copy OpenLDAP binaries and libraries from build stage
COPY --from=build /usr/sbin/slapd /usr/sbin/slapd
COPY --from=build /usr/bin/ldap* /usr/bin/
COPY --from=build /usr/lib64/libldap* /usr/lib64/
COPY --from=build /usr/lib64/liblber* /usr/lib64/
COPY --from=build /etc/openldap /etc/openldap

# Create simple entrypoint
RUN echo '#!/bin/sh' > /usr/bin/docker-entrypoint.sh && \
    echo 'exec "$@"' >> /usr/bin/docker-entrypoint.sh && \
    chmod +x /usr/bin/docker-entrypoint.sh

EXPOSE 389 636

VOLUME ["/var/lib/ldap", "/etc/openldap/slapd.d"]

# Health check - verify LDAP is responding
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD ["/usr/bin/ldapsearch", "-x", "-H", "ldap://localhost:389", "-b", "", "-s", "base"] || exit 1

ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]
CMD ["slapd", "-d", "256", "-h", "ldap:/// ldaps:///", "-u", "ldap", "-g", "ldap"]
