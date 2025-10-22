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

Run smoke tests for container images

OPTIONS:
    -h, --help              Show this help message
    -t, --tag TAG          Image tag to test (default: test)
    --all                  Run smoke tests for all images

EXAMPLES:
    # Run smoke test for specific image
    $0 minio

    # Run smoke test with custom tag
    $0 --tag latest minio

    # Run smoke tests for all images
    $0 --all

EOF
    exit 0
}

# Run smoke test for a single image
run_smoke_test() {
    local image_name=$1
    local tag=$2
    local image_dir="images/$image_name"
    local smoke_test="$image_dir/smoke-test.sh"

    print_info "Running smoke test for: $image_name"

    if [ ! -d "$image_dir" ]; then
        print_error "Image directory not found: $image_dir"
        return 1
    fi

    if [ ! -f "$smoke_test" ]; then
        print_warning "No smoke test found for $image_name (expected: $smoke_test)"
        print_info "Skipping smoke test for $image_name"
        return 0
    fi

    # Make smoke test executable
    chmod +x "$smoke_test"

    # Run the smoke test
    if bash "$smoke_test" "cloudpirates/$image_name:$tag"; then
        print_success "Smoke test passed for $image_name"
        return 0
    else
        print_error "Smoke test failed for $image_name"
        return 1
    fi
}

# Default values
TAG="test"
RUN_ALL=false
IMAGE_NAME=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        --all)
            RUN_ALL=true
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

# Main execution
if [ "$RUN_ALL" = true ]; then
    print_info "Running smoke tests for all images..."
    echo ""

    FAILED_TESTS=()
    PASSED_TESTS=()

    for image_dir in images/*/; do
        image_name=$(basename "$image_dir")

        if run_smoke_test "$image_name" "$TAG"; then
            PASSED_TESTS+=("$image_name")
        else
            FAILED_TESTS+=("$image_name")
        fi
        echo ""
    done

    # Print summary
    echo ""
    echo "=========================================="
    echo "Smoke Test Summary"
    echo "=========================================="
    echo "Passed: ${#PASSED_TESTS[@]}"
    for test in "${PASSED_TESTS[@]}"; do
        echo "  ✅ $test"
    done

    if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
        echo ""
        echo "Failed: ${#FAILED_TESTS[@]}"
        for test in "${FAILED_TESTS[@]}"; do
            echo "  ❌ $test"
        done
        exit 1
    else
        echo ""
        print_success "All smoke tests passed!"
    fi
elif [ -n "$IMAGE_NAME" ]; then
    if ! run_smoke_test "$IMAGE_NAME" "$TAG"; then
        exit 1
    fi
else
    print_error "Image name is required (or use --all)"
    usage
fi
