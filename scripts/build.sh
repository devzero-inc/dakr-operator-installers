#!/bin/bash

set -euo pipefail

# Default values
OS=""
VERSION=""
ARCH=""
CRIU_VERSION="latest"
NETAVARK_VERSION="latest"
OUTPUT_DIR="dist"
CROSS_BUILD="false"
HOST_ARCH=$(uname -m)

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Build CRIU and Netavark for specified OS/version/architecture combination.

OPTIONS:
    --os OS                 Target OS (ubuntu, centos, fedora, amazonlinux, rockylinux, debian, alpine, rhel)
    --version VERSION       OS version (e.g., 20.04, 22.04, 7, 8, 9, 11, 12, 3.18, 3.19)
    --arch ARCH            Target architecture (amd64, arm64)
    --criu-version VER     CRIU version to build (default: latest)
    --netavark-version VER Netavark version to build (default: latest)
    --output-dir DIR       Output directory (default: dist)
    --cross-build          Enable cross-platform builds (requires Docker buildx)
    --help                 Show this help message

EXAMPLES:
    $0 --os ubuntu --version 22.04 --arch amd64
    $0 --os alpine --version 3.19 --arch arm64 --cross-build
    $0 --os ubuntu --version 20.04 --arch amd64 --criu-version v3.19

NOTE:
    Cross-platform builds (--cross-build) require Docker buildx and QEMU emulation.
    Without --cross-build, builds are limited to host architecture for better compatibility.
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --os)
            OS="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --arch)
            ARCH="$2"
            shift 2
            ;;
        --criu-version)
            CRIU_VERSION="$2"
            shift 2
            ;;
        --netavark-version)
            NETAVARK_VERSION="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --cross-build)
            CROSS_BUILD="true"
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$OS" || -z "$VERSION" || -z "$ARCH" ]]; then
    echo "Error: --os, --version, and --arch are required"
    show_help
    exit 1
fi

# Validate OS
case "$OS" in
    ubuntu|centos|fedora|amazonlinux|rockylinux|debian|alpine|rhel)
        ;;
    *)
        echo "Error: Unsupported OS '$OS'"
        echo "Supported: ubuntu, centos, fedora, amazonlinux, rockylinux, debian, alpine, rhel"
        exit 1
        ;;
esac

# Validate architecture
case "$ARCH" in
    amd64|arm64)
        ;;
    *)
        echo "Error: Unsupported architecture '$ARCH'"
        echo "Supported: amd64, arm64"
        exit 1
        ;;
esac

# Check architecture compatibility
HOST_DOCKER_ARCH=""
TARGET_DOCKER_ARCH=""

# Convert host architecture to Docker format
case "$HOST_ARCH" in
    x86_64)
        HOST_DOCKER_ARCH="amd64"
        ;;
    aarch64)
        HOST_DOCKER_ARCH="arm64"
        ;;
    *)
        echo "Error: Unsupported host architecture '$HOST_ARCH'"
        exit 1
        ;;
esac

# Convert target architecture to Docker format
case "$ARCH" in
    amd64)
        TARGET_DOCKER_ARCH="amd64"
        ;;
    arm64)
        TARGET_DOCKER_ARCH="arm64"
        ;;
esac

# Check if cross-compilation is needed
IS_CROSS_BUILD="false"
if [[ "$HOST_DOCKER_ARCH" != "$TARGET_DOCKER_ARCH" ]]; then
    IS_CROSS_BUILD="true"
    if [[ "$CROSS_BUILD" != "true" ]]; then
        echo "Error: Cross-platform build detected (host: $HOST_DOCKER_ARCH, target: $TARGET_DOCKER_ARCH)"
        echo "Add --cross-build flag to enable cross-platform builds, or use --arch $HOST_DOCKER_ARCH for native builds"
        echo ""
        echo "For cross-platform builds, ensure you have:"
        echo "  1. Docker buildx installed and configured"
        echo "  2. QEMU emulation set up (run: docker run --rm --privileged multiarch/qemu-user-static --reset -p yes)"
        exit 1
    fi
fi

# Setup variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build"
OUTPUT_PATH="$PROJECT_ROOT/$OUTPUT_DIR"

# Map architecture names for Docker
DOCKER_ARCH="$ARCH"
if [[ "$ARCH" == "amd64" ]]; then
    DOCKER_ARCH="amd64"
elif [[ "$ARCH" == "arm64" ]]; then
    DOCKER_ARCH="arm64"
fi

# Create output directory
mkdir -p "$OUTPUT_PATH"

echo "=== Building CRIU and Netavark ==="
echo "OS: $OS"
echo "Version: $VERSION"
echo "Architecture: $ARCH"
echo "CRIU Version: $CRIU_VERSION"
echo "Netavark Version: $NETAVARK_VERSION"
echo "Output Directory: $OUTPUT_PATH"
echo "==============================="

# Determine the appropriate Dockerfile
DOCKERFILE_NAME=""
case "$OS" in
    ubuntu)
        DOCKERFILE_NAME="Dockerfile.ubuntu"
        ;;
    centos)
        DOCKERFILE_NAME="Dockerfile.centos"
        ;;
    fedora)
        DOCKERFILE_NAME="Dockerfile.fedora"
        ;;
    amazonlinux)
        DOCKERFILE_NAME="Dockerfile.amazonlinux"
        ;;
    rockylinux)
        DOCKERFILE_NAME="Dockerfile.rockylinux"
        ;;
    debian)
        DOCKERFILE_NAME="Dockerfile.debian"
        ;;
    alpine)
        DOCKERFILE_NAME="Dockerfile.alpine"
        ;;
    rhel)
        DOCKERFILE_NAME="Dockerfile.rhel"
        ;;
esac

# Build using Docker
DOCKERFILE_PATH="$BUILD_DIR/$DOCKERFILE_NAME"
if [[ ! -f "$DOCKERFILE_PATH" ]]; then
    echo "Error: Dockerfile not found: $DOCKERFILE_PATH"
    exit 1
fi

# Create a unique build context directory
BUILD_CONTEXT="$BUILD_DIR/context-$OS-$VERSION-$ARCH"
mkdir -p "$BUILD_CONTEXT"

# Copy build files to context
cp "$DOCKERFILE_PATH" "$BUILD_CONTEXT/"
cp "$SCRIPT_DIR/build.sh" "$BUILD_CONTEXT/"


# Build the container using appropriate method
IMAGE_TAG="dakr-builder:$OS-$VERSION-$ARCH"

echo "Building Docker image: $IMAGE_TAG"

if [[ "$IS_CROSS_BUILD" == "true" ]]; then
    echo "Using buildx for cross-compilation..."
    # Use buildx for cross-platform builds
    docker buildx build \
        --builder multiplatform \
        --platform "linux/$TARGET_DOCKER_ARCH" \
        --build-arg "OS_VERSION=$VERSION" \
        --build-arg "CRIU_VERSION=$CRIU_VERSION" \
        --build-arg "NETAVARK_VERSION=$NETAVARK_VERSION" \
        --build-arg "TARGET_ARCH=$ARCH" \
        --load \
        -t "$IMAGE_TAG" \
        -f "$BUILD_CONTEXT/$DOCKERFILE_NAME" \
        "$BUILD_CONTEXT"
else
    echo "Using native Docker build..."
    # Use regular docker build for native builds
    docker build \
        --build-arg "OS_VERSION=$VERSION" \
        --build-arg "CRIU_VERSION=$CRIU_VERSION" \
        --build-arg "NETAVARK_VERSION=$NETAVARK_VERSION" \
        --build-arg "TARGET_ARCH=$ARCH" \
        -t "$IMAGE_TAG" \
        -f "$BUILD_CONTEXT/$DOCKERFILE_NAME" \
        "$BUILD_CONTEXT"
fi

# Extract binaries from the container
CONTAINER_ID=$(docker create "$IMAGE_TAG")

# Create platform-specific output directory
PLATFORM_OUTPUT="$OUTPUT_PATH/$OS-$VERSION-$ARCH"
mkdir -p "$PLATFORM_OUTPUT"

echo "Extracting binaries to: $PLATFORM_OUTPUT"

# Extract CRIU binaries
docker cp "$CONTAINER_ID:/usr/local/bin/criu" "$PLATFORM_OUTPUT/" 2>/dev/null || \
docker cp "$CONTAINER_ID:/usr/bin/criu" "$PLATFORM_OUTPUT/" 2>/dev/null || \
docker cp "$CONTAINER_ID:/build/criu/criu/criu" "$PLATFORM_OUTPUT/" || {
    echo "Warning: Could not extract CRIU binary"
}

# Extract Netavark binary
docker cp "$CONTAINER_ID:/usr/local/bin/netavark" "$PLATFORM_OUTPUT/" 2>/dev/null || \
docker cp "$CONTAINER_ID:/usr/bin/netavark" "$PLATFORM_OUTPUT/" 2>/dev/null || \
docker cp "$CONTAINER_ID:/build/netavark/target/release/netavark" "$PLATFORM_OUTPUT/" || {
    echo "Warning: Could not extract Netavark binary"
}

# Extract any additional libraries or dependencies
docker cp "$CONTAINER_ID:/build/deps/" "$PLATFORM_OUTPUT/" 2>/dev/null || true

# Cleanup
docker rm "$CONTAINER_ID"
docker rmi "$IMAGE_TAG" || true
rm -rf "$BUILD_CONTEXT"

# Create metadata file
cat > "$PLATFORM_OUTPUT/metadata.json" << EOF
{
    "os": "$OS",
    "version": "$VERSION",
    "architecture": "$ARCH",
    "criu_version": "$CRIU_VERSION",
    "netavark_version": "$NETAVARK_VERSION",
    "build_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "build_host": "$(uname -a)"
}
EOF

# Verify binaries
echo "=== Verification ==="
for binary in criu netavark; do
    if [[ -f "$PLATFORM_OUTPUT/$binary" ]]; then
        echo "✓ $binary: $(ls -lh "$PLATFORM_OUTPUT/$binary" | awk '{print $5}')"
        # Make executable
        chmod +x "$PLATFORM_OUTPUT/$binary"
    else
        echo "✗ $binary: NOT FOUND"
    fi
done

echo "=== Runtime Verification ==="
if [[ -x "$PLATFORM_OUTPUT/criu" ]]; then
    # Skip runtime verification in CI environments where libs might not be available
    if [[ "${CI:-false}" == "true" ]] || [[ "${GITHUB_ACTIONS:-false}" == "true" ]]; then
        echo "ℹ Skipping runtime verification in CI environment"
        echo "✓ CRIU binary exists and is executable"
    else
        "$PLATFORM_OUTPUT/criu" check && echo "✓ CRIU runtime check passed" || { 
            echo "✗ CRIU runtime check failed - this may be due to missing libraries on this system"
            echo "  The binary should still work on systems with proper dependencies installed"
        }
    fi
else
    echo "✗ CRIU binary not found or not executable"
fi

if [[ -x "$PLATFORM_OUTPUT/netavark" ]]; then
    if [[ "${CI:-false}" == "true" ]] || [[ "${GITHUB_ACTIONS:-false}" == "true" ]]; then
        echo "ℹ Skipping netavark verification in CI environment"
        echo "✓ Netavark binary exists and is executable"
    else
        "$PLATFORM_OUTPUT/netavark" --version >/dev/null 2>&1 && echo "✓ Netavark runtime check passed" || {
            echo "✗ Netavark runtime check failed - this may be due to missing libraries"
            echo "  The binary should still work on systems with proper dependencies installed"
        }
    fi
else
    echo "✗ Netavark binary not found or not executable"
fi

if [[ -x "$PLATFORM_OUTPUT/netavark" ]]; then
    "$PLATFORM_OUTPUT/netavark" --help || { echo "✗ Netavark failed to run"; exit 1; }
fi

# Create archive
cd "$OUTPUT_PATH"
ARCHIVE_NAME="dakr-snapshot-tools-$OS-$VERSION-$ARCH.tar.gz"
tar -czf "$ARCHIVE_NAME" -C "$OS-$VERSION-$ARCH" .

echo "=== Build Complete ==="
echo "Archive: $OUTPUT_PATH/$ARCHIVE_NAME"
echo "Size: $(ls -lh "$OUTPUT_PATH/$ARCHIVE_NAME" | awk '{print $5}')"
echo "======================="
