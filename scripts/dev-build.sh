#!/bin/bash

set -euo pipefail

# Local development script for testing builds

# Default values
OS="ubuntu"
VERSION="22.04"
ARCH="amd64"
CRIU_VERSION="latest"
NETAVARK_VERSION="latest"

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Test build CRIU and Netavark locally for development.

OPTIONS:
    --os OS                 Target OS (ubuntu, centos, fedora, amazonlinux, rockylinux, debian, alpine, rhel) [default: ubuntu]
    --version VERSION       OS version [default: 22.04]
    --arch ARCH            Target architecture (amd64, arm64) [default: amd64]
    --criu-version VER     CRIU version to build [default: latest]
    --netavark-version VER Netavark version to build [default: latest]
    --help                 Show this help message

EXAMPLES:
    $0                                           # Build for Ubuntu 22.04 amd64
    $0 --os alpine --version 3.19 --arch arm64  # Build for Alpine 3.19 arm64
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Local Development Build ==="
echo "OS: $OS"
echo "Version: $VERSION"
echo "Architecture: $ARCH"
echo "CRIU Version: $CRIU_VERSION"
echo "Netavark Version: $NETAVARK_VERSION"
echo "=============================="

# Run the main build script
"$SCRIPT_DIR/build.sh" \
    --os "$OS" \
    --version "$VERSION" \
    --arch "$ARCH" \
    --criu-version "$CRIU_VERSION" \
    --netavark-version "$NETAVARK_VERSION"

echo ""
echo "=== Build completed! ==="
echo "Check the dist/ directory for results."
echo ""
echo "To test the binaries:"
echo "  cd dist/$OS-$VERSION-$ARCH"
echo "  ./criu --version"
echo "  ./netavark --version"
