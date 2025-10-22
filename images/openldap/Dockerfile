FROM registry.access.redhat.com/ubi9/ubi-minimal:latest

ARG OPENLDAP_VERSION=2.6.10

LABEL org.opencontainers.image.source="https://github.com/CloudPirates-io/container-images"
LABEL org.opencontainers.image.description="OpenLDAP - Open Source LDAP Directory Server"
LABEL org.opencontainers.image.version="${OPENLDAP_VERSION}"
LABEL org.opencontainers.image.licenses="OpenLDAP Public License"

# Install dependencies
RUN microdnf install -y \
    openldap \
    openldap-servers \
    openldap-clients \
    cyrus-sasl \
    cyrus-sasl-md5 \
    cyrus-sasl-plain \
    && microdnf clean all

# Create necessary directories
RUN mkdir -p /var/lib/ldap /etc/openldap/slapd.d /run/openldap \
    && chown -R ldap:ldap /var/lib/ldap /etc/openldap/slapd.d /run/openldap

# Expose LDAP and LDAPS ports
EXPOSE 389 636

# Set default user
USER ldap

# Default command
CMD ["slapd", "-d", "256", "-h", "ldap:/// ldapi:/// ldaps:///"]