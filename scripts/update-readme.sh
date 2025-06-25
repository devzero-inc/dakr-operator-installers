#!/bin/bash

set -euo pipefail

# Script to update README.md with latest release information

RELEASE_TAG="$1"

if [[ -z "$RELEASE_TAG" ]]; then
    echo "Usage: $0 <release-tag>"
    exit 1
fi

README_FILE="README.md"

# Check if README exists
if [[ ! -f "$README_FILE" ]]; then
    echo "Error: $README_FILE not found"
    exit 1
fi

# Create a backup
cp "$README_FILE" "${README_FILE}.backup"

# Generate release section
RELEASE_SECTION=$(cat << EOF

---

## DAKR Snapshot Tools

This repository also provides pre-built binaries of CRIU and Netavark for enabling container snapshotting capabilities across multiple Linux distributions and architectures.

### Latest Release: \`$RELEASE_TAG\`

Download the appropriate archive for your platform from the [Releases page](https://github.com/\${GITHUB_REPOSITORY}/releases/latest).

#### Supported Platforms

| OS | Versions | Architectures |
|---|---|---|
| Ubuntu | 20.04, 22.04, 24.04 | amd64, arm64 |
| CentOS | 7, 8 | amd64, arm64 |
| Fedora | 38, 39, 40 | amd64, arm64 |
| Amazon Linux | 2, 2023 | amd64, arm64 |
| Rocky Linux | 8, 9 | amd64, arm64 |
| Debian | 11, 12 | amd64, arm64 |
| Alpine | 3.18, 3.19 | amd64, arm64 |
| RHEL | 7, 8, 9 | amd64, arm64 |

#### Quick Installation

\`\`\`bash
# Download for your platform (example: Ubuntu 22.04 amd64)
wget https://github.com/\${GITHUB_REPOSITORY}/releases/download/$RELEASE_TAG/dakr-snapshot-tools-ubuntu-22.04-amd64.tar.gz

# Extract binaries
tar -xzf dakr-snapshot-tools-ubuntu-22.04-amd64.tar.gz

# Install binaries (optional)
sudo cp criu netavark /usr/local/bin/
\`\`\`

#### What's Included

- **CRIU**: Checkpoint/Restore in Userspace for container snapshotting
- **Netavark**: Network stack for containers
- **Dependencies**: Required shared libraries for each platform
- **Metadata**: Build information and version details

These tools are essential for the DAKR operator's container snapshotting capabilities and will be used by the daemonset to prepare hosts for snapshot-friendly operations.

EOF
)

# Add the release section before the last line (if it doesn't already exist)
if ! grep -q "DAKR Snapshot Tools" "$README_FILE"; then
    # Insert before the last line or at the end
    echo "$RELEASE_SECTION" >> "$README_FILE"
    echo "✓ Added release section to $README_FILE"
else
    # Update existing section
    # This is a simple approach - in production you might want more sophisticated updating
    echo "ℹ Release section already exists in $README_FILE"
fi

echo "README update completed for release: $RELEASE_TAG"
