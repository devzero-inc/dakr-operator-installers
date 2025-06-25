#!/bin/bash

set -euo pipefail

# Quick test script for local development

echo "=== DAKR Snapshot Tools - Local Test ==="
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed or not in PATH"
    echo "Please install Docker to run builds"
    exit 1
fi

echo "✅ Docker is available"

# Check if make is available
if ! command -v make &> /dev/null; then
    echo "❌ Make is not installed or not in PATH"
    echo "Please install make or use ./scripts/dev-build.sh directly"
    exit 1
fi

echo "✅ Make is available"

# Check current platform
CURRENT_ARCH=$(uname -m)
if [[ "$CURRENT_ARCH" == "x86_64" ]]; then
    ARCH="amd64"
elif [[ "$CURRENT_ARCH" == "aarch64" ]]; then
    ARCH="arm64"
else
    echo "⚠️  Unknown architecture: $CURRENT_ARCH, defaulting to amd64"
    ARCH="amd64"
fi

echo "✅ Detected architecture: $ARCH ($CURRENT_ARCH)"

# Detect OS
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    OS_NAME=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
    OS_VERSION="$VERSION_ID"
    echo "✅ Detected OS: $OS_NAME $OS_VERSION"
else
    echo "⚠️  Cannot detect OS, using Ubuntu 22.04 as default"
    OS_NAME="ubuntu"
    OS_VERSION="22.04"
fi

echo ""
echo "=== Starting Local Build ==="
echo "Building for: $OS_NAME $OS_VERSION $ARCH"
echo ""

# Run the build
if make build-local; then
    echo ""
    echo "✅ Build completed successfully!"
    echo ""
    
    # Look for the built artifacts
    DIST_DIR="dist"
    if [[ -d "$DIST_DIR" ]]; then
        echo "📦 Built artifacts:"
        find "$DIST_DIR" -type f -executable -name "criu" -o -name "netavark" | while read -r file; do
            echo "  - $file ($(ls -lh "$file" | awk '{print $5}'))"
        done
        
        echo ""
        echo "🧪 Testing binaries..."
        
        # Test CRIU if available
        CRIU_BIN=$(find "$DIST_DIR" -name "criu" -type f -executable | head -1)
        if [[ -n "$CRIU_BIN" ]]; then
            echo "Testing CRIU..."
            if $CRIU_BIN --version; then
                echo "✅ CRIU works correctly"
            else
                echo "⚠️  CRIU version check failed"
            fi
        else
            echo "❌ CRIU binary not found"
        fi
        
        # Test Netavark if available
        NETAVARK_BIN=$(find "$DIST_DIR" -name "netavark" -type f -executable | head -1)
        if [[ -n "$NETAVARK_BIN" ]]; then
            echo "Testing Netavark..."
            if $NETAVARK_BIN --version; then
                echo "✅ Netavark works correctly"
            else
                echo "⚠️  Netavark version check failed"
            fi
        else
            echo "❌ Netavark binary not found"
        fi
        
        echo ""
        echo "🎉 Local test completed!"
        echo ""
        echo "Next steps:"
        echo "  1. Copy binaries to your PATH: sudo cp dist/*/criu dist/*/netavark /usr/local/bin/"
        echo "  2. Build for other platforms: make build-all"
        echo "  3. Create a release: make release"
        
    else
        echo "❌ No build artifacts found in $DIST_DIR"
        exit 1
    fi
else
    echo ""
    echo "❌ Build failed!"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check Docker is running: docker info"
    echo "  2. Check available disk space: df -h"
    echo "  3. Try building manually: ./scripts/dev-build.sh"
    echo "  4. Check the logs above for specific error messages"
    exit 1
fi
