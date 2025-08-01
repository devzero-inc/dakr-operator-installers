#!/bin/bash

# Kubernetes Cluster Management CLI
# Supports AWS EKS (via eksctl), GCP GKE, and Azure AKS with minimal dependencies
# Usage: ./create-k8s.sh --cloud <cloud> --os <os> --nodes <count> [--action <action>]

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
CLOUD="aws"          # Default to AWS
OS=""                 # Will be set based on cloud provider (al2023/cos/azurelinux)
NODE_COUNT="2"       # Default to 2 nodes
ACTION=""            # No default action
REGION=""
CLUSTER_NAME=""
AWS_PROFILE=""
GCP_PROJECT=""
AZURE_SUBSCRIPTION=""
CUSTOM_AMI=""
NODE_SIZE=""           # Instance/machine/VM size
CLUSTER_VERSION="1.32" # Default Kubernetes version

# Function to print colored output
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

# Function to show usage
show_usage() {
    cat << EOF
Kubernetes Cluster Management CLI

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --create, -c               Create a new cluster (required for creation)
    --delete, -d               Delete cluster instead of creating
    --cloud, -C <cloud>        Cloud provider: aws, gcp, azure (default: aws)
    --os, -o <os>              Operating system for nodes (default: linux)
    --nodes, -n <count>        Number of worker nodes 1-100 (default: 2)
    --region, -r <region>      Cloud region (optional, uses CLI defaults)
    --name, -N <name>          Cluster name (optional, auto-generated)
    --profile, -p <profile>    AWS profile name (optional, uses default)
    --project, -P <project>    GCP project ID (optional, uses CLI default)
    --subscription, -s <sub>   Azure subscription ID (optional, uses CLI default)
    --ami, -a <ami-id>         Custom AMI ID for AWS EKS nodes (auto-sets --os to custom)
    --size, -S <size>          Node instance size (optional, auto-selected based on cloud)
    --version, -v <version>    Kubernetes version (default: 1.32)
    --help, -h                 Show this help message

SUPPORTED OS BY CLOUD:
    AWS EKS:
        al2023 (default), linux, ubuntu, amazonlinux, bottlerocket, windows
        custom - automatically set when --ami flag is used
    
    GCP GKE:
        cos (default), linux, ubuntu, windows
    
    Azure AKS:
        azurelinux (default), linux, ubuntu, windows

EXAMPLES:
    # Create AWS cluster with default settings (2 Linux nodes)
    $0 --create
    
    # Create AWS EKS cluster with 3 nodes
    $0 --create --nodes 3
    
    # Create GCP cluster with default settings
    $0 --create -C gcp
    
    # Create Azure cluster with Ubuntu nodes
    $0 --create -C azure --os ubuntu
    
    # Create AWS cluster with custom AMI and specific version
    $0 --create --ami ami-0123456789abcdef0 --version 1.30
    
    # Create cluster with specific name, region, and version
    $0 --create --name my-cluster --region us-east-1 --version 1.31
    
    # Delete cluster (will list available clusters)
    $0 --delete
    
    # Delete specific cluster by name
    $0 --delete --name my-cluster

QUICK START:
    $0 --create
    This creates an AWS EKS cluster with 2 Linux nodes using default settings.

NOTES:
    - All parameters are optional with smart defaults
    - Uses CLI defaults for region, account, etc. if not specified
    - AWS: Uses eksctl for cluster creation and management
    - AWS: Supports multiple profiles via --profile flag
    - AWS: Supports custom AMIs via --ami flag (automatically sets --os to custom)
    - GCP: Supports project override via --project flag  
    - Azure: Supports subscription override via --subscription flag
    - Creates completely public clusters for easy access
    - Tracks clusters with .info files for easy deletion
    - Minimal dependencies: only requires cloud CLI tools and kubectl (plus eksctl for AWS)
EOF
}

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --create|-c)
                ACTION="create"
                shift
                ;;
            --cloud|-C)
                CLOUD="$2"
                shift 2
                ;;
            --os|-o)
                OS="$2"
                shift 2
                ;;
            --nodes|-n)
                NODE_COUNT="$2"
                shift 2
                ;;
            --delete|-d)
                ACTION="delete"
                shift
                ;;
            --region|-r)
                REGION="$2"
                shift 2
                ;;
            --name|-N)
                CLUSTER_NAME="$2"
                shift 2
                ;;
            --profile|-p)
                AWS_PROFILE="$2"
                shift 2
                ;;
            --project|-P)
                GCP_PROJECT="$2"
                shift 2
                ;;
            --subscription|-s)
                AZURE_SUBSCRIPTION="$2"
                shift 2
                ;;
            --ami|-a)
                CUSTOM_AMI="$2"
                shift 2
                ;;
            --size|-S)
                NODE_SIZE="$2"
                shift 2
                ;;
            --version|-v)
                CLUSTER_VERSION="$2"
                shift 2
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Function to validate arguments
validate_arguments() {
    # Set smart defaults and handle special cases for create action
    if [[ "$ACTION" == "create" ]]; then
        
        # Set default OS based on cloud provider if not specified
        if [[ -z "$OS" ]]; then
            case $CLOUD in
                aws)
                    OS="al2023"  # Amazon Linux 2023
                    print_info "✓ Using default OS for AWS: $OS"
                    ;;
                gcp)
                    OS="cos"     # Container-Optimized OS
                    print_info "✓ Using default OS for GCP: $OS"
                    ;;
                azure)
                    OS="azurelinux"  # Azure Linux
                    print_info "✓ Using default OS for Azure: $OS"
                    ;;
                *)
                    OS="al2023"  # Fallback default
                    print_info "✓ Using fallback default OS: $OS"
                    ;;
            esac
        fi
        
        # Handle AWS EKS with custom AMI - override OS to custom
        if [[ "$CLOUD" == "aws" && -n "$CUSTOM_AMI" ]]; then
            if [[ "$OS" != "custom" ]]; then
                if [[ "$OS" != "linux" ]]; then
                    print_warning "Overriding --os $OS with 'custom' since AMI was provided"
                else
                    print_info "✓ Using custom OS since AMI was provided: $CUSTOM_AMI"
                fi
                OS="custom"
            fi
        fi
        
        # Handle legacy "linux" OS mapping for different clouds
        if [[ "$OS" == "linux" ]]; then
            case $CLOUD in
                gcp)
                    # For GCP, map "linux" to "cos" (Container-Optimized OS)
                    ACTUAL_OS="cos"
                    print_info "✓ Using Container-Optimized OS for GCP (mapped from linux)"
                    ;;
                azure)
                    # For Azure, map "linux" to "ubuntu" 
                    ACTUAL_OS="ubuntu"
                    print_info "✓ Using Ubuntu for Azure (mapped from linux)"
                    ;;
                aws)
                    # For AWS, map "linux" to "al2023" (Amazon Linux 2023)
                    ACTUAL_OS="al2023"
                    print_info "✓ Using Amazon Linux 2023 for AWS (mapped from linux)"
                    ;;
                *)
                    ACTUAL_OS="linux"
                    ;;
            esac
        else
            ACTUAL_OS="$OS"
        fi
        
        print_info "✓ Cluster config: $CLOUD cloud, $NODE_COUNT nodes, $ACTUAL_OS OS, version $CLUSTER_VERSION"
    fi
    
    # Validate cloud provider
    if [[ -n "$CLOUD" ]]; then
        case $CLOUD in
            aws|gcp|azure)
                ;;
            *)
                print_error "Invalid cloud provider: $CLOUD. Must be aws, gcp, or azure."
                echo ""
                show_usage
                exit 1
                ;;
        esac
    fi
    
    # Validate node count
    if [[ -n "$NODE_COUNT" ]]; then
        if ! [[ "$NODE_COUNT" =~ ^[0-9]+$ ]] || [ "$NODE_COUNT" -lt 1 ] || [ "$NODE_COUNT" -gt 100 ]; then
            print_error "Invalid node count: $NODE_COUNT. Must be a number between 1 and 100."
            echo ""
            show_usage
            exit 1
        fi
    fi
    
    # Validate custom AMI format for AWS
    if [[ -n "$CUSTOM_AMI" ]]; then
        if [[ "$CLOUD" != "aws" ]]; then
            print_error "Custom AMI is only supported for AWS EKS clusters."
            echo ""
            show_usage
            exit 1
        fi
        
        if ! [[ "$CUSTOM_AMI" =~ ^ami-[0-9a-f]{8,17}$ ]]; then
            print_error "Invalid AMI ID format: $CUSTOM_AMI. Must be in format ami-xxxxxxxx"
            echo ""
            show_usage
            exit 1
        fi
    fi
    
    # Validate action
    case $ACTION in
        create|delete)
            ;;
        *)
            print_error "Invalid action: $ACTION. Must be 'create' or 'delete'."
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Function to check if required tools are installed
check_prerequisites() {
    local cloud=$1
    
    case $cloud in
        aws)
            if ! command -v eksctl &> /dev/null; then
                print_error "eksctl is not installed. Please install it first."
                print_info "Install with: curl --silent --location 'https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz' | tar xz -C /tmp && sudo mv /tmp/eksctl /usr/local/bin"
                exit 1
            fi
            
            if ! command -v aws &> /dev/null; then
                print_error "AWS CLI is not installed. Please install it first."
                print_info "Install with: curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip' && unzip awscliv2.zip && sudo ./aws/install"
                exit 1
            fi
            
            # Build AWS CLI command for testing (before get_aws_defaults)
            local test_aws_cmd="aws"
            if [[ -n "$AWS_PROFILE" ]]; then
                test_aws_cmd="aws --profile $AWS_PROFILE"
            fi
            
            # Test AWS CLI access
            if ! $test_aws_cmd sts get-caller-identity >/dev/null 2>&1; then
                print_error "AWS CLI is not configured or lacks permissions. Please run 'aws configure' first."
                if [[ -n "$AWS_PROFILE" ]]; then
                    print_info "Or check if profile '$AWS_PROFILE' exists and has valid credentials."
                fi
                exit 1
            fi
            
            # Check for jq if using custom AMI
            if [[ "$OS" == "custom" ]] && ! command -v jq >/dev/null 2>&1; then
                print_error "jq is required for custom AMI validation. Please install it first."
                print_info "Install with: sudo apt-get update && sudo apt-get install -y jq"
                exit 1
            fi
            ;;
        gcp)
            if ! command -v gcloud &> /dev/null; then
                print_error "Google Cloud CLI is not installed. Please install it first."
                print_info "Install with: curl https://sdk.cloud.google.com | bash"
                exit 1
            fi
            ;;
        azure)
            if ! command -v az &> /dev/null; then
                print_error "Azure CLI is not installed. Please install it first."
                print_info "Install with: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
                exit 1
            fi
            ;;
    esac
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install it first."
        print_info "Install with: curl -LO 'https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl' && sudo install kubectl /usr/local/bin/"
        exit 1
    fi
}

# Function to get default values for AWS
get_aws_defaults() {
    # Build AWS CLI command with profile if specified
    AWS_CMD="aws"
    if [[ -n "$AWS_PROFILE" ]]; then
        AWS_CMD="aws --profile $AWS_PROFILE"
        print_info "Using AWS profile: $AWS_PROFILE"
    fi
    
    # Get region from AWS CLI config, command line, or use default
    if [[ -z "$REGION" ]]; then
        AWS_REGION=$($AWS_CMD configure get region 2>/dev/null || echo "us-west-2")
    else
        AWS_REGION="$REGION"
    fi
    
    # Get account ID
    AWS_ACCOUNT_ID=$($AWS_CMD sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
    
    # Default cluster name if not provided
    if [[ -z "$CLUSTER_NAME" ]]; then
        CLUSTER_NAME="k8s-cluster-$(date +%Y%m%d-%H%M%S)"
    fi
    
    # Set node instance type - use provided size or default based on OS
    if [[ -n "$NODE_SIZE" ]]; then
        NODE_TYPE="$NODE_SIZE"
        print_info "Using specified instance type: $NODE_TYPE"
    else
        case $OS in
            windows)
                NODE_TYPE="m5.large"
                ;;
            *)
                NODE_TYPE="t3.medium"
                ;;
        esac
        print_info "Using default instance type: $NODE_TYPE"
    fi
    
    print_info "AWS Config - Region: $AWS_REGION, Instance Type: $NODE_TYPE, Cluster: $CLUSTER_NAME, Version: $CLUSTER_VERSION"
    if [[ -n "$AWS_ACCOUNT_ID" ]]; then
        print_info "AWS Account: $AWS_ACCOUNT_ID"
    fi
}

# Function to get default values for GCP
get_gcp_defaults() {
    # Use provided project or get from gcloud config
    if [[ -n "$GCP_PROJECT" ]]; then
        print_info "Using provided GCP project: $GCP_PROJECT"
        # Set the project for this session
        gcloud config set project "$GCP_PROJECT" --quiet
    else
        GCP_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
        if [ -z "$GCP_PROJECT" ]; then
            print_error "No GCP project specified. Use --project/-P PROJECT_ID or set default: gcloud config set project PROJECT_ID"
            exit 1
        fi
    fi
    
    # Get zone from command line, gcloud config, or use default
    if [[ -z "$REGION" ]]; then
        GCP_ZONE=$(gcloud config get-value compute/zone 2>/dev/null)
        # If zone is empty or not set, use default
        if [[ -z "$GCP_ZONE" ]]; then
            GCP_ZONE="us-central1-a"
        fi
    else
        GCP_ZONE="$REGION"
    fi
    
    # Default cluster name if not provided
    if [[ -z "$CLUSTER_NAME" ]]; then
        CLUSTER_NAME="k8s-cluster-$(date +%Y%m%d-%H%M%S)"
    fi
    
    # Set machine type - use provided size or default based on OS
    if [[ -n "$NODE_SIZE" ]]; then
        MACHINE_TYPE="$NODE_SIZE"
        print_info "Using specified machine type: $MACHINE_TYPE"
    else
        case $OS in
            windows)
                MACHINE_TYPE="e2-standard-2"
                ;;
            *)
                MACHINE_TYPE="e2-medium"
                ;;
        esac
        print_info "Using default machine type: $MACHINE_TYPE"
    fi
    
    print_info "GCP Config - Project: $GCP_PROJECT, Zone: $GCP_ZONE, Machine Type: $MACHINE_TYPE, Cluster: $CLUSTER_NAME"
}

# Function to get default values for Azure
get_azure_defaults() {
    # Use provided subscription or get from Azure CLI
    if [[ -n "$AZURE_SUBSCRIPTION" ]]; then
        print_info "Using provided Azure subscription: $AZURE_SUBSCRIPTION"
        az account set --subscription "$AZURE_SUBSCRIPTION"
    else
        AZURE_SUBSCRIPTION=$(az account show --query id --output tsv 2>/dev/null || echo "")
        if [ -z "$AZURE_SUBSCRIPTION" ]; then
            print_error "No Azure subscription found. Please login with: az login"
            exit 1
        fi
    fi
    
    # Get location from command line, Azure CLI config, or use default
    if [[ -z "$REGION" ]]; then
        AZURE_LOCATION=$(az configure --list-defaults --query "[?name=='location'].value" --output tsv 2>/dev/null)
        # If location is empty or not set, use default
        if [[ -z "$AZURE_LOCATION" ]]; then
            AZURE_LOCATION="eastus"
        fi
    else
        AZURE_LOCATION="$REGION"
    fi
    
    # Default resource group and cluster name
    if [[ -z "$CLUSTER_NAME" ]]; then
        CLUSTER_NAME="k8s-cluster-$(date +%Y%m%d-%H%M%S)"
    fi
    RESOURCE_GROUP="k8s-rg-$CLUSTER_NAME"
    
    # Set VM size - use provided size or default based on OS
    if [[ -n "$NODE_SIZE" ]]; then
        AZURE_NODE_SIZE="$NODE_SIZE"
        print_info "Using specified VM size: $AZURE_NODE_SIZE"
    else
        case $OS in
            windows)
                AZURE_NODE_SIZE="Standard_D2s_v3"
                ;;
            *)
                AZURE_NODE_SIZE="Standard_B2s"
                ;;
        esac
        print_info "Using default VM size: $AZURE_NODE_SIZE"
    fi
    
    print_info "Azure Config - Subscription: $AZURE_SUBSCRIPTION, Location: $AZURE_LOCATION, Node Size: $AZURE_NODE_SIZE, Cluster: $CLUSTER_NAME"
}

# Function to create AWS EKS cluster using eksctl
create_aws_cluster() {
    print_info "Creating AWS EKS cluster with eksctl: $CLUSTER_NAME"
    
    # Build eksctl command with profile if specified
    EKSCTL_CMD="eksctl"
    if [[ -n "$AWS_PROFILE" ]]; then
        EKSCTL_CMD="eksctl --profile $AWS_PROFILE"
        print_info "Using AWS profile: $AWS_PROFILE"
    fi
    
    # Create cluster config file for eksctl
    CLUSTER_CONFIG="eksctl-cluster-config.yaml"
    
    # Determine node AMI family based on OS
    AMI_FAMILY="AmazonLinux2"
    case $OS in
        al2023)
            AMI_FAMILY="AmazonLinux2023"
            ;;
        amazonlinux|linux)
            AMI_FAMILY="AmazonLinux2"
            ;;
        bottlerocket)
            AMI_FAMILY="Bottlerocket"
            ;;
        windows)
            AMI_FAMILY="WindowsServer2019FullContainer"
            ;;
        ubuntu)
            AMI_FAMILY="Ubuntu2004"
            ;;
        *)
            AMI_FAMILY="AmazonLinux2"
            print_warning "Unknown OS $OS, defaulting to Amazon Linux 2"
            ;;
    esac
    
    # Create eksctl cluster configuration
    cat > "$CLUSTER_CONFIG" << EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: $CLUSTER_NAME
  region: $AWS_REGION
  version: "$CLUSTER_VERSION"

iam:
  withOIDC: true

nodeGroups:
  - name: worker-nodes
    instanceType: $NODE_TYPE
    desiredCapacity: $NODE_COUNT
    minSize: 1
    maxSize: $((NODE_COUNT + 2))
    amiFamily: $AMI_FAMILY
    volumeSize: 20
    volumeType: gp3
EOF

    # Only add SSH configuration if we're not in CI and SSH keys exist
    if [[ -z "$GITHUB_ACTIONS" && (-f ~/.ssh/id_rsa.pub || -f ~/.ssh/id_ed25519.pub) ]]; then
        cat >> "$CLUSTER_CONFIG" << EOF
    ssh:
      allow: true
EOF
        print_info "SSH access enabled for nodes"
    else
        cat >> "$CLUSTER_CONFIG" << EOF
    ssh:
      allow: false
EOF
        print_info "SSH access disabled (CI environment or no SSH keys found)"
    fi

    cat >> "$CLUSTER_CONFIG" << EOF
    labels:
      role: worker
    tags:
      k8s.io/cluster-autoscaler/enabled: "true"
      k8s.io/cluster-autoscaler/$CLUSTER_NAME: "owned"
EOF

    # Add custom AMI if specified
    if [[ "$OS" == "custom" && -n "$CUSTOM_AMI" ]]; then
        print_info "Using custom AMI: $CUSTOM_AMI"
        
        # Validate that the AMI exists and get its details
        print_info "Validating custom AMI..."
        AMI_INFO=$($AWS_CMD ec2 describe-images --image-ids "$CUSTOM_AMI" --region "$AWS_REGION" --query 'Images[0]' 2>/dev/null || echo "null")
        
        if [[ "$AMI_INFO" == "null" || "$AMI_INFO" == "" ]]; then
            print_error "Custom AMI $CUSTOM_AMI not found or not accessible in region $AWS_REGION"
            exit 1
        fi
        
        # Extract AMI details
        AMI_NAME=$(echo "$AMI_INFO" | jq -r '.Name // "Unknown"')
        AMI_DESCRIPTION=$(echo "$AMI_INFO" | jq -r '.Description // "No description"')
        print_info "AMI Details: $AMI_NAME - $AMI_DESCRIPTION"
        
        # Add custom AMI to config
        cat >> "$CLUSTER_CONFIG" << EOF
    ami: $CUSTOM_AMI
    overrideBootstrapCommand: |
      #!/bin/bash
      /etc/eks/bootstrap.sh $CLUSTER_NAME
EOF
    fi
    
    print_info "Creating EKS cluster with eksctl (this may take 15-20 minutes)..."
    print_info "Using cluster config:"
    cat "$CLUSTER_CONFIG"
    
    # Create the cluster
    if ! $EKSCTL_CMD create cluster -f "$CLUSTER_CONFIG"; then
        print_error "Failed to create EKS cluster with eksctl. Please check the error above."
        rm -f "$CLUSTER_CONFIG"
        exit 1
    fi
    
    # Update kubeconfig
    print_info "Updating kubeconfig for AWS cluster..."
    $EKSCTL_CMD utils write-kubeconfig --cluster="$CLUSTER_NAME" --region="$AWS_REGION"
    
    # Cleanup config file
    rm -f "$CLUSTER_CONFIG"
    
    print_success "AWS EKS cluster '$CLUSTER_NAME' created successfully!"
    print_info "Cluster details saved to: clusters.info"
    
    # Save cluster info for deletion (append to single file)
    cat >> "clusters.info" << EOF
CLOUD=aws
CLUSTER_NAME=$CLUSTER_NAME
AWS_REGION=$AWS_REGION
AWS_PROFILE=$AWS_PROFILE
NODE_COUNT=$NODE_COUNT
OS=$OS
NODE_TYPE=$NODE_TYPE
CLUSTER_VERSION=$CLUSTER_VERSION
CUSTOM_AMI=$CUSTOM_AMI
AMI_FAMILY=$AMI_FAMILY
CREATED_AT="$(date -Iseconds)"
---
EOF
}

# Function to create GCP GKE cluster
create_gcp_cluster() {
    print_info "Creating GCP GKE cluster: $CLUSTER_NAME"
    
    if [ "$OS" = "windows" ]; then
        # Create cluster with Windows nodes
        gcloud container clusters create "$CLUSTER_NAME" \
            --zone "$GCP_ZONE" \
            --machine-type "$MACHINE_TYPE" \
            --num-nodes "$NODE_COUNT" \
            --enable-network-policy \
            --enable-ip-alias \
            --enable-autoscaling \
            --min-nodes 1 \
            --max-nodes $((NODE_COUNT + 2)) \
            --image-type "WINDOWS_SAC" \
            --disk-type "pd-standard" \
            --disk-size "100GB"
    else
        # Determine image type based on OS
        IMAGE_TYPE="COS_CONTAINERD"
        case $ACTUAL_OS in
            ubuntu)
                IMAGE_TYPE="UBUNTU_CONTAINERD"
                ;;
            cos)
                IMAGE_TYPE="COS_CONTAINERD"
                ;;
            linux)
                IMAGE_TYPE="COS_CONTAINERD"  # Default to COS for linux
                ;;
        esac
        
        gcloud container clusters create "$CLUSTER_NAME" \
            --zone "$GCP_ZONE" \
            --machine-type "$MACHINE_TYPE" \
            --num-nodes "$NODE_COUNT" \
            --enable-network-policy \
            --enable-ip-alias \
            --enable-autoscaling \
            --min-nodes 1 \
            --max-nodes $((NODE_COUNT + 2)) \
            --image-type "$IMAGE_TYPE" \
            --disk-type "pd-standard" \
            --disk-size "50GB"
    fi
    
    # Get credentials for kubectl
    print_info "Updating kubeconfig for GCP cluster..."
    gcloud container clusters get-credentials "$CLUSTER_NAME" --zone "$GCP_ZONE" --project "$GCP_PROJECT"
    
    print_success "GCP GKE cluster '$CLUSTER_NAME' created successfully!"
    print_info "Cluster details saved to: clusters.info"
    
    # Save cluster info for deletion (append to single file)
    cat >> "clusters.info" << EOF
CLOUD=gcp
CLUSTER_NAME=$CLUSTER_NAME
GCP_PROJECT=$GCP_PROJECT
GCP_ZONE=$GCP_ZONE
NODE_COUNT=$NODE_COUNT
OS=$OS
MACHINE_TYPE=$MACHINE_TYPE
CLUSTER_VERSION=$CLUSTER_VERSION
CREATED_AT="$(date -Iseconds)"
---
EOF
}

# Function to create Azure AKS cluster
create_azure_cluster() {
    print_info "Creating Azure AKS cluster: $CLUSTER_NAME"
    
    # Create resource group
    az group create --name "$RESOURCE_GROUP" --location "$AZURE_LOCATION"
    
    if [ "$OS" = "windows" ]; then
        # Create cluster with both Linux and Windows node pools
        az aks create \
            --resource-group "$RESOURCE_GROUP" \
            --name "$CLUSTER_NAME" \
            --location "$AZURE_LOCATION" \
            --node-count 1 \
            --node-vm-size "Standard_B2s" \
            --enable-cluster-autoscaler \
            --min-count 1 \
            --max-count 3 \
            --network-plugin "azure" \
            --generate-ssh-keys
        
        # Add Windows node pool
        az aks nodepool add \
            --resource-group "$RESOURCE_GROUP" \
            --cluster-name "$CLUSTER_NAME" \
            --name "winnp" \
            --node-count "$NODE_COUNT" \
            --node-vm-size "$AZURE_NODE_SIZE" \
            --os-type "Windows" \
            --enable-cluster-autoscaler \
            --min-count 1 \
            --max-count $((NODE_COUNT + 2))
    else
        # Determine OS SKU for Linux nodes
        OS_SKU="Ubuntu"
        case $ACTUAL_OS in
            ubuntu)
                OS_SKU="Ubuntu"
                ;;
            azurelinux)
                OS_SKU="AzureLinux"
                ;;
            linux)
                OS_SKU="Ubuntu"  # Default to Ubuntu for linux
                ;;
        esac
        
        az aks create \
            --resource-group "$RESOURCE_GROUP" \
            --name "$CLUSTER_NAME" \
            --location "$AZURE_LOCATION" \
            --node-count "$NODE_COUNT" \
            --node-vm-size "$AZURE_NODE_SIZE" \
            --os-sku "$OS_SKU" \
            --enable-cluster-autoscaler \
            --min-count 1 \
            --max-count $((NODE_COUNT + 2)) \
            --network-plugin "azure" \
            --generate-ssh-keys
    fi
    
    # Get credentials for kubectl
    print_info "Updating kubeconfig for Azure cluster..."
    az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --overwrite-existing
    
    print_success "Azure AKS cluster '$CLUSTER_NAME' created successfully!"
    print_info "Cluster details saved to: clusters.info"
    
    # Save cluster info for deletion (append to single file)
    cat >> "clusters.info" << EOF
CLOUD=azure
CLUSTER_NAME=$CLUSTER_NAME
RESOURCE_GROUP=$RESOURCE_GROUP
AZURE_LOCATION=$AZURE_LOCATION
AZURE_SUBSCRIPTION=$AZURE_SUBSCRIPTION
NODE_COUNT=$NODE_COUNT
OS=$OS
AZURE_NODE_SIZE=$AZURE_NODE_SIZE
CLUSTER_VERSION=$CLUSTER_VERSION
CREATED_AT="$(date -Iseconds)"
---
EOF
}

# Function to delete AWS EKS cluster directly (cluster info already loaded)
delete_aws_cluster_direct() {
    local cluster_name="$1"
    
    # Build eksctl command with profile if specified
    EKSCTL_CMD="eksctl"
    if [[ -n "$AWS_PROFILE" ]]; then
        EKSCTL_CMD="eksctl --profile $AWS_PROFILE"
        print_info "Using AWS profile: $AWS_PROFILE"
    fi
    
    print_info "Deleting AWS EKS cluster: $cluster_name"
    print_info "Using aggressive deletion approach to avoid hanging on unevictable pods."
    
    # Try direct cluster deletion without graceful node draining
    print_info "Attempting direct cluster deletion (skipping node drain)..."
    if timeout 300 $EKSCTL_CMD delete cluster --name "$cluster_name" --region "$AWS_REGION" --disable-nodegroup-eviction --wait; then
        print_success "AWS EKS cluster '$cluster_name' deleted successfully!"
        return 0
    fi
    
    print_warning "Direct deletion failed or timed out. Trying nodegroup deletion first..."
    
    # Get list of nodegroups and delete them individually
    print_info "Listing nodegroups..."
    local nodegroups
    nodegroups=$($EKSCTL_CMD get nodegroup --cluster="$cluster_name" --region="$AWS_REGION" --output json 2>/dev/null | jq -r '.[].Name' 2>/dev/null || echo "worker-nodes")
    
    # Delete nodegroups with shorter timeout
    for ng in $nodegroups; do
        print_info "Deleting nodegroup: $ng"
        timeout 180 $EKSCTL_CMD delete nodegroup --cluster="$cluster_name" --region="$AWS_REGION" --name="$ng" --disable-eviction --wait || {
            print_warning "Failed to delete nodegroup $ng, continuing..."
        }
    done
    
    # Delete the cluster control plane only
    print_info "Deleting cluster control plane only..."
    if timeout 120 $EKSCTL_CMD delete cluster --name "$cluster_name" --region "$AWS_REGION" --wait; then
        print_success "AWS EKS cluster '$cluster_name' deleted successfully!"
        return 0
    fi
    
    print_warning "Cluster deletion failed, but this might be expected if cluster was partially created or already deleted"
    return 1
}

# Function to delete GCP GKE cluster directly (cluster info already loaded)
delete_gcp_cluster_direct() {
    local cluster_name="$1"
    
    print_info "Deleting GCP GKE cluster: $cluster_name"
    
    if ! gcloud container clusters delete "$cluster_name" --zone "$GCP_ZONE" --quiet; then
        print_error "Failed to delete GCP cluster '$cluster_name'"
        return 1
    fi
    
    print_success "GCP GKE cluster '$cluster_name' deleted successfully!"
    return 0
}

# Function to delete Azure AKS cluster directly (cluster info already loaded)
delete_azure_cluster_direct() {
    local cluster_name="$1"
    
    print_info "Deleting Azure AKS cluster: $cluster_name"
    
    # Delete the cluster and wait for completion
    if ! az aks delete --resource-group "$RESOURCE_GROUP" --name "$cluster_name" --yes; then
        print_error "Failed to delete Azure cluster '$cluster_name'"
        return 1
    fi
    
    print_info "Deleting resource group: $RESOURCE_GROUP"
    if ! az group delete --name "$RESOURCE_GROUP" --yes; then
        print_warning "Cluster deleted but failed to delete resource group '$RESOURCE_GROUP'"
        print_info "You may need to manually delete the resource group"
        return 0  # Still consider this a success since cluster is deleted
    fi
    
    print_success "Azure AKS cluster '$cluster_name' and resource group '$RESOURCE_GROUP' deleted successfully!"
    return 0
}

# Function to list available clusters from single info file
list_clusters() {
    echo "Available clusters for deletion:"
    echo "================================"
    
    if [ ! -f "clusters.info" ] || [ ! -s "clusters.info" ]; then
        echo "No clusters.info file found or file is empty."
        echo ""
        echo "To create a cluster, run:"
        echo "$0 --create -C <aws|gcp|azure> --os <os> --nodes <count>"
        return
    fi
    
    local found_clusters=false
    local cluster_count=0
    local current_cloud=""
    local current_cluster_name=""
    local current_os=""
    local current_node_count=""
    local current_created_at=""
    
    # Read the clusters.info file and parse each cluster entry
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" == "---" ]]; then
            # End of cluster block - display if we found a valid cluster
            if [[ -n "$current_cluster_name" && -n "$current_cloud" ]]; then
                echo ""
                echo "Cluster #$((cluster_count + 1)):"
                echo "  Cloud: $current_cloud"
                echo "  Name: $current_cluster_name"
                echo "  OS: ${current_os:-unknown}"
                echo "  Nodes: ${current_node_count:-unknown}"
                echo "  Created: ${current_created_at:-unknown}"
                echo "--------------------------------"
                cluster_count=$((cluster_count + 1))
                found_clusters=true
            fi
            # Reset for next cluster
            current_cloud=""
            current_cluster_name=""
            current_os=""
            current_node_count=""
            current_created_at=""
        elif [[ "$line" =~ ^CLOUD=(.*)$ ]]; then
            current_cloud="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^CLUSTER_NAME=(.*)$ ]]; then
            current_cluster_name="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^OS=(.*)$ ]]; then
            current_os="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^NODE_COUNT=(.*)$ ]]; then
            current_node_count="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^CREATED_AT=(.*)$ ]]; then
            current_created_at="${BASH_REMATCH[1]}"
        fi
    done < "clusters.info"
    
    # Handle the last cluster if file doesn't end with ---
    if [[ -n "$current_cluster_name" && -n "$current_cloud" ]]; then
        echo ""
        echo "Cluster #$((cluster_count + 1)):"
        echo "  Cloud: $current_cloud"
        echo "  Name: $current_cluster_name"
        echo "  OS: ${current_os:-unknown}"
        echo "  Nodes: ${current_node_count:-unknown}"
        echo "  Created: ${current_created_at:-unknown}"
        cluster_count=$((cluster_count + 1))
        found_clusters=true
    fi
    
    if [ "$found_clusters" = false ]; then
        echo "No valid clusters found in clusters.info file."
        echo ""
        echo "To create a cluster, run:"
        echo "$0 --create -C <aws|gcp|azure> --os <os> --nodes <count>"
    fi
}

# Function to remove cluster from single info file
remove_cluster_from_info() {
    local cluster_name="$1"
    local temp_file="clusters.info.tmp"
    
    if [ ! -f "clusters.info" ]; then
        print_error "clusters.info file not found"
        return 1
    fi
    
    local found_cluster=false
    local in_cluster_block=false
    local current_cluster=""
    
    # Read the file and write all clusters except the one to delete
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" == "---" ]]; then
            if [ "$in_cluster_block" = true ] && [ "$current_cluster" != "$cluster_name" ]; then
                echo "$line" >> "$temp_file"
            fi
            in_cluster_block=false
            current_cluster=""
        elif [[ "$line" =~ ^CLUSTER_NAME=(.*)$ ]]; then
            current_cluster="${BASH_REMATCH[1]}"
            if [ "$current_cluster" = "$cluster_name" ]; then
                found_cluster=true
                in_cluster_block=true
            else
                in_cluster_block=true
                echo "$line" >> "$temp_file"
            fi
        elif [ "$in_cluster_block" = true ] && [ "$current_cluster" != "$cluster_name" ]; then
            echo "$line" >> "$temp_file"
        elif [ "$in_cluster_block" = true ] && [ "$current_cluster" = "$cluster_name" ]; then
            # Skip lines for the cluster being deleted
            continue
        fi
    done < "clusters.info"
    
    if [ "$found_cluster" = true ]; then
        mv "$temp_file" "clusters.info"
        return 0
    else
        rm -f "$temp_file"
        return 1
    fi
}

# Function to get cluster info from single info file
get_cluster_info() {
    local cluster_name="$1"
    local temp_file="/tmp/cluster_info_$$.sh"
    
    if [ ! -f "clusters.info" ]; then
        return 1
    fi
    
    local in_cluster_block=false
    local current_cluster=""
    local cluster_lines=()
    
    # Extract the specific cluster's info
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" == "---" ]]; then
            if [ "$in_cluster_block" = true ] && [ "$current_cluster" = "$cluster_name" ]; then
                # Found the cluster, write all its lines to temp file
                for cluster_line in "${cluster_lines[@]}"; do
                    echo "$cluster_line" >> "$temp_file"
                done
                break
            fi
            in_cluster_block=false
            current_cluster=""
            cluster_lines=()
        elif [[ "$line" =~ ^CLOUD= ]]; then
            # Start of a new cluster block
            in_cluster_block=true
            current_cluster=""
            cluster_lines=("$line")
        elif [[ "$line" =~ ^CLUSTER_NAME=(.*)$ ]] && [ "$in_cluster_block" = true ]; then
            current_cluster="${BASH_REMATCH[1]}"
            cluster_lines+=("$line")
        elif [ "$in_cluster_block" = true ]; then
            cluster_lines+=("$line")
        fi
    done < "clusters.info"
    
    # Handle case where target cluster is the last one (no trailing ---)
    if [ "$in_cluster_block" = true ] && [ "$current_cluster" = "$cluster_name" ]; then
        for cluster_line in "${cluster_lines[@]}"; do
            echo "$cluster_line" >> "$temp_file"
        done
    fi
    
    if [ -f "$temp_file" ] && [ -s "$temp_file" ]; then
        echo "$temp_file"
        return 0
    else
        rm -f "$temp_file"
        return 1
    fi
}

# Function to delete cluster by name
delete_cluster_by_name() {
    local cluster_name="$1"
    
    # Clear any existing variables that might interfere
    unset CLOUD AWS_REGION GCP_PROJECT GCP_ZONE RESOURCE_GROUP AZURE_LOCATION
    
    # Get cluster info from single clusters.info file
    local cluster_info_file
    cluster_info_file=$(get_cluster_info "$cluster_name")
    
    if [ $? -ne 0 ] || [ -z "$cluster_info_file" ]; then
        print_error "Cluster '$cluster_name' not found in tracked clusters"
        list_clusters
        return 1
    fi
    
    # Source the cluster info
    source "$cluster_info_file"
    
    # Delete the cluster based on cloud provider
    print_info "Deleting $CLOUD cluster: $cluster_name"
    
    case $CLOUD in
        aws)
            delete_aws_cluster_direct "$cluster_name"
            ;;
        gcp)
            delete_gcp_cluster_direct "$cluster_name"
            ;;
        azure)
            delete_azure_cluster_direct "$cluster_name"
            ;;
        *)
            print_error "Unknown cloud provider: $CLOUD"
            rm -f "$cluster_info_file"
            return 1
            ;;
    esac
    
    # Remove cluster from info file if deletion was successful
    if [ $? -eq 0 ]; then
        remove_cluster_from_info "$cluster_name"
        print_success "Cluster '$cluster_name' removed from tracking"
    fi
    
    # Cleanup temp file
    rm -f "$cluster_info_file"
}


# Main script logic
main() {
    # If no arguments provided, show help
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 0
    fi
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Check if action is specified
    if [[ -z "$ACTION" ]]; then
        print_error "No action specified. Use --create to create a cluster or --delete to delete one."
        echo ""
        show_usage
        exit 1
    fi
    
    # Validate arguments
    validate_arguments
    
    # Handle delete action
    if [[ "$ACTION" == "delete" ]]; then
        if [[ -n "$CLUSTER_NAME" ]]; then
            # Delete specific cluster by name
            delete_cluster_by_name "$CLUSTER_NAME"
        else
            # Show available clusters for deletion
            list_clusters
            echo ""
            echo "To delete a specific cluster, run:"
            echo "$0 --delete --name <cluster-name>"
        fi
        return 0
    fi
    
    # Handle create action
    print_info "Starting Kubernetes cluster creation..."
    print_info "Cloud: $CLOUD, OS: $OS, Node Count: $NODE_COUNT, Version: $CLUSTER_VERSION"
    
    # Check prerequisites
    check_prerequisites "$CLOUD"
    
    # Get defaults and create cluster
    case $CLOUD in
        aws)
            get_aws_defaults
            create_aws_cluster
            ;;
        gcp)
            get_gcp_defaults
            create_gcp_cluster
            ;;
        azure)
            get_azure_defaults
            create_azure_cluster
            ;;
    esac
    
    # Verify cluster is ready and show connection info
    print_info "Verifying cluster is ready and updating kubeconfig..."
    
    # Set kubectl context to the new cluster
    case $CLOUD in
        aws)
            kubectl config use-context "arn:aws:eks:$AWS_REGION:$AWS_ACCOUNT_ID:cluster/$CLUSTER_NAME" 2>/dev/null || kubectl config use-context "$CLUSTER_NAME" 2>/dev/null || true
            ;;
        gcp)
            kubectl config use-context "gke_${GCP_PROJECT}_${GCP_ZONE}_${CLUSTER_NAME}" 2>/dev/null || true
            ;;
        azure)
            kubectl config use-context "$CLUSTER_NAME" 2>/dev/null || true
            ;;
    esac
    
    # Display cluster info
    print_info "Cluster connection details:"
    kubectl cluster-info
    
    print_info "Cluster nodes:"
    kubectl get nodes
    
    print_info "Current kubectl context:"
    kubectl config current-context
    
    print_success "Cluster creation completed successfully!"
    print_info "Your kubeconfig has been updated. You can now use 'kubectl' to interact with your cluster."
}

# Run main function with all arguments
main "$@"
