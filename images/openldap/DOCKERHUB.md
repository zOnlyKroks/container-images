# OpenLDAP - Open Source LDAP Directory Server

Multi-architecture OpenLDAP container built from official source on Red Hat UBI9.

**GitHub Repository**: https://github.com/zOnlyKroks/container-images

## Quick Start

```bash
# Basic usage
docker run -d \
  -p 389:389 \
  -p 636:636 \
  -v ldap-data:/var/lib/ldap \
  -v ldap-config:/usr/local/openldap/etc/openldap/slapd.d \
  zonlykroks/openldap:latest

# With custom command
docker run -d \
  -p 389:389 \
  zonlykroks/openldap:latest \
  slapd -d 256 -h "ldap:///"
```

## Features

- Built from official OpenLDAP source (version 2.6.10 LTS)
- Multi-platform support: `linux/amd64`, `linux/arm64`
- Based on Red Hat UBI9 Micro (minimal attack surface)
- All common modules and overlays enabled
- TLS/SSL support with OpenSSL
- SASL authentication support
- Includes ODBC backend support
- No modifications to upstream source
- Trivy security scanning
- Cosign image signing

## Image Details

- **Base Image**: Red Hat UBI9 Micro
- **OpenLDAP Version**: 2.6.10 (LTS Release)
- **Registry**: Docker Hub (`zonlykroks/openldap`)
- **Alternate Registry**: GHCR (`ghcr.io/zonlykroks/container-images/openldap`)

## Ports

- `389` - LDAP (unencrypted)
- `636` - LDAPS (encrypted)

## Volumes

- `/var/lib/ldap` - Database files
- `/usr/local/openldap/etc/openldap/slapd.d` - Configuration directory

## Configuration

This is a minimal base image. You will need to:

1. Configure slapd via command-line options or mount your own configuration
2. Initialize your database schema
3. Set up TLS certificates (for LDAPS)
4. Configure access controls and authentication

Example with configuration file:

```bash
docker run -d \
  -p 389:389 \
  -v /path/to/slapd.conf:/usr/local/openldap/etc/openldap/slapd.conf:ro \
  -v ldap-data:/var/lib/ldap \
  zonlykroks/openldap:latest \
  slapd -f /usr/local/openldap/etc/openldap/slapd.conf -d 256
```

## Available Tools

The image includes all standard OpenLDAP utilities:

- `slapd` - Standalone LDAP daemon
- `ldapadd`, `ldapmodify`, `ldapdelete` - Directory modification tools
- `ldapsearch` - Directory search tool
- `slapcat`, `slapadd` - Database backup/restore utilities
- `slapindex`, `slaptest` - Maintenance utilities

## Health Check

Built-in health check verifies that the slapd binary is present and functional.

## Security

- Images scanned with Trivy for vulnerabilities
- Signed with Cosign for supply chain security
- Minimal runtime dependencies (UBI9 Micro base)
- Built from unmodified upstream source

### Image Verification

```bash
# Verify signature
cosign verify --key cosign.pub zonlykroks/openldap:latest
```

Public key available at: https://github.com/zOnlyKroks/container-images/blob/main/cosign.pub

## Tags

- `latest` - Latest stable version
- `2.6.10` - Specific version tag
- `2.6` - Minor version tag

## Source & Support

- **Source Code**: https://github.com/zOnlyKroks/container-images
- **OpenLDAP Upstream**: https://www.openldap.org/
- **Issues**: https://github.com/zOnlyKroks/container-images/issues
- **License**: OpenLDAP Public License

## Notes

- This image provides OpenLDAP binaries only - configuration management is left to the user
- Suitable as a base for custom LDAP deployments
- Not recommended for production use without proper configuration and hardening
- Consider using an orchestration tool (Kubernetes, Docker Compose) for production deployments

## Example Docker Compose

```yaml
services:
  openldap:
    image: zonlykroks/openldap:latest
    ports:
      - "389:389"
      - "636:636"
    volumes:
      - ldap-data:/var/lib/ldap
      - ldap-config:/usr/local/openldap/etc/openldap/slapd.d
    environment:
      - TZ=UTC
    restart: unless-stopped

volumes:
  ldap-data:
  ldap-config:
```
