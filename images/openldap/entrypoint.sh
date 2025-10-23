#!/bin/sh
set -e

log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1"
}

DATA_DIR="${LDAP_DATA_DIR:-/var/lib/ldap}"
CONFIG_DIR="${LDAP_CONFIG_DIR:-/usr/local/openldap/etc/openldap/slapd.d}"

if [ ! -d "${DATA_DIR}" ]; then
    log_error "Data directory ${DATA_DIR} does not exist"
    exit 1
fi

log_info "Starting OpenLDAP as $(id -u):$(id -g)"

exec "$@"
