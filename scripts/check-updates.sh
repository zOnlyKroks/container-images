#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "🔍 Checking for dependency updates..."
echo ""

# Check each image directory
for image_dir in images/*/; do
    IMAGE_NAME=$(basename "$image_dir")
    CONFIG_FILE="${image_dir}config.yaml"

    if [ ! -f "$CONFIG_FILE" ]; then
        continue
    fi

    print_info "Checking $IMAGE_NAME..."

    CURRENT_VERSION=$(yq eval '.version' "$CONFIG_FILE" 2>/dev/null || echo "unknown")

    case "$IMAGE_NAME" in
        minio)
            # Check MinIO latest release
            print_info "  Current: $CURRENT_VERSION"

            LATEST_VERSION=$(curl -sI https://dl.min.io/server/minio/release/linux-amd64/minio 2>/dev/null | \
                grep -i "x-amz-meta-release-name" | \
                cut -d: -f2 | \
                tr -d ' \r\n' || echo "unknown")

            if [ "$LATEST_VERSION" = "unknown" ]; then
                # Fallback to GitHub API
                LATEST_VERSION=$(curl -s https://api.github.com/repos/minio/minio/releases/latest | \
                    jq -r '.tag_name' || echo "unknown")
            fi

            print_info "  Latest:  $LATEST_VERSION"

            if [ "$CURRENT_VERSION" != "$LATEST_VERSION" ] && [ "$LATEST_VERSION" != "unknown" ]; then
                print_warning "  ⚠️  Update available!"
                echo ""
                echo "  To update, run:"
                echo "    yq eval '.version = \"$LATEST_VERSION\"' -i $CONFIG_FILE"
                echo "    yq eval '.build_args.RELEASE = \"$LATEST_VERSION\"' -i $CONFIG_FILE"
                echo "    sed -i '' 's/^ARG RELEASE=.*/ARG RELEASE=$LATEST_VERSION/' images/minio/Dockerfile"
            else
                print_success "  ✓ Up to date"
            fi
            ;;
        *)
            print_info "  Version: $CURRENT_VERSION"
            print_info "  Automatic update check not configured for this image"
            ;;
    esac

    echo ""
done

print_info "Checking base images..."

# Check for updated base images in Dockerfiles
for dockerfile in images/*/Dockerfile; do
    # Skip if glob didn't match any files
    if [ ! -f "$dockerfile" ]; then
        continue
    fi

    IMAGE_NAME=$(basename $(dirname "$dockerfile"))

    # Extract base image
    BASE_IMAGE=$(grep "^FROM" "$dockerfile" | head -1 | awk '{print $2}')

    if [ -n "$BASE_IMAGE" ]; then
        print_info "  $IMAGE_NAME: $BASE_IMAGE"

        # Check if newer version exists (basic check)
        IMAGE_REPO=$(echo "$BASE_IMAGE" | cut -d: -f1)
        IMAGE_TAG=$(echo "$BASE_IMAGE" | cut -d: -f2)

        # For common patterns like golang:1.23-alpine, suggest checking
        if [[ "$IMAGE_TAG" =~ ^[0-9]+\.[0-9]+-alpine$ ]]; then
            print_info "    💡 Check https://hub.docker.com/_/$IMAGE_REPO for newer versions"
        fi
    fi
done

echo ""
print_success "Dependency check complete!"
