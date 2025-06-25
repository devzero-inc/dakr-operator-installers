# Makefile for DAKR Operator and Snapshot Tools

.PHONY: help build-local build-all test clean docker-build release

# Default target
help:
	@echo "DAKR Operator - Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  help           Show this help message"
	@echo "  build-local    Build CRIU and Netavark for local platform"
	@echo "  build-ubuntu   Build for Ubuntu (all versions and architectures)"
	@echo "  build-centos   Build for CentOS (all versions and architectures)"
	@echo "  build-fedora   Build for Fedora (all versions and architectures)"
	@echo "  build-amazonlinux Build for Amazon Linux (all versions and architectures)"
	@echo "  build-rocky    Build for Rocky Linux (all versions and architectures)"
	@echo "  build-debian   Build for Debian (all versions and architectures)"
	@echo "  build-alpine   Build for Alpine (all versions and architectures)"
	@echo "  build-rhel     Build for Red Hat Enterprise Linux (all versions and architectures)"
	@echo "  build-all      Build for all supported platforms"
	@echo "  build-native   Build for all platforms (native architecture only)"
	@echo "  build-cross    Build for all platforms (with cross-compilation)"
	@echo "  test           Test local build"
	@echo "  clean          Clean build artifacts"
	@echo "  release        Create a local release archive"
	@echo ""
	@echo "Environment variables:"
	@echo "  CRIU_VERSION     CRIU version to build (default: latest)"
	@echo "  NETAVARK_VERSION Netavark version to build (default: latest)"
	@echo ""
	@echo "Examples:"
	@echo "  make build-local"
	@echo "  make build-ubuntu CRIU_VERSION=v3.19"
	@echo "  make build-all CRIU_VERSION=v3.19 NETAVARK_VERSION=v1.7.0"

# Variables
CRIU_VERSION ?= latest
NETAVARK_VERSION ?= latest
BUILD_SCRIPT = ./scripts/build.sh

# Detect host architecture
HOST_ARCH := $(shell uname -m)
ifeq ($(HOST_ARCH),x86_64)
	NATIVE_ARCH := amd64
else ifeq ($(HOST_ARCH),aarch64)
	NATIVE_ARCH := arm64
else
	NATIVE_ARCH := amd64
endif

# Local build (detect current platform)
build-local:
	@echo "Building for local platform..."
	./scripts/dev-build.sh \
		--criu-version $(CRIU_VERSION) \
		--netavark-version $(NETAVARK_VERSION)

# Ubuntu builds (native architecture only)
build-ubuntu:
	@echo "Building for Ubuntu platforms..."
	$(BUILD_SCRIPT) --os ubuntu --version 20.04 --arch $(NATIVE_ARCH) --criu-version $(CRIU_VERSION) --netavark-version $(NETAVARK_VERSION)
	$(BUILD_SCRIPT) --os ubuntu --version 22.04 --arch $(NATIVE_ARCH) --criu-version $(CRIU_VERSION) --netavark-version $(NETAVARK_VERSION)
	$(BUILD_SCRIPT) --os ubuntu --version 24.04 --arch $(NATIVE_ARCH) --criu-version $(CRIU_VERSION) --netavark-version $(NETAVARK_VERSION)

# Ubuntu builds (with cross-compilation)
build-ubuntu-cross:
	@echo "Building for Ubuntu platforms (with cross-compilation)..."
	$(BUILD_SCRIPT) --os ubuntu --version 20.04 --arch amd64 --criu-version $(CRIU_VERSION) --netavark-version $(NETAVARK_VERSION) --cross-build
	$(BUILD_SCRIPT) --os ubuntu --version 20.04 --arch arm64 --criu-version $(CRIU_VERSION) --netavark-version $(NETAVARK_VERSION) --cross-build
	$(BUILD_SCRIPT) --os ubuntu --version 22.04 --arch amd64 --criu-version $(CRIU_VERSION) --netavark-version $(NETAVARK_VERSION) --cross-build
	$(BUILD_SCRIPT) --os ubuntu --version 22.04 --arch arm64 --criu-version $(CRIU_VERSION) --netavark-version $(NETAVARK_VERSION) --cross-build
	$(BUILD_SCRIPT) --os ubuntu --version 24.04 --arch amd64 --criu-version $(CRIU_VERSION) --netavark-version $(NETAVARK_VERSION) --cross-build
	$(BUILD_SCRIPT) --os ubuntu --version 24.04 --arch arm64 --criu-version $(CRIU_VERSION) --netavark-version $(NETAVARK_VERSION) --cross-build

# CentOS builds
build-centos:
	@echo "Building for CentOS platforms..."
	$(BUILD_SCRIPT) --os centos --version 7 --arch $(NATIVE_ARCH) --criu-version $(CRIU_VERSION) --netavark-version $(NETAVARK_VERSION)
	$(BUILD_SCRIPT) --os centos --version 8 --arch $(NATIVE_ARCH) --criu-version $(CRIU_VERSION) --netavark-version $(NETAVARK_VERSION)

# Fedora builds
build-fedora:
	@echo "Building for Fedora platforms..."
	$(BUILD_SCRIPT) --os fedora --version 38 --arch $(NATIVE_ARCH) --criu-version $(CRIU_VERSION) --netavark-version $(NETAVARK_VERSION)
	$(BUILD_SCRIPT) --os fedora --version 39 --arch $(NATIVE_ARCH) --criu-version $(CRIU_VERSION) --netavark-version $(NETAVARK_VERSION)
	$(BUILD_SCRIPT) --os fedora --version 40 --arch $(NATIVE_ARCH) --criu-version $(CRIU_VERSION) --netavark-version $(NETAVARK_VERSION)

# Amazon Linux builds
build-amazonlinux:
	@echo "Building for Amazon Linux platforms..."
	$(BUILD_SCRIPT) --os amazonlinux --version 2 --arch $(NATIVE_ARCH) --criu-version $(CRIU_VERSION) --netavark-version $(NETAVARK_VERSION)
	$(BUILD_SCRIPT) --os amazonlinux --version 2023 --arch $(NATIVE_ARCH) --criu-version $(CRIU_VERSION) --netavark-version $(NETAVARK_VERSION)

# Rocky Linux builds
build-rocky:
	@echo "Building for Rocky Linux platforms..."
	$(BUILD_SCRIPT) --os rockylinux --version 8 --arch $(NATIVE_ARCH) --criu-version $(CRIU_VERSION) --netavark-version $(NETAVARK_VERSION)
	$(BUILD_SCRIPT) --os rockylinux --version 9 --arch $(NATIVE_ARCH) --criu-version $(CRIU_VERSION) --netavark-version $(NETAVARK_VERSION)

# Debian builds
build-debian:
	@echo "Building for Debian platforms..."
	$(BUILD_SCRIPT) --os debian --version 11 --arch $(NATIVE_ARCH) --criu-version $(CRIU_VERSION) --netavark-version $(NETAVARK_VERSION)
	$(BUILD_SCRIPT) --os debian --version 12 --arch $(NATIVE_ARCH) --criu-version $(CRIU_VERSION) --netavark-version $(NETAVARK_VERSION)

# Alpine builds
build-alpine:
	@echo "Building for Alpine platforms..."
	$(BUILD_SCRIPT) --os alpine --version 3.18 --arch $(NATIVE_ARCH) --criu-version $(CRIU_VERSION) --netavark-version $(NETAVARK_VERSION)
	$(BUILD_SCRIPT) --os alpine --version 3.19 --arch $(NATIVE_ARCH) --criu-version $(CRIU_VERSION) --netavark-version $(NETAVARK_VERSION)

# RHEL builds
build-rhel:
	@echo "Building for Red Hat Enterprise Linux platforms..."
	$(BUILD_SCRIPT) --os rhel --version 7 --arch $(NATIVE_ARCH) --criu-version $(CRIU_VERSION) --netavark-version $(NETAVARK_VERSION)
	$(BUILD_SCRIPT) --os rhel --version 8 --arch $(NATIVE_ARCH) --criu-version $(CRIU_VERSION) --netavark-version $(NETAVARK_VERSION)
	$(BUILD_SCRIPT) --os rhel --version 9 --arch $(NATIVE_ARCH) --criu-version $(CRIU_VERSION) --netavark-version $(NETAVARK_VERSION)

# Build all platforms (native architecture only)
build-native: build-ubuntu build-centos build-fedora build-amazonlinux build-rocky build-debian build-alpine build-rhel
	@echo "All native builds completed!"

# Build all platforms with cross-compilation
build-cross: build-ubuntu-cross
	@echo "Cross-compilation builds completed!"
	@echo "Note: Only Ubuntu cross-compilation is implemented. Add more platforms as needed."

# Build all platforms
build-all: build-native build-cross
	@echo "All builds completed!"

# Test local build
test: build-local
	@echo "Testing local build..."
	@if [ -f dist/*/criu ]; then \
		echo "✓ CRIU binary found"; \
		dist/*/criu --version || echo "⚠ CRIU version check failed"; \
	else \
		echo "✗ CRIU binary not found"; \
	fi
	@if [ -f dist/*/netavark ]; then \
		echo "✓ Netavark binary found"; \
		dist/*/netavark --version || echo "⚠ Netavark version check failed"; \
	else \
		echo "✗ Netavark binary not found"; \
	fi

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf dist/
	rm -rf build/context-*
	docker system prune -f --filter label=builder=dakr-snapshot-tools || true
	@echo "Clean completed!"

# Create a local release archive
release:
	@echo "Creating local release archive..."
	@if [ ! -d dist/ ]; then \
		echo "No build artifacts found. Run 'make build-all' first."; \
		exit 1; \
	fi
	@mkdir -p releases
	@RELEASE_NAME="dakr-snapshot-tools-$(shell date +%Y%m%d-%H%M%S)"; \
	tar -czf "releases/$$RELEASE_NAME.tar.gz" -C dist . && \
	echo "Release archive created: releases/$$RELEASE_NAME.tar.gz"

# Docker-specific targets
docker-build:
	@echo "Building Docker images for all platforms..."
	@for os in ubuntu centos fedora amazonlinux rockylinux debian alpine rhel; do \
		for version in $$(case $$os in \
			ubuntu) echo "20.04 22.04 24.04" ;; \
			centos) echo "7 8" ;; \
			fedora) echo "38 39 40" ;; \
			amazonlinux) echo "2 2023" ;; \
			rockylinux) echo "8 9" ;; \
			debian) echo "11 12" ;; \
			alpine) echo "3.18 3.19" ;; \
			rhel) echo "7 8 9" ;; \
		esac); do \
			for arch in amd64 arm64; do \
				echo "Building Docker image for $$os:$$version ($$arch)..."; \
				docker build \
					--platform linux/$$arch \
					--build-arg OS_VERSION=$$version \
					--build-arg CRIU_VERSION=$(CRIU_VERSION) \
					--build-arg NETAVARK_VERSION=$(NETAVARK_VERSION) \
					--build-arg TARGET_ARCH=$$arch \
					-t dakr-builder:$$os-$$version-$$arch \
					-f build/Dockerfile.$$os \
					build/ || echo "Failed to build $$os:$$version ($$arch)"; \
			done; \
		done; \
	done
