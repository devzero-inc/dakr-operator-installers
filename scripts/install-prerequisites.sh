#!/bin/bash

# Install prerequisites for Kubernetes cluster management
# This script installs required tools for AWS, GCP, and Azure

set -e

echo "Installing prerequisites..."

# Update package lists
sudo apt-get update

# Install basic tools
echo "Installing basic tools..."
sudo apt-get install -y jq curl unzip

# Install AWS CLI v2
echo "Installing AWS CLI v2..."
if ! command -v aws &> /dev/null; then
    echo "AWS CLI not found, installing..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf awscliv2.zip aws/
else
    echo "AWS CLI already installed, updating..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install --update
    rm -rf awscliv2.zip aws/
fi
aws --version

# Install kubectl
echo "Installing kubectl..."
if ! command -v kubectl &> /dev/null; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
fi
kubectl version --client

echo "Prerequisites installation completed!"
