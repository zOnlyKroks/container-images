# Workflow Changes Summary

## Overview
The `build-and-publish.yaml` workflow has been converted to a **manual-only trigger** with enhanced configuration options for greater control over the release process.

## Key Changes

### 1. Manual Trigger Only
- **Removed**: Automatic triggers on push/PR to main branch
- **Now**: Only runs via manual `workflow_dispatch` trigger
- This prevents accidental automatic releases to registries

### 2. New Configuration Options

When manually triggering the workflow, you can now configure:

#### `images` (Required)
- **Description**: Images to build
- **Format**: Comma-separated list (e.g., `etcd,openldap`) or `all` for all images
- **Default**: `all`
- **Example**: `etcd` or `etcd,openldap`

#### `push_to_dockerhub` (Optional)
- **Description**: Enable/disable push to Docker Hub
- **Type**: Boolean (checkbox)
- **Default**: `true`
- Requires `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` secrets

#### `push_to_ghcr` (Optional)
- **Description**: Enable/disable push to GitHub Container Registry
- **Type**: Boolean (checkbox)
- **Default**: `true`
- Uses built-in `GITHUB_TOKEN` (always available)

#### `sign_images` (Optional)
- **Description**: Enable/disable image signing with Cosign
- **Type**: Boolean (checkbox)
- **Default**: `true`
- Requires `COSIGN_KEY` and `COSIGN_PASSWORD` secrets
- Signs only images pushed to enabled registries

#### `run_security_scan` (Optional)
- **Description**: Enable/disable Trivy vulnerability scanning
- **Type**: Boolean (checkbox)
- **Default**: `true`
- Requires GHCR push to be enabled (scans from GHCR)

#### `platforms` (Optional)
- **Description**: Override target platforms
- **Type**: String
- **Default**: Empty (uses `config.yaml` defaults)
- **Example**: `linux/amd64` or `linux/amd64,linux/arm64,linux/arm/v7`

#### `tag_suffix` (Optional)
- **Description**: Add a suffix to image tags
- **Type**: String
- **Default**: Empty
- **Example**: `rc1`, `beta`, `alpha`
- **Note**: When a suffix is provided, the `latest` tag is NOT created

## Usage Examples

### Example 1: Release All Images to Both Registries
```yaml
images: all
push_to_dockerhub: true
push_to_ghcr: true
sign_images: true
run_security_scan: true
platforms: (empty - uses config.yaml)
tag_suffix: (empty)
```

### Example 2: Release Specific Image with Custom Tag
```yaml
images: etcd
push_to_dockerhub: true
push_to_ghcr: true
sign_images: true
run_security_scan: true
platforms: (empty)
tag_suffix: rc1
```
This creates tags like `etcd:3.5.17-rc1` (no `latest` tag)

### Example 3: Build Only (No Push)
```yaml
images: openldap
push_to_dockerhub: false
push_to_ghcr: false
sign_images: false
run_security_scan: false
platforms: (empty)
tag_suffix: (empty)
```

### Example 4: GHCR Only with Custom Platforms
```yaml
images: etcd,openldap
push_to_dockerhub: false
push_to_ghcr: true
sign_images: true
run_security_scan: true
platforms: linux/amd64
tag_suffix: (empty)
```

### Example 5: Multi-Image Beta Release
```yaml
images: all
push_to_dockerhub: true
push_to_ghcr: true
sign_images: true
run_security_scan: true
platforms: (empty)
tag_suffix: beta
```

## How to Trigger Manually

### Via GitHub UI
1. Go to **Actions** tab in your repository
2. Select **Build and Publish Container Images** workflow
3. Click **Run workflow** button
4. Fill in the desired options
5. Click **Run workflow**

### Via GitHub CLI
```bash
gh workflow run build-and-publish.yaml \
  -f images="etcd,openldap" \
  -f push_to_dockerhub=true \
  -f push_to_ghcr=true \
  -f sign_images=true \
  -f run_security_scan=true \
  -f platforms="" \
  -f tag_suffix=""
```

## Security Considerations

1. **No Automatic Releases**: Prevents accidental pushes to production registries
2. **Selective Registry Push**: Choose which registries to push to
3. **Optional Signing**: Control when images are signed
4. **Credential Validation**: Workflow checks for required secrets and skips unavailable operations
5. **Security Scanning**: Optional vulnerability scanning with Trivy

## Job Summary Output

The workflow generates a comprehensive summary showing:
- ✅ Successful operations
- ⚠️  Skipped operations (missing credentials)
- ⏭️  Disabled operations (user choice)
- Build configuration (platforms, tag suffix)
- Pull commands for enabled registries

## Migration Notes

- **Old behavior**: Workflow ran automatically on every push to main
- **New behavior**: Workflow only runs when manually triggered
- **Breaking change**: You must now manually trigger releases
- **Benefit**: Full control over when and where images are published
