#!/bin/bash
# OpenLDAP Smoke Test
# This script performs basic validation that the OpenLDAP container is functional

set -euo pipefail

IMAGE_TAG="${1:-cloudpirates/openldap:test}"
CONTAINER_NAME="openldap-smoke-test-$$"

echo "Running smoke test for OpenLDAP image: $IMAGE_TAG"

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
}

trap cleanup EXIT

# Start OpenLDAP container
echo "Starting OpenLDAP container..."
docker run -d \
    --name "$CONTAINER_NAME" \
    -e LDAP_ORGANISATION="Test Organization" \
    -e LDAP_DOMAIN="example.com" \
    -e LDAP_ADMIN_PASSWORD="admin123" \
    -p 389:389 \
    -p 636:636 \
    "$IMAGE_TAG"

# Wait for OpenLDAP to be ready
echo "Waiting for OpenLDAP to start..."
RETRIES=30
until docker exec "$CONTAINER_NAME" ldapsearch -x -H ldap://localhost -b "dc=example,dc=com" -D "cn=admin,dc=example,dc=com" -w admin123 >/dev/null 2>&1; do
    RETRIES=$((RETRIES - 1))
    if [ $RETRIES -eq 0 ]; then
        echo "ERROR: OpenLDAP failed to start within expected time"
        docker logs "$CONTAINER_NAME"
        exit 1
    fi
    echo "Waiting... ($RETRIES attempts remaining)"
    sleep 2
done

echo "OpenLDAP is ready!"

# Test 1: Check if OpenLDAP is responding
echo "Test 1: Checking OpenLDAP connection..."
if docker exec "$CONTAINER_NAME" ldapsearch -x -H ldap://localhost -b "" -s base "(objectclass=*)" namingContexts >/dev/null 2>&1; then
    echo "✅ OpenLDAP connection check passed"
else
    echo "❌ OpenLDAP connection check failed"
    exit 1
fi

# Test 2: Verify admin bind
echo "Test 2: Testing admin authentication..."
if docker exec "$CONTAINER_NAME" ldapsearch -x -H ldap://localhost -b "dc=example,dc=com" -D "cn=admin,dc=example,dc=com" -w admin123 >/dev/null 2>&1; then
    echo "✅ Admin authentication passed"
else
    echo "❌ Admin authentication failed"
    exit 1
fi

# Test 3: Add a test entry
echo "Test 3: Adding test entry..."
docker exec "$CONTAINER_NAME" sh -c 'cat > /tmp/testuser.ldif <<EOF
dn: ou=users,dc=example,dc=com
objectClass: organizationalUnit
ou: users

dn: uid=testuser,ou=users,dc=example,dc=com
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: testuser
cn: Test User
sn: User
userPassword: testpass
uidNumber: 10001
gidNumber: 10001
homeDirectory: /home/testuser
loginShell: /bin/bash
EOF'

if docker exec "$CONTAINER_NAME" ldapadd -x -H ldap://localhost -D "cn=admin,dc=example,dc=com" -w admin123 -f /tmp/testuser.ldif >/dev/null 2>&1; then
    echo "✅ Test entry creation passed"
else
    echo "❌ Test entry creation failed"
    exit 1
fi

# Test 4: Search for the test entry
echo "Test 4: Searching for test entry..."
if docker exec "$CONTAINER_NAME" ldapsearch -x -H ldap://localhost -b "dc=example,dc=com" -D "cn=admin,dc=example,dc=com" -w admin123 "(uid=testuser)" | grep -q "uid=testuser"; then
    echo "✅ Test entry search passed"
else
    echo "❌ Test entry search failed"
    exit 1
fi

# Test 5: Verify user authentication
echo "Test 5: Testing user authentication..."
if docker exec "$CONTAINER_NAME" ldapwhoami -x -H ldap://localhost -D "uid=testuser,ou=users,dc=example,dc=com" -w testpass >/dev/null 2>&1; then
    echo "✅ User authentication passed"
else
    echo "❌ User authentication failed"
    exit 1
fi

# Test 6: Check slapd version
echo "Test 6: Checking OpenLDAP version..."
if docker exec "$CONTAINER_NAME" slapd -V 2>&1 | grep -q "slapd"; then
    VERSION=$(docker exec "$CONTAINER_NAME" slapd -V 2>&1 | head -1)
    echo "✅ Version check passed: $VERSION"
else
    echo "❌ Version check failed"
    exit 1
fi

echo ""
echo "=========================================="
echo "All OpenLDAP smoke tests passed! ✅"
echo "=========================================="
