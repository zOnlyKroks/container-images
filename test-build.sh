#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print with color
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to display usage
usage() {
    cat <<EOF
Usage: $0 [OPTIONS] <image-name>

Test build container images locally

OPTIONS:
    -h, --help              Show this help message
    -p, --platform PLATFORM Build for specific platform (default: linux/amd64)
                           Examples: linux/amd64, linux/arm64, linux/amd64,linux/arm64
    -t, --tag TAG          Custom tag (default: test)
    --no-cache             Build without cache
    --push                 Push to registry after successful build
    --load                 Load image to docker (single platform only)
    --smoke-test           Run smoke test after successful build

EXAMPLES:
    # Build for current platform
    $0 minio

    # Build for specific platform
    $0 --platform linux/arm64 minio

    # Build for multiple platforms
    $0 --platform linux/amd64,linux/arm64 minio

    # Build without cache
    $0 --no-cache minio

    # Build and load to local docker
    $0 --load minio

    # Build and run smoke test
    $0 --smoke-test minio

EOF
    exit 0
}

# Default values - auto-detect platform based on architecture
DEFAULT_PLATFORM="linux/amd64"
if [ "$(uname -m)" = "arm64" ] || [ "$(uname -m)" = "aarch64" ]; then
    DEFAULT_PLATFORM="linux/arm64"
fi

PLATFORM="$DEFAULT_PLATFORM"
TAG="test"
NO_CACHE=""
PUSH=""
LOAD="--load"
RUN_SMOKE_TEST=false
IMAGE_NAME=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -p|--platform)
            PLATFORM="$2"
            shift 2
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        --push)
            PUSH="--push"
            LOAD=""
            shift
            ;;
        --load)
            LOAD="--load"
            shift
            ;;
        --smoke-test)
            RUN_SMOKE_TEST=true
            shift
            ;;
        -*)
            print_error "Unknown option: $1"
            usage
            ;;
        *)
            IMAGE_NAME="$1"
            shift
            ;;
    esac
done

# Validate image name
if [ -z "$IMAGE_NAME" ]; then
    print_error "Image name is required"
    usage
fi

IMAGE_DIR="images/$IMAGE_NAME"

if [ ! -d "$IMAGE_DIR" ]; then
    print_error "Image directory not found: $IMAGE_DIR"
    exit 1
fi

if [ ! -f "$IMAGE_DIR/config.yaml" ]; then
    print_error "Configuration file not found: $IMAGE_DIR/config.yaml"
    exit 1
fi

print_info "Testing build for: $IMAGE_NAME"
echo ""

# Check for required tools
print_info "Checking required tools..."

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed"
    exit 1
fi

# Detect if docker is actually podman
DOCKER_CMD="docker"
DOCKER_VERSION=$(docker --version 2>&1)
DOCKER_INFO=$(docker info 2>&1)
if echo "$DOCKER_VERSION" | grep -iq "podman" || echo "$DOCKER_INFO" | grep -iq "podman"; then
    print_warning "Detected Podman (via podman-machine or docker alias)"
    DOCKER_CMD="podman"
fi

if ! command -v yq &> /dev/null; then
    print_warning "yq is not installed. Install with: brew install yq (macOS) or see https://github.com/mikefarah/yq"
    print_info "Attempting to parse config.yaml without yq..."

    # Fallback parsing
    BASE_IMAGE=$(grep '^base_image:' "$IMAGE_DIR/config.yaml" | sed 's/base_image: *["'"'"']\?\([^"'"'"']*\)["'"'"']\?/\1/')
    VERSION=$(grep '^version:' "$IMAGE_DIR/config.yaml" | sed 's/version: *["'"'"']\?\([^"'"'"']*\)["'"'"']\?/\1/')
else
    # Parse config.yaml
    BASE_IMAGE=$(yq eval '.base_image' "$IMAGE_DIR/config.yaml")
    VERSION=$(yq eval '.version' "$IMAGE_DIR/config.yaml")
    DESCRIPTION=$(yq eval '.description // ""' "$IMAGE_DIR/config.yaml")
    CONFIG_PLATFORMS=$(yq eval '.platforms // "linux/amd64,linux/arm64"' "$IMAGE_DIR/config.yaml")

    print_info "Description: $DESCRIPTION"
    print_info "Configured platforms: $CONFIG_PLATFORMS"
fi

print_info "Base image: $BASE_IMAGE"
print_info "Version: $VERSION"
print_info "Build platform: $PLATFORM (auto-detected: $DEFAULT_PLATFORM)"
echo ""

# Check if buildx is available for multi-platform builds
if [[ "$PLATFORM" == *","* ]]; then
    if ! docker buildx version &> /dev/null; then
        print_error "Docker Buildx is required for multi-platform builds"
        exit 1
    fi
    LOAD=""  # Cannot use --load with multiple platforms
    print_warning "Multi-platform build: --load disabled (use --push to push to registry)"
fi

# Determine Dockerfile
if [ -f "$IMAGE_DIR/Dockerfile" ]; then
    DOCKERFILE="$IMAGE_DIR/Dockerfile"
    print_info "Using custom Dockerfile: $DOCKERFILE"
else
    print_info "Generating Dockerfile..."
    DOCKERFILE="$IMAGE_DIR/Dockerfile.generated"

    cat > "$DOCKERFILE" <<EOF
FROM $BASE_IMAGE

LABEL org.opencontainers.image.source="https://github.com/CloudPirates-io/container-images"
LABEL org.opencontainers.image.description="Test build"
LABEL org.opencontainers.image.version="$VERSION"
LABEL org.opencontainers.image.vendor="CloudPirates"
LABEL org.opencontainers.image.licenses="Apache-2.0"

EOF

    # Add setup script if exists
    if [ -f "$IMAGE_DIR/setup.sh" ]; then
        print_info "Found setup.sh - adding to Dockerfile"
        cat >> "$DOCKERFILE" <<EOF
COPY setup.sh /tmp/setup.sh
RUN chmod +x /tmp/setup.sh && /tmp/setup.sh && rm /tmp/setup.sh
EOF
    fi

    print_success "Generated Dockerfile"
fi

echo ""

# Build image
IMAGE_TAG="cloudpirates/$IMAGE_NAME:$TAG"
print_info "Building image: $IMAGE_TAG"
print_info "Platform: $PLATFORM"

BUILD_CMD="docker buildx build \
    --platform $PLATFORM \
    --file $DOCKERFILE \
    --tag $IMAGE_TAG \
    $NO_CACHE \
    $LOAD \
    $PUSH \
    $IMAGE_DIR"

print_info "Build command:"
echo "$BUILD_CMD"
echo ""

# Execute build
if eval "$BUILD_CMD"; then
    print_success "Build completed successfully!"
    echo ""

    if [ -n "$LOAD" ]; then
        print_info "Image loaded locally:"
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedAt}}\t{{.Size}}" | head -1
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedAt}}\t{{.Size}}" | grep "$IMAGE_NAME" | grep "$TAG"
        echo ""

        # Get the actual engine being used
        ENGINE_NAME="Docker"
        if [ "$DOCKER_CMD" = "podman" ]; then
            ENGINE_NAME="Podman"
        fi

        print_info "You can run the image with:"
        echo "  docker run --rm -it $IMAGE_TAG"
        echo ""

        print_info "To test the image:"
        echo "  docker run --rm $IMAGE_TAG --version"
        echo ""

        print_info "To inspect the image:"
        echo "  docker inspect $IMAGE_TAG"
        echo ""

        print_info "To remove the image:"
        echo "  docker rmi $IMAGE_TAG"
        echo ""

        if [ "$DOCKER_CMD" = "podman" ]; then
            print_warning "Note: You're using Podman. Images are stored in Podman's local storage."
            print_info "To list Podman images directly:"
            echo "  podman images"
        fi
    elif [ -n "$PUSH" ]; then
        print_success "Image pushed to registry"
    else
        print_info "Image built but not loaded (multi-platform build)"
        print_info "Use --push to push to registry or build single platform with --load"
    fi
else
    print_error "Build failed!"
    exit 1
fi

# Cleanup generated Dockerfile
if [ "$DOCKERFILE" = "$IMAGE_DIR/Dockerfile.generated" ]; then
    rm -f "$DOCKERFILE"
    print_info "Cleaned up generated Dockerfile"
fi

# Run smoke test if requested
if [ "$RUN_SMOKE_TEST" = true ]; then
    echo ""
    print_info "Running smoke test..."

    SMOKE_TEST_SCRIPT="$IMAGE_DIR/smoke-test.sh"

    if [ ! -f "$SMOKE_TEST_SCRIPT" ]; then
        print_warning "No smoke test found for $IMAGE_NAME (expected: $SMOKE_TEST_SCRIPT)"
        print_info "Skipping smoke test"
    else
        if [ -z "$LOAD" ]; then
            print_warning "Cannot run smoke test: image not loaded locally (multi-platform or --push used)"
            print_info "Use single platform with --load to run smoke tests"
        else
            chmod +x "$SMOKE_TEST_SCRIPT"
            if bash "$SMOKE_TEST_SCRIPT" "$IMAGE_TAG"; then
                print_success "Smoke test passed!"
            else
                print_error "Smoke test failed!"
                exit 1
            fi
        fi
    fi
fi

print_success "Test build complete!"
