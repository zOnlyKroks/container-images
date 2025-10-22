FROM alpine:3.21

ARG OPENLDAP_VERSION=2.6.10

LABEL org.opencontainers.image.source="https://github.com/CloudPirates-io/container-images"
LABEL org.opencontainers.image.description="OpenLDAP - Open Source LDAP Directory Server"
LABEL org.opencontainers.image.version="${OPENLDAP_VERSION}"
LABEL org.opencontainers.image.licenses="OpenLDAP Public License"

# Install OpenLDAP and dependencies
RUN apk add --no-cache \
    openldap \
    openldap-back-mdb \
    openldap-clients \
    openldap-overlay-all \
    cyrus-sasl \
    cyrus-sasl-plain \
    cyrus-sasl-digestmd5 \
    && rm -rf /var/cache/apk/*

# Create necessary directories
RUN mkdir -p /var/lib/openldap /etc/openldap/slapd.d /run/openldap \
    && chown -R ldap:ldap /var/lib/openldap /etc/openldap/slapd.d /run/openldap

# Expose LDAP and LDAPS ports
EXPOSE 389 636

# Set default user
USER ldap

# Default command
CMD ["slapd", "-d", "256", "-h", "ldap:/// ldapi:/// ldaps:///"]