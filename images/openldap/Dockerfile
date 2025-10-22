# Build stage - prepare runtime dependencies
FROM alpine:3.21 AS builder

ARG OPENLDAP_VERSION=2.6.10

# Install OpenLDAP and dependencies
RUN apk add --no-cache \
    openldap \
    openldap-back-mdb \
    openldap-clients \
    openldap-overlay-all \
    cyrus-sasl \
    cyrus-sasl-login \
    cyrus-sasl-digestmd5 \
    cyrus-sasl-crammd5

# Runtime stage - minimal image
FROM alpine:3.21

ARG OPENLDAP_VERSION=2.6.9

LABEL org.opencontainers.image.source="https://github.com/CloudPirates-io/container-images"
LABEL org.opencontainers.image.description="OpenLDAP - Open Source LDAP Directory Server"
LABEL org.opencontainers.image.version="${OPENLDAP_VERSION}"
LABEL org.opencontainers.image.licenses="OpenLDAP Public License"

# Install only runtime dependencies (no build tools or cache)
RUN apk add --no-cache \
    openldap \
    openldap-back-mdb \
    openldap-clients \
    openldap-overlay-all \
    cyrus-sasl \
    cyrus-sasl-login \
    cyrus-sasl-digestmd5 \
    cyrus-sasl-crammd5 \
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/* \
    && rm -rf /var/tmp/*

# Create necessary directories with proper permissions
RUN mkdir -p /var/lib/openldap /etc/openldap/slapd.d /run/openldap \
    && chown -R ldap:ldap /var/lib/openldap /etc/openldap/slapd.d /run/openldap

# Expose LDAP and LDAPS ports
EXPOSE 389 636

# Health check - verify LDAP is responding
# Check every 30s, timeout 5s, start checking after 10s, 3 retries before unhealthy
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ldapsearch -x -H ldap://localhost -b "" -s base "(objectclass=*)" namingContexts > /dev/null 2>&1 || exit 1

# Set default user
USER ldap

# Default command
CMD ["slapd", "-d", "256", "-h", "ldap:/// ldapi:/// ldaps:///"]
